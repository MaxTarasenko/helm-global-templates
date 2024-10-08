#!/bin/bash

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
RESET=$(tput sgr0)

# check_dependencies
for cmd in helm kubectl yq; do
    if ! command -v $cmd &> /dev/null; then
        echo "${RED}Error: $cmd is not installed.${RESET}"
        exit 1
    fi
done

# Default Variables
REPO_NAME="helm-global-templates"
REPO_URL="https://maxtarasenko.github.io/helm-global-templates"
CHART_NAME="global-one"
CHART_VERSION=${CHART_VERSION:-""}
NAMESPACE=${NAMESPACE:-"default"}
STANDARD_VALUES_FILE=""
ENV_VALUES_FILE=""
OPERATION=${OPERATION:-""}
DIRECTORY=${DIRECTORY:-""}
ALL_DIRECTORIES=false
ENV_FILE_NAME=${ENV_FILE_NAME:-""}
IMAGE_TAG=""
RELEASE_NAME=${RELEASE_NAME:-""}
EXCLUDE_RELEASES=${EXCLUDE_RELEASES:-""}

# check_dependencies
for cmd in helm kubectl yq; do
    if ! command -v $cmd &> /dev/null; then
        echo "${RED}Error: $cmd is not installed.${RESET}"
        exit 1
    fi
done

# Function to display help message
show_help() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -d, --directory       Specify the base directory for Helm charts."
  echo "  -a, --all             Iterate over all subdirectories as separate releases."
  echo "  -n, --namespace       Specify the Kubernetes namespace."
  echo "  -r, --release         Specify the release name."
  echo "  -o, --operation       Specify the operation (diff, upgrade)."
  echo "  -k, --kubeconfig      Set the KUBECONFIG to use."
  echo "  -e, --env-file        Specify the environment-specific values file."
  echo "  -t, --image-tag       Specify the image tag to use."
  echo "  -c, --chart-version   Specify the chart version to use."
  echo "  -h, --help            Display this help message."
  echo ""
  echo "Examples:"
  echo "  $0 -n mynamespace -r myrelease -t newtag"
  echo "  $0 -d mycharts/ -o upgrade"
  exit 0
}

add_separator() {
    echo ""
    echo "--- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---"
    echo ""
}

# Function to parse command-line arguments
parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case $1 in
    -d | --directory)
      DIRECTORY="${2%/}" # Remove trailing slash
      shift
      ;;
    -a | --all)
      ALL_DIRECTORIES=true
      ;;
    -n | --namespace)
      NAMESPACE="$2"
      shift
      ;;
    -r | --release)
      RELEASE_NAME="$2"
      shift
      ;;
    -o | --operation)
      OPERATION="$2"
      shift
      ;;
    -k | --kubeconfig)
      if [ -z "$KUBECONFIG" ]; then
        set_kubeconfig
      fi
      ;;
    -e | --env-file)
      ENV_FILE_NAME="$2"
      shift
      ;;
    -t | --image-tag)
      IMAGE_TAG="$2"
      shift
      ;;
    -c | --chart-version)
      CHART_VERSION="$2"
      shift
      ;;
    -h | --help)
      show_help
      ;;
    -x | --exclude)
      EXCLUDE_RELEASES="$2"
      shift
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
    esac
    shift
  done
}

# Function to select a base directory if not provided
select_base_directory() {
  if [ -z "$DIRECTORY" ]; then
    echo "Select a base directory:"
    select dir in */; do
      DIRECTORY="${dir%/}" # Remove trailing slash
      echo "Using base directory: $DIRECTORY"
      break
    done
  else
    DIRECTORY="${DIRECTORY%/}" # Ensure no trailing slash
    echo "Using specified base directory: $DIRECTORY"
  fi
  add_separator
}

