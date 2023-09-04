#!/bin/bash
set -e # Exit on error

# Global Chart templates
helmGlobalChart="oci://registry-1.docker.io/mrmerseri/global-one"

# Path to the charts values folder
chartsValuesPath=${CHARTS_VALUES_PATH:-"./helmfile/values"}

# Get a list of charts
charts=$(ls "$chartsValuesPath")

# Use the global variable NAMESPACE if it is set. Otherwise use 'insk-hotfix'.
namespace=${NAMESPACE:-"default"}

for chart in $charts; do
  if [ -d "$chartsValuesPath/$chart" ]; then

    helmGlobalChartVersion=$(helm -n $namespace history $chart | grep '^[0-9]' | tail -n1 | awk '{ print $8 }' | awk -F- '{print $NF}')

    chartValues="$chartsValuesPath/$chart/values.yaml"

    # Get the current chart values and select the 'image.tag' section
    helm get values "$chart" -n "$namespace" -a | yq eval '{"image": {"tag": .image.tag}}' - >image_values.yaml

    # Check for changes using the helm diff
    diff_output=$(helm diff upgrade "$chart" "$helmGlobalChart" --version "$helmGlobalChartVersion"  \
      -f "$chartValues" -f image_values.yaml -n "$namespace" --context 1)

    if [ -z "$diff_output" ]; then
      echo "No changes detected for $chart. Skipping..."
      # Delete the temporary file
      rm image_values.yaml
      # Skip
      continue
    else
      echo -e "Changes detected for $chart. Applying...\n"
      echo -e "$diff_output"
    fi

    # Check if the override file exists
    overrideBaseName=${CHARTS_VALUE_OVERRIDE:-"override"}
    overrideFile=""
    if [ -f "$chartsValuesPath/$chart/$overrideBaseName.yaml" ]; then
      overrideFile="$chartsValuesPath/$chart/$overrideBaseName.yaml"
    elif [ -f "$chartsValuesPath/$chart/$overrideBaseName.yml" ]; then
      overrideFile="$chartsValuesPath/$chart/$overrideBaseName.yml"
    fi

    if [ -f "$overrideFile" ]; then
      # Helm upgrade with namespace and override file selected
      helm upgrade "$chart" "$helmGlobalChart" --version "$helmGlobalChartVersion" \
        -n "$namespace" \
        -f "$chartValues" \
        -f "$overrideFile" \
        -f image_values.yaml \
        --wait --timeout 300s
    else
      # Helm upgrade with namespace and without override file
      helm upgrade "$chart" "$helmGlobalChart" --version "$helmGlobalChartVersion" \
        -n "$namespace" \
        -f "$chartValues" \
        -f image_values.yaml \
        --wait --timeout 300s
    fi

    # Delete the temporary file
    rm image_values.yaml
  fi
done
