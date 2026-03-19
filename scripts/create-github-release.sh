#!/bin/bash

# This script is designed to run in CodeMagic post-build
# It triggers the GitHub Actions workflow to create a release

set -e

echo "🚀 Creating GitHub Release from CodeMagic Build..."

# Get build information
BUILD_ID=$(echo $CM_BUILD_ID)
BUILD_PLATFORM=$(echo $CM_PLATFORM)
BUILD_NUMBER=$(echo $CM_BUILD_NUMBER)

# Get version from pubspec.yaml
VERSION=$(grep "version:" pubspec.yaml | head -1 | awk '{print $2}' | cut -d '+' -f1)

echo "📦 Build Information:"
echo "   Version: $VERSION"
echo "   Build ID: $BUILD_ID"
echo "   Platform: $BUILD_PLATFORM"
echo "   Build Number: $BUILD_NUMBER"

# Trigger GitHub Actions workflow via repository_dispatch
# This requires: GITHUB_TOKEN environment variable to be set in CodeMagic

GITHUB_REPO="TECHTUNE-I-T-SOLUTIONS/whispr-mobile"
WORKFLOW_TRIGGER_URL="https://api.github.com/repos/${GITHUB_REPO}/dispatches"

PAYLOAD=$(cat <<EOF
{
  "event_type": "codemagic-build-success",
  "client_payload": {
    "version": "$VERSION",
    "build_id": "$BUILD_ID",
    "platform": "$BUILD_PLATFORM",
    "build_number": "$BUILD_NUMBER",
    "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  }
}
EOF
)

echo ""
echo "📡 Triggering GitHub Release Workflow..."
echo "   Repository: $GITHUB_REPO"
echo "   Event: codemagic-build-success"

if [ -z "$GITHUB_TOKEN" ]; then
  echo "⚠️  GITHUB_TOKEN not set. Cannot trigger GitHub Actions."
  echo "   Please set GITHUB_TOKEN environment variable in CodeMagic."
  exit 1
fi

RESPONSE=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d "$PAYLOAD" \
  "$WORKFLOW_TRIGGER_URL")

if echo "$RESPONSE" | grep -q '"message"'; then
  ERROR=$(echo "$RESPONSE" | grep -o '"message":"[^"]*' | cut -d'"' -f4)
  echo "❌ Failed to trigger workflow: $ERROR"
  exit 1
fi

echo "✅ GitHub Release workflow triggered successfully!"
echo ""
echo "🎉 Release v$VERSION will be created shortly."
echo "   Visit: https://github.com/$GITHUB_REPO/releases"