# Function to check and select a subdirectory with values.yaml
select_subdirectory() {
  while [ ! -f "$DIRECTORY/values.yaml" ]; do
    echo "No values.yaml found in $DIRECTORY. Select a subdirectory:"
    select subdir in "$DIRECTORY"/*/; do
      DIRECTORY="${subdir%/}" # Remove trailing slash
      echo "Checking in subdirectory: $DIRECTORY"
      if [ -f "$DIRECTORY/values.yaml" ]; then
        echo "Found values.yaml in $DIRECTORY."
        break
      fi
      echo "values.yaml not found in selected subdirectory."
    done
    add_separator
  done
}

# Function to iterate through subdirectories
iterate_subdirectories() {
  for subdir in "$DIRECTORY"/*/; do
    RELEASE_NAME="${subdir%/}"         # Use subdirectory name as release name
    RELEASE_NAME="${RELEASE_NAME##*/}" # Remove path to get just the directory name
    STANDARD_VALUES_FILE="$subdir/values.yaml"

    # Use the environment file if ENV_FILE_NAME is set
    if [ -n "$ENV_FILE_NAME" ]; then
      ENV_VALUES_FILE="$subdir/$ENV_FILE_NAME.yaml"
      if [ ! -f "$ENV_VALUES_FILE" ]; then
        echo "Specified environment file $ENV_VALUES_FILE does not exist for subdirectory $subdir."
        ENV_VALUES_FILE=""
      fi
    else
      ENV_VALUES_FILE=""
    fi

    # Reset the image tag for each service
    IMAGE_TAG=""

    select_env_values_file
    perform_directory_operation
    add_separator
  done
}

