#!/bin/bash

# Default Variables
REPO_NAME="helm-global-templates"
REPO_URL="https://maxtarasenko.github.io/helm-global-templates"
CHART_NAME="global-one"
NAMESPACE=${NAMESPACE:-"default"}
STANDARD_VALUES_FILE=""
ENV_VALUES_FILE=""
OPERATION=${OPERATION:-""}
DIRECTORY=${DIRECTORY:-""}
ALL_DIRECTORIES=false
ENV_FILE_NAME=${ENV_FILE_NAME:-""}
IMAGE_TAG=${IMAGE_TAG:-""}
RELEASE_NAME=${RELEASE_NAME:-""}

# Function to parse command-line arguments
parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -d|--directory)
        DIRECTORY="$2"
        shift
        ;;
      -a|--all)
        ALL_DIRECTORIES=true
        ;;
      -n|--namespace)
        NAMESPACE="$2"
        shift
        ;;
      -r|--release)
        RELEASE_NAME="$2"
        shift
        ;;
      -o|--operation)
        OPERATION="$2"
        shift
        ;;
      -k|--kubeconfig)
        set_kubeconfig
        ;;
      -e|--env-file)
        ENV_FILE_NAME="$2.yaml"
        shift
        ;;
      -t|--image-tag)
        IMAGE_TAG="$2"
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
    echo "Using specified base directory: $DIRECTORY"
  fi
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
  done
}

# Function to iterate through subdirectories
iterate_subdirectories() {
  for subdir in "$DIRECTORY"/*/; do
    RELEASE_NAME="${subdir%/}" # Use subdirectory name as release name
    RELEASE_NAME="${RELEASE_NAME##*/}" # Remove path to get just the directory name
    STANDARD_VALUES_FILE="$subdir/values.yaml"
    ENV_VALUES_FILE="$subdir/$ENV_FILE_NAME"

    select_env_values_file
    perform_directory_operation
  done
}

