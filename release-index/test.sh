#!/usr/bin/env bash
#
# Tests for release-index/generate.sh
#
# Usage: release-index/test.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATE="$SCRIPT_DIR/generate.sh"

FAILURES=0
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

pass() { echo "  ok   - $1"; }
fail() { echo "  FAIL - $1" >&2; FAILURES=$((FAILURES + 1)); }

assert_eq() {
    local expected="$1" actual="$2" message="$3"
    if [ "$expected" = "$actual" ]; then
        pass "$message"
    else
        fail "$message (expected '$expected', got '$actual')"
    fi
}

assert_file() {
    local path="$1" message="$2"
    if [ -f "$path" ]; then
        pass "$message"
    else
        fail "$message (missing $path)"
    fi
}

new_case() {
    CASE_DIR="$TMP_ROOT/$1"
    mkdir -p "$CASE_DIR/meta" "$CASE_DIR/out"
    echo "# $1"
}

write_meta() {
    local version="$1" date="$2" prerelease="$3"
    cat > "$CASE_DIR/meta/$version.json" <<EOF
{
  "version": "$version",
  "url": "https://dist.lacylights.com/releases/rpi/lacylights-rpi-$version.tar.gz",
  "sha256": "abc$version",
  "releaseDate": "$date",
  "isPrerelease": $prerelease,
  "fileSize": 120000
}
EOF
}

# --- Builds a sorted manifest and copies the page ---
new_case "sorted manifest"
write_meta "0.2.1" "2025-12-10T16:12:01Z" false
write_meta "0.2.19" "2026-01-07T16:54:53Z" false
write_meta "0.2.0-beta.2" "2025-12-08T17:12:56Z" true
"$GENERATE" "$CASE_DIR/meta" "$CASE_DIR/out" >/dev/null

assert_eq "rpi" "$(jq -r '.component' "$CASE_DIR/out/versions.json")" "component is rpi"
assert_eq "3" "$(jq -r '.count' "$CASE_DIR/out/versions.json")" "count matches number of versions"
assert_eq "0.2.19,0.2.1,0.2.0-beta.2" \
    "$(jq -r '[.versions[].version] | join(",")' "$CASE_DIR/out/versions.json")" \
    "versions sorted newest first by releaseDate"
assert_eq "true" "$(jq -r '.versions[2].isPrerelease' "$CASE_DIR/out/versions.json")" "prerelease flag preserved"
if jq -e '.generated | test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$")' "$CASE_DIR/out/versions.json" >/dev/null; then
    pass "generated timestamp is ISO-8601 UTC"
else
    fail "generated timestamp is ISO-8601 UTC"
fi
if cmp -s "$SCRIPT_DIR/index.html" "$CASE_DIR/out/index.html"; then
    pass "index.html copied to output"
else
    fail "index.html copied to output"
fi

# --- Ignores pointer files and invalid metadata ---
new_case "ignored files"
write_meta "0.2.19" "2026-01-07T16:54:53Z" false
cp "$CASE_DIR/meta/0.2.19.json" "$CASE_DIR/meta/latest.json"
cp "$CASE_DIR/meta/0.2.19.json" "$CASE_DIR/meta/prerelease.json"
echo '{"component":"rpi","versions":[]}' > "$CASE_DIR/meta/versions.json"
echo 'not json' > "$CASE_DIR/meta/broken.json"
echo '{"version":"9.9.9"}' > "$CASE_DIR/meta/9.9.9.json"
echo '[1,2,3]' > "$CASE_DIR/meta/array.json"
touch "$CASE_DIR/meta/lacylights-rpi-0.2.19.tar.gz"
STDERR=$("$GENERATE" "$CASE_DIR/meta" "$CASE_DIR/out" 2>&1 >/dev/null)

assert_eq "0.2.19" "$(jq -r '[.versions[].version] | join(",")' "$CASE_DIR/out/versions.json")" \
    "only valid per-version metadata is included"
