#!/bin/bash

# Variables
REPO_NAME="helm-global-templates"
REPO_URL="https://maxtarasenko.github.io/helm-global-templates"
CHART_NAME="global-one"
NAMESPACE=${NAMESPACE:-"default"}
RELEASE_NAME=${RELEASE_NAME:-"global-one"}
STANDARD_VALUES_FILE=""  # Variable to store the selected standard values.yaml file
ENV_VALUES_FILE=""       # Variable to store the selected environment-specific values.yaml file

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

# Function to choose standard values.yaml file
select_standard_values_file() {
  echo "Select standard values.yaml option (default: values.yaml):"
  echo "1. Use default values (values.yaml)"
  echo "2. Select from current directory"
  echo "3. Specify a custom values.yaml path"

  read -p "Enter option number [1-3]: " values_option
  values_option=${values_option:-1} # Default to option 1

  case $values_option in
    1)
      STANDARD_VALUES_FILE="values.yaml" # Use default values
      echo "Using default values file."
      ;;
    2)
      echo "Available values.yaml files in current directory:"
      select values_file in ./*.yaml; do
        STANDARD_VALUES_FILE="$values_file"
        echo "Using selected standard values file: $STANDARD_VALUES_FILE"
        break
      done
      ;;
    3)
      read -p "Enter custom standard values.yaml path: " custom_values_file
      STANDARD_VALUES_FILE="$custom_values_file"
      echo "Using custom standard values file: $STANDARD_VALUES_FILE"
      ;;
    *)
      echo "Invalid option. Using default chart values."
      STANDARD_VALUES_FILE="" # Default to no values file
      ;;
  esac
}

# Function to choose environment-specific values.yaml file
select_env_values_file() {
  echo "Select environment-specific values.yaml option (default: skip):"
  echo "1. Use no additional values file"
  echo "2. Select from current directory"
  echo "3. Specify a custom values.yaml path"

  read -p "Enter option number [1-3]: " env_values_option
  env_values_option=${env_values_option:-1} # Default to option 1

  case $env_values_option in
    1)
      ENV_VALUES_FILE="" # Use no additional values file
      echo "No environment-specific values file specified."
      ;;
    2)
      echo "Available values.yaml files in current directory:"
      select env_file in ./*.yaml; do
        ENV_VALUES_FILE="$env_file"
        echo "Using selected environment-specific values file: $ENV_VALUES_FILE"
        break
      done
      ;;
    3)
      read -p "Enter custom environment-specific values.yaml path: " custom_env_file
      ENV_VALUES_FILE="$custom_env_file"
      echo "Using custom environment-specific values file: $ENV_VALUES_FILE"
      ;;
    *)
      echo "Invalid option. No environment-specific values file specified."
      ENV_VALUES_FILE="" # Default to no additional values file
      ;;
  esac
}

# Function to perform the chosen operation
perform_operation() {
  VALUES_FLAGS=""
  if [[ -n $STANDARD_VALUES_FILE ]]; then
    VALUES_FLAGS="$VALUES_FLAGS --values $STANDARD_VALUES_FILE"
  fi
  if [[ -n $ENV_VALUES_FILE ]]; then
    VALUES_FLAGS="$VALUES_FLAGS --values $ENV_VALUES_FILE"
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

# Echo the namespace and release name
echo "Namespace: $NAMESPACE"
echo "Release name: $RELEASE_NAME"
echo ""

# Main script execution
add_helm_repo
echo ""
set_kubeconfig
echo ""
select_standard_values_file
echo ""
select_env_values_file
echo ""

# Main menu
echo "Select operation (default: 1):"
echo "1. diff"
echo "2. apply"
echo "3. sync"

read -p "Enter action number [1-3]: " operation
operation=${operation:-1} # Default to option 1

# Perform the chosen operation
case $operation in
  1)
    echo "Using operation: diff"
    get_image_tag
    perform_operation "diff"
    ;;
  2)
    echo "Using operation: apply"
    get_image_tag
    perform_operation "apply"
    ;;
  3)
    echo "Using operation: sync"
    get_image_tag
    perform_operation "sync"
    ;;
  *)
    echo "Invalid operation"
    ;;
esac
