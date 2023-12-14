#!/bin/sh
set -e

# Check if the argument is passed (diff or upgrade)
if [ $# -eq 0 ]; then
    echo "You must specify 'diff' or 'apply'."
    exit 1
fi

COMMAND=$1
HELMFILE=$2
ENV=$3
NAMESPACE=$4

# Retrieve release names from helmfile
releases=$(yq e '.releases[].name' "$HELMFILE")

if [ "$COMMAND" = "diff" ]; then
  for release in $releases; do
      echo "Execute $COMMAND for release $release"
      helmfile "$COMMAND" -f "$HELMFILE" -e "$ENV" -n "$NAMESPACE" --values "./temp-values.yaml" -l name="$release" --context 1
  done
fi

if [ "$COMMAND" = "apply" ]; then
  for release in $releases; do
      echo "Execute $COMMAND for release $release"
      helmfile "$COMMAND" -f "$HELMFILE" -e "$ENV" -n "$NAMESPACE" --values "./temp-values.yaml" -l name="$release" --context 1
  done
fi