case "$STDERR" in
    *broken.json*) pass "warns about invalid JSON" ;;
    *) fail "warns about invalid JSON" ;;
esac
case "$STDERR" in
    *9.9.9.json*) pass "warns about metadata missing url" ;;
    *) fail "warns about metadata missing url" ;;
esac

# --- Rejects metadata that is unsafe or would break the page ---
new_case "rejected metadata"
write_meta "0.2.19" "2026-01-07T16:54:53Z" false
GOOD='{"version":"1.0.0","url":"https://dist.lacylights.com/x.tar.gz","isPrerelease":false}'
printf 'null\n%s\n' "$GOOD" > "$CASE_DIR/meta/multi.json"
echo '{"version":"1.0.1; rm -rf ~","url":"https://dist.lacylights.com/x.tar.gz","isPrerelease":false}' \
    > "$CASE_DIR/meta/badversion.json"
echo '{"version":"1.0.2","url":"javascript:alert(1)","isPrerelease":false}' > "$CASE_DIR/meta/badurl.json"
echo '{"version":"1.0.3","url":"https://dist.lacylights.com/x.tar.gz","isPrerelease":"yes"}' \
    > "$CASE_DIR/meta/badflag.json"
"$GENERATE" "$CASE_DIR/meta" "$CASE_DIR/out" >/dev/null 2>&1

assert_eq "0.2.19" "$(jq -r '[.versions[].version] | join(",")' "$CASE_DIR/out/versions.json")" \
    "multi-value, unsafe version, non-https url and non-boolean prerelease are rejected"

# --- Sorting is deterministic for missing and tied dates ---
new_case "deterministic sort"
write_meta "0.2.1" "2025-12-10T16:12:01Z" false
write_meta "0.2.2" "2025-12-10T16:12:01Z" false
write_meta "0.2.10" "2025-12-10T16:12:01Z" false
echo '{"version":"0.0.1","url":"https://dist.lacylights.com/old.tar.gz","isPrerelease":false}' \
    > "$CASE_DIR/meta/0.0.1.json"
"$GENERATE" "$CASE_DIR/meta" "$CASE_DIR/out" >/dev/null

assert_eq "0.2.10,0.2.2,0.2.1,0.0.1" "$(jq -r '[.versions[].version] | join(",")' "$CASE_DIR/out/versions.json")" \
    "ties broken by numeric version and missing releaseDate sorts last"

# --- Empty metadata directory still produces a valid page ---
new_case "empty"
# Stdin must be ignored: with no files, jq would otherwise read it (or hang)
echo '{"version":"from-stdin"}' | "$GENERATE" "$CASE_DIR/meta" "$CASE_DIR/out" >/dev/null
assert_eq "0" "$(jq -r '.count' "$CASE_DIR/out/versions.json")" "empty directory yields zero versions"
assert_eq "[]" "$(jq -c '.versions' "$CASE_DIR/out/versions.json")" "empty directory yields empty array"
assert_file "$CASE_DIR/out/index.html" "index.html written for empty directory"

# --- Creates the output directory if needed ---
new_case "nested output"
write_meta "0.2.19" "2026-01-07T16:54:53Z" false
"$GENERATE" "$CASE_DIR/meta" "$CASE_DIR/out/a/b" >/dev/null
assert_file "$CASE_DIR/out/a/b/versions.json" "output directory created"

# --- Argument validation ---
new_case "arguments"
set +e
"$GENERATE" >/dev/null 2>&1
assert_eq "2" "$?" "missing arguments exits 2"
"$GENERATE" "$CASE_DIR/does-not-exist" "$CASE_DIR/out" >/dev/null 2>&1
assert_eq "1" "$?" "missing metadata directory exits 1"
set -e

echo
if [ "$FAILURES" -gt 0 ]; then
    echo "$FAILURES test(s) failed" >&2
    exit 1
fi
echo "All tests passed"
