#!/bin/bash

# This script runs after the Codemagic build and publishes the local APK/AAB
# directly to a GitHub release so the website can consume stable assets.

set -euo pipefail

echo "🚀 Publishing GitHub Release from Codemagic artifacts..."

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "❌ GITHUB_TOKEN is not set in Codemagic."
  exit 1
fi

GITHUB_REPO="${GITHUB_REPO:-TECHTUNE-I-T-SOLUTIONS/whispr-mobile}"
GITHUB_OWNER="${GITHUB_REPO%%/*}"
GITHUB_NAME="${GITHUB_REPO##*/}"

VERSION=$(grep "^version:" pubspec.yaml | head -1 | awk '{print $2}' | cut -d '+' -f1)
TAG_NAME="v${VERSION}"
RELEASE_NAME="Whispr Mobile v${VERSION}"

APK_PATH=$(find build/app/outputs/apk/release -maxdepth 1 -type f -name '*.apk' | head -1)
AAB_PATH=$(find build/app/outputs/bundle/release -maxdepth 1 -type f -name '*.aab' | head -1)

if [ -z "$APK_PATH" ] && [ -z "$AAB_PATH" ]; then
  echo "❌ No APK or AAB artifact was found in the build output."
  exit 1
fi

API_BASE="https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_NAME}"
AUTH_HEADER="Authorization: Bearer ${GITHUB_TOKEN}"
COMMON_HEADERS=(
  -H "$AUTH_HEADER"
  -H "Accept: application/vnd.github+json"
  -H "X-GitHub-Api-Version: 2022-11-28"
)

echo "📦 Version: ${VERSION}"
echo "🏷️  Tag: ${TAG_NAME}"
echo "📁 APK: ${APK_PATH:-none}"
echo "📁 AAB: ${AAB_PATH:-none}"

RELEASE_JSON=$(curl -sS -w '\n%{http_code}' "${COMMON_HEADERS[@]}" "$API_BASE/releases/tags/$TAG_NAME")
RELEASE_HTTP_STATUS=$(echo "$RELEASE_JSON" | tail -n1)
RELEASE_BODY=$(echo "$RELEASE_JSON" | sed '$d')

if [ "$RELEASE_HTTP_STATUS" = "404" ]; then
  echo "🆕 Creating release $TAG_NAME"
  RELEASE_BODY=$(curl -sS -X POST "${COMMON_HEADERS[@]}" \
    -d @- "$API_BASE/releases" <<EOF
{
  "tag_name": "$TAG_NAME",
  "name": "$RELEASE_NAME",
  "body": "Whispr Mobile ${VERSION}",
  "draft": false,
  "prerelease": false
}
EOF
)
else
  echo "♻️  Updating existing release $TAG_NAME"
fi

UPLOAD_URL=$(echo "$RELEASE_BODY" | jq -r '.upload_url' | cut -d'{' -f1)
RELEASE_ID=$(echo "$RELEASE_BODY" | jq -r '.id')

if [ -z "$UPLOAD_URL" ] || [ "$UPLOAD_URL" = "null" ]; then
  echo "❌ Could not determine the GitHub release upload URL."
  exit 1
fi

delete_asset_if_exists() {
  local asset_name="$1"
  local asset_id
  asset_id=$(curl -sS "${COMMON_HEADERS[@]}" "$API_BASE/releases/$RELEASE_ID/assets" | jq -r --arg NAME "$asset_name" '.[] | select(.name == $NAME) | .id' | head -1)
  if [ -n "$asset_id" ] && [ "$asset_id" != "null" ]; then
    curl -sS -X DELETE "${COMMON_HEADERS[@]}" "$API_BASE/releases/assets/$asset_id" >/dev/null
  fi
}

upload_asset() {
  local file_path="$1"
  local content_type="$2"
  local asset_name
  asset_name=$(basename "$file_path")
  delete_asset_if_exists "$asset_name"
  curl -sS -X POST \
    -H "$AUTH_HEADER" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: $content_type" \
    --data-binary "@$file_path" \
    "$UPLOAD_URL?name=$asset_name"
}

if [ -n "$APK_PATH" ]; then
  echo "⬆️  Uploading APK asset"
  upload_asset "$APK_PATH" "application/vnd.android.package-archive" >/dev/null
fi

if [ -n "$AAB_PATH" ]; then
  echo "⬆️  Uploading AAB asset"
  upload_asset "$AAB_PATH" "application/octet-stream" >/dev/null
fi

echo "✅ GitHub release published successfully: https://github.com/${GITHUB_REPO}/releases/tag/${TAG_NAME}"
