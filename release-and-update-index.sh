#!/bin/bash

# Load variables from .env file
export $(grep -v '^#' .env | xargs)

# Envs
REPO="maxtarasenko/helm-global-templates"
CHART_PATH="charts/global-one"
CHART_NAME="global-one"
TAG="0.1.6"
RELEASE_NAME="Release $TAG"
DESCRIPTION="global-one helm chart"
GITHUB_TOKEN=${GITHUB_TOKEN:-"token"}
REPO_URL="https://github.com/MaxTarasenko/helm-global-templates"

# Helm package
helm package $CHART_PATH

# Get tar file name
TAR_FILE=$(ls ${CHART_NAME}-*.tgz)

# Create release
RELEASE_RESPONSE=$(curl -s -X POST "https://api.github.com/repos/$REPO/releases" \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  -d @- <<EOF
{
  "tag_name": "$TAG",
  "target_commitish": "main",
  "name": "$RELEASE_NAME",
  "body": "$DESCRIPTION",
  "draft": false,
  "prerelease": false
}
EOF
)

# Check for errors
if [[ $(echo "$RELEASE_RESPONSE" | jq -r '.id') == "null" ]]; then
  echo "Error creating release: $(echo "$RELEASE_RESPONSE" | jq -r '.message')"
  exit 1
fi

# Get upload URL
UPLOAD_URL=$(echo "$RELEASE_RESPONSE" | jq -r '.upload_url' | sed -e "s/{?name,label}//")

# Upload tar file
curl -s -X POST "$UPLOAD_URL?name=$(basename $TAR_FILE)" \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/gzip" \
  --data-binary @"$TAR_FILE"

echo "The $TAG release has been created and the $TAR_FILE file has been loaded."

# Update index.yaml
helm repo index . --url "$REPO_URL/releases/download/$TAG"

# Commit and push changes
git add index.yaml
git commit -m "Update index.yaml for release $TAG"
git push origin main

echo "index.yaml has been updated and uploaded to the repository."
