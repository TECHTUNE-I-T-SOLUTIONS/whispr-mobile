#!/bin/bash

# Debug CodeMagic API response
CODEMAGIC_API_TOKEN="Mx0tOKSDa9W0dLPSRUrWqlwmnhv43KrFKclPrtqpuNM"
CODEMAGIC_APP_ID="69bc03348aebba642bb60c85"

echo "=== Fetching CodeMagic builds ==="
echo "API Token: ${CODEMAGIC_API_TOKEN:0:10}..."
echo "App ID: $CODEMAGIC_APP_ID"
echo ""

# Fetch raw response
echo "=== Full API Response ==="
curl -s -H "x-auth-token: ${CODEMAGIC_API_TOKEN}" \
  "https://api.codemagic.io/builds?appId=${CODEMAGIC_APP_ID}&status=finished&limit=5" | jq '.'

echo ""
echo "=== Build Statuses ==="
curl -s -H "x-auth-token: ${CODEMAGIC_API_TOKEN}" \
  "https://api.codemagic.io/builds?appId=${CODEMAGIC_APP_ID}&status=finished&limit=5" | jq '.builds[] | {id: .id, platform: .platform, status: .status, buildStatus: .buildStatus, mode: .mode, hasArtifacts: (.artifacts | length), artifacts: .artifacts}'

echo ""
echo "=== iOS Builds with Artifacts ==="
curl -s -H "x-auth-token: ${CODEMAGIC_API_TOKEN}" \
  "https://api.codemagic.io/builds?appId=${CODEMAGIC_APP_ID}&status=finished&limit=10" | jq '.builds[] | select(.platform == "ios" and .buildStatus == "success") | {id: .id, status: .buildStatus, mode: .mode, artifacts: .artifacts}'

echo ""
echo "=== Android Builds with Artifacts ==="
curl -s -H "x-auth-token: ${CODEMAGIC_API_TOKEN}" \
  "https://api.codemagic.io/builds?appId=${CODEMAGIC_APP_ID}&status=finished&limit=10" | jq '.builds[] | select(.platform == "android" and .buildStatus == "success") | {id: .id, status: .buildStatus, mode: .mode, artifacts: .artifacts}'
