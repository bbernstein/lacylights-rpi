#!/usr/bin/env bash
#
# Build the download page for https://dist.lacylights.com/releases/rpi/
#
# CloudFront rewrites /releases/rpi/ to /releases/rpi/index.html, so that
# object must exist in S3 or visitors get an AccessDenied error. This script
# produces index.html plus the versions.json manifest it reads.
#
# Usage:
#   release-index/generate.sh <metadata-dir> <output-dir>
#
#   metadata-dir  Directory containing per-version metadata files
#                 (e.g. 0.2.19.json) as uploaded by the release workflow.
#                 latest.json, prerelease.json and versions.json are ignored.
#   output-dir    Directory to write index.html and versions.json into.

set -euo pipefail

COMPONENT="rpi"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <metadata-dir> <output-dir>" >&2
    exit 2
fi

METADATA_DIR="$1"
OUTPUT_DIR="$2"

if [ ! -d "$METADATA_DIR" ]; then
    echo "Error: metadata directory not found: $METADATA_DIR" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

VERSIONS_JSON="[]"
shopt -s nullglob
for FILE in "$METADATA_DIR"/*.json; do
    case "$(basename "$FILE")" in
        latest.json|prerelease.json|versions.json) continue ;;
    esac

    # Only accept well-formed metadata that has the fields the page needs
    if ! jq -e 'type == "object" and (.version | type == "string") and (.url | type == "string")' \
        "$FILE" >/dev/null 2>&1; then
        echo "Warning: skipping invalid metadata file $(basename "$FILE")" >&2
        continue
    fi

    VERSIONS_JSON=$(jq --slurpfile item "$FILE" '. + $item' <<<"$VERSIONS_JSON")
done
shopt -u nullglob

GENERATED_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

jq \
    --arg component "$COMPONENT" \
    --arg generated "$GENERATED_DATE" \
    'sort_by(.releaseDate // "") | reverse
     | {component: $component, generated: $generated, count: length, versions: .}' \
    <<<"$VERSIONS_JSON" > "$OUTPUT_DIR/versions.json"

cp "$SCRIPT_DIR/index.html" "$OUTPUT_DIR/index.html"

echo "Generated index.html and versions.json ($(jq '.count' "$OUTPUT_DIR/versions.json") versions) in $OUTPUT_DIR"
