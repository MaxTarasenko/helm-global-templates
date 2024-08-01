#!/bin/bash

# Variables
REPO_NAME="helm-global-templates"
REPO_URL="https://maxtarasenko.github.io/helm-global-templates"
CHART_NAME="global-one"
NAMESPACE=${NAMESPACE:-"default"}
RELEASE_NAME=${RELEASE_NAME:-"global-one"}

# Function to set KUBECONFIG
set_kubeconfig() {
  echo "Select KUBECONFIG option:"
  echo "1. Default KUBECONFIG ($HOME/.kube/config)"
  echo "2. Select from $HOME/.kube directory"
  echo "3. Specify a custom KUBECONFIG path"

  read -p "Enter option number: " kubeconfig_option

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
        helm diff install "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE" --context 2
      fi
      ;;
    apply)
      echo "Performing apply operation..."
      if release_exists; then
        helm upgrade "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE"
      else
        helm install "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE"
      fi
      ;;
    sync)
      echo "Performing sync operation..."
      if release_exists; then
        helm upgrade --install "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE"
      else
        helm install "$RELEASE_NAME" "$REPO_NAME/$CHART_NAME" -n "$NAMESPACE"
      fi
      ;;
    *)
      echo "Invalid operation. Choose 'diff', 'apply', or 'sync'."
      exit 1
      ;;
  esac
}

# Main script execution
set_kubeconfig
add_helm_repo

# Main menu
echo "Select operation:"
echo "1. diff"
echo "2. apply"
echo "3. sync"

read -p "Enter action number: " operation

# Perform the chosen operation
case $operation in
  1)
    get_image_tag
    perform_operation "diff"
    ;;
  2)
    get_image_tag
    perform_operation "apply"
    ;;
  3)
    get_image_tag
    perform_operation "sync"
    ;;
  *)
    echo "Invalid operation"
    ;;
esac
