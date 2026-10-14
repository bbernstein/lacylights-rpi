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

# A metadata file must hold exactly one object with the fields the page needs.
# The version ends up in a shell command visitors copy, so restrict its charset.
VALID_METADATA='length == 1 and (.[0] | type == "object"
    and (.version | type == "string" and test("^[0-9A-Za-z.+-]+$"))
    and (.url | type == "string" and startswith("https://"))
    and (.isPrerelease | type == "boolean"))'

VALID_FILES=()
shopt -s nullglob
for FILE in "$METADATA_DIR"/*.json; do
    case "$(basename "$FILE")" in
        latest.json|prerelease.json|versions.json) continue ;;
    esac

    if ! jq -s -e "$VALID_METADATA" "$FILE" >/dev/null 2>&1; then
        echo "Warning: skipping invalid metadata file $(basename "$FILE")" >&2
        continue
    fi

    VALID_FILES+=("$FILE")
done
shopt -u nullglob

GENERATED_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')

# Newest first. Version breaks releaseDate ties so output is deterministic;
# numeric parts compare as numbers so 0.2.19 sorts above 0.2.9.
jq -n \
    --arg component "$COMPONENT" \
    --arg generated "$GENERATED_DATE" \
    '[inputs]
     | sort_by([(.releaseDate // ""), (.version | [splits("[.+-]") | tonumber? // .])])
     | reverse
     | {component: $component, generated: $generated, count: length, versions: .}' \
    ${VALID_FILES[@]+"${VALID_FILES[@]}"} < /dev/null > "$OUTPUT_DIR/versions.json"

cp "$SCRIPT_DIR/index.html" "$OUTPUT_DIR/index.html"

echo "Generated index.html and versions.json ($(jq '.count' "$OUTPUT_DIR/versions.json") versions) in $OUTPUT_DIR"
