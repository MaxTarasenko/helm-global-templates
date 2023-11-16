#!/bin/sh

namespace=$1
release_name=$2

# Retrieve values from a running release
values=$(helm -n "$namespace" get values "$release_name" -a)

# Process the values and extract the required data
image_tag=$(echo "$values" | yq eval '.image.tag' -)

# You can save the obtained values in a file or perform other actions
echo "Image tag: $image_tag"

# Example of saving a value to a file
echo "image:\n  tag: $image_tag" > temp-values.yaml
