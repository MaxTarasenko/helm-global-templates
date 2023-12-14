#!/bin/sh
set -e

namespace=$1
release_name=$2

# Function to check if the release exists
release_exists() {
    helm -n "$namespace" list | grep -q "$release_name"
}

# Check if the release exists
if release_exists; then
    # Retrieve values from a running release
    values=$(helm -n "$namespace" get values "$release_name" -a)

    # Process the values and extract the required data
    image_tag=$(echo "$values" | yq eval '.image.tag' -)

    # Output the image tag
    echo "Image tag: $image_tag"

    # Save the value to a file
    echo "image:\n  tag: $image_tag" > temp-values.yaml
else
    # Create an empty file if the release does not exist
    touch temp-values.yaml
    echo "Release $release_name not found. Created an empty file."
fi
