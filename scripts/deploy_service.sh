#!/bin/bash
set -e  # Exit on error

# Docker registry
imageTag=${IMAGE_TAG:-"latest"}

# Global tpl configuration
helmGlobalChart="oci://registry-1.docker.io/mrmerseri/global-one"
helmGlobalChartVersion=${HELM_GLOBAL_CHART_VERSION:-"0.1.1"}

# K8s configuration
namespace=${NAMESPACE:-"default"}

# Helm configuration
helmChartName=${HELM_CHART_NAME:-"global-one"}
helmUpgradeTimeout=${HELM_UPGRADE_TIMEOUT:-"300s"}

# Helm upgrade
helm -n "${namespace}" upgrade "${helmChartName}" "${helmGlobalChart}" --version "${helmGlobalChartVersion}" \
  --reuse-values \
  --set image.tag="${imageTag}" \
  --wait --timeout "${helmUpgradeTimeout}" \
  && true

# Check status of upgrade
chartStatus=$(helm -n "${namespace}" status "${helmChartName}" --output json | jq -r '.info.status')

if [[ "$chartStatus" == "failed" ]]; then
  echo "Chart status is FAILED, initiating rollback"

  # Initialize k8sPodName as empty string
  k8sPodName=""

  # Keep trying until k8sPodName is not empty
  while [ -z "$k8sPodName" ]
  do
    # Get the pod name
    k8sPodName=$(kubectl -n "${namespace}" get pods \
    -l "app.kubernetes.io/instance=${helmChartName}" | \
    grep -E 'CrashLoopBackOff|ImagePullBackOff' | \
    awk '{print $1}')
  done

  echo "Pod name: ${k8sPodName}"

  # Write logs to file
  kubectl -n "${namespace}" logs -p --since=15m "${k8sPodName}" > container.log || echo "Could not write logs"

  # Write describe pod to file
  kubectl -n "${namespace}" describe pods "${k8sPodName}" > describe_container.log

  # Initiating rollback
  if ! helm rollback -n "${namespace}" "${helmChartName}";
  then
    echo "Error during helm rollback"
  else
    echo "Upgrade failed. Helm successfully rolled back"
  fi

  exit 1
fi