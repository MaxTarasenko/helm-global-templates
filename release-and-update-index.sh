#!/bin/bash

# Load variables from .env file
export $(grep -v '^#' .env | xargs)

# Variables
CHART_PATH="charts/global-one"
CHART_NAME="global-one"

# Extract the version from Chart.yaml
CHART_VERSION=$(yq eval '.version' "$CHART_PATH/Chart.yaml")
RELEASE_NAME="Release $CHART_VERSION"

REPO="maxtarasenko/helm-global-templates"
GITHUB_TOKEN=${GITHUB_TOKEN:-"token"}
BRANCH="main"

# Package the chart
echo "Packaging version $CHART_VERSION for chart $CHART_PATH..."
helm package $CHART_PATH

# Get tar file name
TAR_FILE="$CHART_NAME-$CHART_VERSION.tgz"

# Check if the release already exists
EXISTING_RELEASE=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$REPO/releases/tags/v$CHART_VERSION")

if echo "$EXISTING_RELEASE" | grep -q '"id":'; then
  echo "Release v$CHART_VERSION already exists. Deleting the old release..."
  RELEASE_ID=$(echo "$EXISTING_RELEASE" | jq -r '.id')

  # Delete the existing release
  curl -s -X DELETE -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO/releases/$RELEASE_ID"
fi

# Create a new release
echo "Creating a new release v$CHART_VERSION..."
RELEASE_RESPONSE=$(curl -s -X POST "https://api.github.com/repos/$REPO/releases" \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -d @- <<EOF
{
  "tag_name": "v$CHART_VERSION",
  "target_commitish": "$BRANCH",
  "name": "Release v$CHART_VERSION",
  "body": "Release version $CHART_VERSION",
  "draft": false,
  "prerelease": false
}
EOF
)

# Extract the upload URL
UPLOAD_URL=$(echo "$RELEASE_RESPONSE" | jq -r '.upload_url' | sed -e "s/{?name,label}//")

# Check for errors in release creation
if [[ "$UPLOAD_URL" == "null" ]]; then
  echo "Error creating release: $(echo "$RELEASE_RESPONSE" | jq -r '.message')"
  exit 1
fi

# Upload the file to the release
echo "Uploading file $TAR_FILE to the release..."
curl -s -X POST "$UPLOAD_URL?name=$(basename $TAR_FILE)" \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/gzip" \
  --data-binary @"$TAR_FILE"

echo "The $CHART_VERSION release has been created and the $TAR_FILE file has been loaded."

# Update index.yaml
echo "Updating index.yaml..."
REPO_URL="https://github.com/MaxTarasenko/helm-global-templates/releases/download"
helm repo index . --url "$REPO_URL/v$CHART_VERSION"

rm "$TAR_FILE"

# Commit and push changes
git add .
git commit -m "Create release $CHART_VERSION"
git push origin main

echo "index.yaml has been updated and uploaded to the repository."