# Function to select environment-specific values.yaml file
select_env_values_file() {
  if [ -n "$ENV_VALUES_FILE" ]; then
    if [ -f "$ENV_VALUES_FILE" ]; then
      echo "Using specified environment-specific values file: $ENV_VALUES_FILE"
      return
    else
      echo "Specified environment file $ENV_VALUES_FILE does not exist."
      ENV_VALUES_FILE=""
    fi
  fi

  # Scan for additional YAML files and offer selection if ENV_FILE_NAME not set
  yaml_files=($(ls "$DIRECTORY"/*.yaml 2>/dev/null | grep -v "values.yaml"))
  if [ "${#yaml_files[@]}" -gt 0 ]; then
    echo "Found additional YAML files:"
    options=("${yaml_files[@]##*/}" "Skip")
    for i in "${!options[@]}"; do
      echo "$((i + 1))) ${options[$i]}"
    done

    read -p "Choose an environment file [default: Skip]: " choice
    choice=${choice:-$((${#options[@]}))} # Default to the last option (Skip) if no choice is made

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#options[@]}" ] && [ "$choice" -gt 0 ]; then
      env_file="${options[$((choice - 1))]}"
      if [ "$env_file" == "Skip" ]; then
        ENV_VALUES_FILE=""
        echo "Skipping additional environment-specific values file."
      else
        ENV_VALUES_FILE="$DIRECTORY/$env_file"
        echo "Using selected environment-specific values file: $ENV_VALUES_FILE"
      fi
    else
      echo "Invalid selection. Skipping additional environment-specific values file."
      ENV_VALUES_FILE=""
    fi
  else
    echo "No additional environment-specific values file found."
    ENV_VALUES_FILE=""
  fi

  add_separator
}

# Function to set KUBECONFIG
set_kubeconfig() {
  echo "Select KUBECONFIG option (default: 1):"
  echo "1. Default KUBECONFIG ($HOME/.kube/config)"
  echo "2. Select from $HOME/.kube directory"
  echo "3. Specify a custom KUBECONFIG path"

  add_separator

  read -p "Enter option number [1-3]: " kubeconfig_option
  kubeconfig_option=${kubeconfig_option:-1} # Default to option 1

  case $kubeconfig_option in
  1)
    export KUBECONFIG="$HOME/.kube/config"
    echo "Using default KUBECONFIG: $KUBECONFIG"
    ;;
  2)
    echo "Available KUBECONFIG files in $HOME/.kube:"
    select kube_file in $HOME/.kube/*; do
      if [ -f "$kube_file" ]; then
        export KUBECONFIG="$kube_file"
        echo "Using selected KUBECONFIG: $KUBECONFIG"
        break
      else
        echo "Invalid selection, please choose a valid file."
      fi
    done
    ;;
  3)
    read -p "Enter custom KUBECONFIG path: " custom_kubeconfig
    if [ -f "$custom_kubeconfig" ]; then
      export KUBECONFIG="$custom_kubeconfig"
      echo "Using custom KUBECONFIG: $KUBECONFIG"
    else
      echo "Invalid file path. Using default KUBECONFIG."
      export KUBECONFIG="$HOME/.kube/config"
    fi
    ;;
  *)
    echo "Invalid option. Using default KUBECONFIG."
    export KUBECONFIG="$HOME/.kube/config"
    ;;
  esac

  add_separator
}

# Function to add Helm repo if not already added
add_helm_repo() {
  if ! helm repo list | grep -q "$REPO_NAME"; then
    echo "Adding Helm repo..."
    helm repo add "$REPO_NAME" "$REPO_URL"
    helm repo update
  else
    echo "Helm repo already added."
  fi
}

# Function to check if the release exists
release_exists() {
  helm ls -n "$NAMESPACE" | grep -q "$RELEASE_NAME"
}

# Function to extract image tag from existing release
get_image_tag() {
  if release_exists; then
    echo "Extracting image tag from existing release for $RELEASE_NAME..."
    values=$(helm get values "$RELEASE_NAME" -n "$NAMESPACE" -a)
    image_tag=$(echo "$values" | yq eval '.image.tag' -)
    echo "Current image tag: $image_tag"
    IMAGE_TAG=${IMAGE_TAG:-$image_tag}
  else
    echo "Release $RELEASE_NAME does not exist."
  fi
}

# TODO - fix error handling
# Function for simple image tag deployment with rollback
deploy_image_tag() {
  echo "Deploying image tag $IMAGE_TAG to release $RELEASE_NAME in namespace $NAMESPACE"

  if release_exists; then
    # Include the chart version if specified
    CHART_VERSION_FLAG=""
    if [ -n "$CHART_VERSION" ]; then
      CHART_VERSION_FLAG="--version $CHART_VERSION"
    fi

    echo "Existing release found. Upgrading with new image tag."
    previous_revision=$(helm history "$RELEASE_NAME" -n "$NAMESPACE" --max 1 | awk 'NR==2{print $1}')
    helm upgrade "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE" $CHART_VERSION_FLAG --set image.tag="$IMAGE_TAG" --reuse-values

    # Check if the deployment succeeded
    if [ $? -ne 0 ]; then
      echo "Upgrade failed. Rolling back to revision $previous_revision."
      helm rollback "$RELEASE_NAME" "$previous_revision" -n "$NAMESPACE"
      return
    fi

    # Get the latest replica set by sorting based on the creation timestamp and filtering by desired replicas
    latest_rs=$(kubectl get rs -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME" \
      --sort-by=.metadata.creationTimestamp -o jsonpath='{range .items[?(@.status.replicas!=0)]}{.metadata.name}{"\n"}{end}' | tail -1)

    echo "Latest Replica Set: $latest_rs"

    # Extract the pod-template-hash to track new pods from this replica set
    latest_hash="${latest_rs##*-}"

    echo "Pod Template Hash for Latest RS: $latest_hash"

    # Monitor the status of pods from the new replica set
    echo "Checking pod status..."
    sleep_interval=10
    max_restarts=3
    max_checks=30

    for ((i = 0; i < max_checks; i++)); do
      # Get the pods associated with the latest replica set
      pod_status=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/instance="$RELEASE_NAME" \
        -o jsonpath='{range .items[*]}{.metadata.name}:{.metadata.labels.pod-template-hash}:{.status.phase}:{.status.containerStatuses[0].restartCount}:{.status.containerStatuses[0].state.waiting.reason}{"\n"}{end}')

      echo "Detected Pods:"
      echo "$pod_status"

      new_pods=false
      all_pods_ready=true
      old_pods_terminated=true

      # Check each pod's restart count and status
      for status in $pod_status; do
        pod_name=$(echo "$status" | cut -d':' -f1)
        pod_hash=$(echo "$status" | cut -d':' -f2)
        pod_phase=$(echo "$status" | cut -d':' -f3)
        restart_count=$(echo "$status" | cut -d':' -f4)
        waiting_reason=$(echo "$status" | cut -d':' -f5)

        # Only process pods from the latest replica set
        if [[ "$pod_hash" == "$latest_hash" ]]; then
          new_pods=true
          echo "Pod $pod_name has $restart_count restarts. Status: $waiting_reason, Phase: $pod_phase"

          if [ "$restart_count" -gt "$max_restarts" ]; then
            echo "Pod $pod_name is restarting too frequently. Rolling back to revision $previous_revision."
            capture_logs "$pod_name"
            helm rollback "$RELEASE_NAME" "$previous_revision" -n "$NAMESPACE"
            return
          fi

          if [[ "$waiting_reason" == "ImagePullBackOff" || "$waiting_reason" == "CrashLoopBackOff" || "$waiting_reason" == "ErrImagePull" ]]; then
            echo "Pod $pod_name is in state $waiting_reason. Rolling back to revision $previous_revision."
            capture_logs "$pod_name"
            helm rollback "$RELEASE_NAME" "$previous_revision" -n "$NAMESPACE"
            return
          fi

          if [ "$pod_phase" != "Running" ]; then
            all_pods_ready=false
          fi
        else
          # Check if old pods are terminated
          if [ "$pod_phase" != "Terminating" ] && [ "$pod_phase" != "Succeeded" ]; then
            old_pods_terminated=false
            echo "Old pod $pod_name is still running or terminating. Waiting..."
          fi
        fi
      done

      if [ "$new_pods" = false ]; then
        echo "No new pods found yet. Waiting..."
      elif [ "$all_pods_ready" = true ] && [ "$old_pods_terminated" = true ]; then
        echo "All new pods are running and ready, and all old pods have terminated. Deployment successful."
        return
      fi

      echo "Continuing to monitor..."
      sleep $sleep_interval
    done

    echo "Deployment successful. Pods are stable."
  else
    echo "Release not found. Skipping deployment since the release doesn't exist."
  fi
}

# Function to capture logs for a specific pod
capture_logs() {
  pod_name="$1"
  echo "Capturing logs for pod $pod_name..."

  # Capture container logs
  kubectl logs "$pod_name" -n "$NAMESPACE" >"${pod_name}.log" 2>&1

  # Capture describe output
  kubectl describe pod "$pod_name" -n "$NAMESPACE" >"${pod_name}_describe.log" 2>&1

  echo "Logs captured: ${pod_name}.log, ${pod_name}_describe.log"
}

# Function to perform the operation on a directory
perform_directory_operation() {
  echo "Namespace: $NAMESPACE"
  echo "Release name: $RELEASE_NAME"
  echo "Using standard values file: $STANDARD_VALUES_FILE"
  echo "Using environment-specific values file: ${ENV_VALUES_FILE:-None}"

  add_separator

  # Determine operation
  if [ -z "$OPERATION" ]; then
    echo "Select operation (default: 1):"
    echo "1. diff"
    echo "2. upgrade"

    read -p "Enter action number [1-2]: " operation
    operation=${operation:-1} # Default to option 1

    case $operation in
    1) OPERATION="diff" ;;
    2) OPERATION="upgrade" ;;
    *) echo "Invalid operation" ;;
    esac
  fi

  if [[ "$OPERATION" =~ ^(diff|upgrade)$ ]]; then
    echo "Using operation: $OPERATION"
    get_image_tag
    perform_operation "$OPERATION"
  else
    echo "Invalid operation: $OPERATION. Choose 'diff' or 'upgrade'."
  fi
}

# Function to perform the chosen operation
perform_operation() {
  VALUES_FLAGS=""
  if [[ -f $STANDARD_VALUES_FILE ]]; then
    VALUES_FLAGS="$VALUES_FLAGS --values $STANDARD_VALUES_FILE"
  fi
  if [[ -f $ENV_VALUES_FILE ]]; then
    VALUES_FLAGS="$VALUES_FLAGS --values $ENV_VALUES_FILE"
  fi

  # Use the existing image tag if not overridden by the IMAGE_TAG variable
  if [ -n "$IMAGE_TAG" ]; then
    VALUES_FLAGS="$VALUES_FLAGS --set image.tag=$IMAGE_TAG"
  fi

  # Include the chart version if specified
  CHART_VERSION_FLAG=""
  if [ -n "$CHART_VERSION" ]; then
    CHART_VERSION_FLAG="--version $CHART_VERSION"
  fi

  case $1 in
  diff)
    echo "Performing diff operation..."
    if release_exists; then
      helm diff upgrade "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE" $VALUES_FLAGS $CHART_VERSION_FLAG --context 2
    else
      echo "Release does not exist. Diff shows entire contents as new."
      helm diff upgrade "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE" --allow-unreleased $VALUES_FLAGS $CHART_VERSION_FLAG --context 2
    fi
    ;;
  upgrade)
    echo "Performing upgrade operation..."
    if release_exists; then
      echo "Release exists. Upgrading..."

      # Check if there are changes with diff
      echo "Checking for changes with diff..."

      # Run the diff and capture the output
      DIFF_OUTPUT=$(helm diff upgrade "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE" $VALUES_FLAGS $CHART_VERSION_FLAG --context 2)

      # Check if there are no changes
      if [ -z "$DIFF_OUTPUT" ]; then
        echo "No changes detected, skipping upgrade."
      else
        echo "Changes detected, proceeding with upgrade..."

        # Output the detected changes
        echo "The following changes will be applied:"
        echo -e "$DIFF_OUTPUT"

        # Perform the upgrade
        helm upgrade "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE" $VALUES_FLAGS $CHART_VERSION_FLAG
      fi
    else
      echo "Release does not exist. Installing..."
      helm install "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE" $VALUES_FLAGS $CHART_VERSION_FLAG
    fi
    ;;
  *)
    echo "Invalid operation. Choose 'diff', 'upgrade'."
    exit 1
    ;;
  esac
}

# Main script execution
parse_args "$@"
add_helm_repo
add_separator

# Check if IMAGE_TAG is provided for updating
if [ -n "$IMAGE_TAG" ]; then
  deploy_image_tag
else
  # Select the base directory if not provided
  select_base_directory

  # Iterate over subdirectories if -a is specified
  if $ALL_DIRECTORIES; then
    iterate_subdirectories
  else
    select_subdirectory             # Choose subdirectory if values.yaml not found
    RELEASE_NAME="${DIRECTORY##*/}" # Use specified directory as release name
    STANDARD_VALUES_FILE="$DIRECTORY/values.yaml"

    # Use the environment file if ENV_FILE_NAME is set
    if [ -n "$ENV_FILE_NAME" ]; then
      ENV_VALUES_FILE="$DIRECTORY/$ENV_FILE_NAME.yaml"
      if [ ! -f "$ENV_VALUES_FILE" ]; then
        echo "Specified environment file $ENV_VALUES_FILE does not exist for subdirectory $subdir."
        ENV_VALUES_FILE=""
      fi
    else
      ENV_VALUES_FILE=""
    fi

    # Set the ENV_VALUES_FILE to user-specified or default to directory env.yaml
    select_env_values_file

    perform_directory_operation
  fi
fi

# ToDo - output color of echo
# ToDo - gaps between releases
# ToDo - when updating all releases, add a function to exclude some releases
# ToDo - connect few more additional values (option)
# ToDo - added option for upgrade with rollback