#!/bin/sh
set -e

# Check if the argument is passed (diff or apply)
if [ $# -eq 0 ]; then
    echo "You must specify 'diff' or 'apply'."
    exit 1
elif [ "$1" != "diff" ] && [ "$1" != "apply" ]; then
    echo "Invalid argument: $1. You must specify 'diff' or 'apply'."
    exit 1
fi

COMMAND=$1
HELMFILE=$2
NAMESPACE=$3
ENV=$4

helmfileStart() {
    # Retrieve release names from helmfile
    releases=$(yq e '.releases[].name' "$HELMFILE")
    # For values
    temp_values_path="$(dirname "$HELMFILE")/temp-values.yaml"


    for release in $releases; do
        # Function to check if the release exists
        release_exists() {
            helm -n "$NAMESPACE" list | grep -q "$release"
        }

        # Check if the release exists
        if release_exists; then
            # Retrieve values from a running release
            values=$(helm -n "$NAMESPACE" get values "$release" -a)

            # Process the values and extract the required data
            image_tag=$(echo "$values" | yq eval '.image.tag' -)

            # Save the value to a file
            printf "image:\n  tag: %s\n" "$image_tag" > "$temp_values_path"
        else
            # Create an empty file if the release does not exist
            touch "$temp_values_path"
            echo "Release $release not found. Created an empty file."
        fi

        # Diff or Upgrade Helmfile
        echo "Execute $COMMAND for release $release"
        if [ -f "$temp_values_path" ]; then
            if [ -n "$ENV" ]; then
                helmfile "$COMMAND" -f "$HELMFILE" -n "$NAMESPACE" -e "$ENV" --values "$temp_values_path" -l name="$release" --context 1
            else
                helmfile "$COMMAND" -f "$HELMFILE" -n "$NAMESPACE" --values "$temp_values_path" -l name="$release" --context 1
            fi
            # Clean file temp-values.yaml after deploy
            rm "$temp_values_path"
        else
            if [ -n "$ENV" ]; then
                helmfile "$COMMAND" -f "$HELMFILE" -n "$NAMESPACE" -e "$ENV" -l name="$release" --context 1
            else
                helmfile "$COMMAND" -f "$HELMFILE" -n "$NAMESPACE" -l name="$release" --context 1
            fi
        fi
    done
}

# Call helmfileStart function
helmfileStart
