#!/usr/bin/env bash
# Resolves the exact Zig version and the install directory, and gives a cache key.
# Inputs come from the environment: INPUT_VERSION, INPUT_INDEX_URL.
set -euo pipefail
source "$GITHUB_ACTION_PATH/common.sh"

index_file=""
if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  # A release never changes, so the version is the key. No download is necessary.
  resolved="$version"
else
  # "master" and other moving keys: read the real version from the index, so
  # that a new build gets a new cache key. install.sh uses the same index file.
  index_file="$(mktemp "${RUNNER_TEMP:-/tmp}/setup-zig-index.XXXXXX")"
  fetch_index "$index_file"
  resolved="$(jq -r --arg v "$version" '.[$v].version // $v' "$index_file")"
fi

target="${archs[0]}-$os"
install_dir="${RUNNER_TOOL_CACHE:-$HOME/.cache}/zig/$resolved/$target"

{
  echo "version=$resolved"
  echo "install-dir=$install_dir"
  echo "cache-path=$(native_path "$install_dir")"
  echo "cache-key=setup-zig-$resolved-$target"
  echo "index-file=$index_file"
} >> "$GITHUB_OUTPUT"
