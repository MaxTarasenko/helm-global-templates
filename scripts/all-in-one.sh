#!/bin/bash

# Variables
REPO_NAME="helm-global-templates"
REPO_URL="https://maxtarasenko.github.io/helm-global-templates"
CHART_NAME="global-one"
NAMESPACE=${NAMESPACE:-"default"}
RELEASE_NAME=${RELEASE_NAME:-"global-one"}

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

# Function to perform the chosen operation
perform_operation() {
  case $1 in
    diff)
      echo "Performing diff operation..."
      if release_exists; then
        helm diff upgrade "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE" --context 2
      else
        echo "Release does not exist. Diff shows entire contents as new."
        helm diff upgrade "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE" --allow-unreleased --context 2
      fi
      ;;
    apply)
      echo "Performing apply operation..."
      if release_exists; then
        helm upgrade "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE" --context 2
      else
        helm install "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE" --context 2
      fi
      ;;
    sync)
      echo "Performing sync operation..."
      helm upgrade --install "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE"
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
    echo "Using default operation: diff"
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