# Function to select environment-specific values.yaml file
select_env_values_file() {
  if [ -n "$ENV_FILE_NAME" ]; then
    ENV_VALUES_FILE="$DIRECTORY/$ENV_FILE_NAME"
    if [ -f "$ENV_VALUES_FILE" ]; then
      echo "Using specified environment-specific values file: $ENV_VALUES_FILE"
    else
      echo "Specified environment file $ENV_VALUES_FILE does not exist."
      ENV_VALUES_FILE=""
    fi
  else
    # Scan for additional YAML files and offer selection
    yaml_files=($(ls "$DIRECTORY"/*.yaml 2>/dev/null | grep -v "values.yaml"))
    if [ "${#yaml_files[@]}" -gt 0 ]; then
      echo "Found additional YAML files:"
      options=("${yaml_files[@]##*/}" "Skip")
      for i in "${!options[@]}"; do
        echo "$((i+1))) ${options[$i]}"
      done

      read -p "Choose an environment file [default: Skip]: " choice
      choice=${choice:-$(( ${#options[@]} ))} # Default to the last option (Skip) if no choice is made

      if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -le "${#options[@]}" ] && [ "$choice" -gt 0 ]; then
        env_file="${options[$((choice-1))]}"
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
  fi
}

# Function to set KUBECONFIG
set_kubeconfig() {
  echo "Select KUBECONFIG option (default: 1):"
  echo "1. Default KUBECONFIG ($HOME/.kube/config)"
  echo "2. Select from $HOME/.kube directory"
  echo "3. Specify a custom KUBECONFIG path"

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
        export KUBECONFIG="$kube_file"
        echo "Using selected KUBECONFIG: $KUBECONFIG"
        break
      done
      ;;
    3)
      read -p "Enter custom KUBECONFIG path: " custom_kubeconfig
      export KUBECONFIG="$custom_kubeconfig"
      echo "Using custom KUBECONFIG: $KUBECONFIG"
      ;;
    *)
      echo "Invalid option. Using default KUBECONFIG."
      export KUBECONFIG="$HOME/.kube/config"
      ;;
  esac
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
    echo "Extracting image tag from existing release..."
    values=$(helm get values "$RELEASE_NAME" -n "$NAMESPACE")
    image_tag=$(echo "$values" | yq eval '.image.tag' -)
    echo "Current image tag: $image_tag"
  else
    echo "Release $RELEASE_NAME does not exist."
  fi
}

# Function to update the image tag
update_image_tag() {
  if release_exists; then
    echo "Updating image tag to $IMAGE_TAG for release $RELEASE_NAME"
    helm get values "$RELEASE_NAME" -n "$NAMESPACE" > current-values.yaml
    yq eval ".image.tag = \"$IMAGE_TAG\"" current-values.yaml > updated-values.yaml
    helm upgrade "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE" -f updated-values.yaml
    rm current-values.yaml updated-values.yaml
  else
    echo "Release $RELEASE_NAME does not exist, cannot update image tag."
  fi
}

# Function to perform the operation on a directory
perform_directory_operation() {
  echo "Namespace: $NAMESPACE"
  echo "Release name: $RELEASE_NAME"
  echo "Using standard values file: $STANDARD_VALUES_FILE"
  echo "Using environment-specific values file: ${ENV_VALUES_FILE:-None}"
  echo ""

  # Determine operation
  if [ -z "$OPERATION" ]; then
    echo "Select operation (default: 1):"
    echo "1. diff"
    echo "2. apply"
    echo "3. sync"

    read -p "Enter action number [1-3]: " operation
    operation=${operation:-1} # Default to option 1

    case $operation in
      1) OPERATION="diff" ;;
      2) OPERATION="apply" ;;
      3) OPERATION="sync" ;;
      *) echo "Invalid operation" ;;
    esac
  fi

  if [[ "$OPERATION" =~ ^(diff|apply|sync)$ ]]; then
    echo "Using operation: $OPERATION"
    get_image_tag
    perform_operation "$OPERATION"
  else
    echo "Invalid operation: $OPERATION. Choose 'diff', 'apply', or 'sync'."
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

  if [ -n "$IMAGE_TAG" ]; then
    VALUES_FLAGS="$VALUES_FLAGS --set image.tag=$IMAGE_TAG"
  fi

  case $1 in
    diff)
      echo "Performing diff operation..."
      if release_exists; then
        helm diff upgrade "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE" $VALUES_FLAGS --context 2
      else
        echo "Release does not exist. Diff shows entire contents as new."
        helm diff upgrade "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE" --allow-unreleased $VALUES_FLAGS --context 2
      fi
      ;;
    apply)
      echo "Performing apply operation..."
      if release_exists; then
        helm upgrade "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE" $VALUES_FLAGS
      else
        helm install "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE" $VALUES_FLAGS
      fi
      ;;
    sync)
      echo "Performing sync operation..."
      helm upgrade --install "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE" $VALUES_FLAGS
      ;;
    *)
      echo "Invalid operation. Choose 'diff', 'apply', or 'sync'."
      exit 1
      ;;
  esac
}

# Main script execution
parse_args "$@"
add_helm_repo
echo ""

# Check if IMAGE_TAG is provided for updating
if [ -n "$IMAGE_TAG" ]; then
  update_image_tag
else
  # Select the base directory if not provided
  select_base_directory

  # Iterate over subdirectories if -a is specified
  if $ALL_DIRECTORIES; then
    iterate_subdirectories
  else
    select_subdirectory # Choose subdirectory if values.yaml not found
    RELEASE_NAME="${DIRECTORY##*/}" # Use specified directory as release name
    STANDARD_VALUES_FILE="$DIRECTORY/values.yaml"

    # Set the ENV_VALUES_FILE to user-specified or default to directory env.yaml
    select_env_values_file

    perform_directory_operation
  fi
fi
