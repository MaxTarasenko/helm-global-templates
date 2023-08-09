#!/bin/bash

helmGlobalChart="oci://registry-1.docker.io/mrmerseri/global-one"
helmGlobalChartVersion=${HELM_GLOBAL_CHART_VERSION:-"0.1.0"}

namespace=${NAMESPACE:-"default"}
helmChartName=${HELM_CHART_NAME:-"global-one"}

imageTag=${IMAGE_TAG:-"latest"}

helmUpgradeTimeout=${HELM_UPGRADE_TIMEOUT:-"300s"}

helm -n "${namespace}" upgrade "${helmChartName}" "${helmGlobalChart}" --version "${helmGlobalChartVersion}" \
  --reuse-values \
  --set image.tag="${imageTag}" \
  --wait --timeout "${helmUpgradeTimeout}"
