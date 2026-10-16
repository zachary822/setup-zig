#!/usr/bin/env bash
# Installs a Zig release that matches the runner OS/arch and adds it to PATH.
# Inputs come from the environment: INPUT_VERSION, INPUT_INDEX_URL.
set -euo pipefail

version="${INPUT_VERSION:?the 'version' input is required}"
index_url="${INPUT_INDEX_URL:-https://ziglang.org/download/index.json}"

fail() {
  echo "::error::$*"
  exit 1
}

# Map the GitHub runner OS/arch to the keys used in index.json.
case "${RUNNER_OS:-$(uname -s)}" in
  Linux) os=linux ;;
  macOS | Darwin) os=macos ;;
  Windows | MINGW* | MSYS* | CYGWIN*) os=windows ;;
  *) fail "Unsupported runner OS: ${RUNNER_OS:-$(uname -s)}" ;;
esac

case "${RUNNER_ARCH:-$(uname -m)}" in
  X64 | x86_64 | amd64) archs=(x86_64) ;;
  ARM64 | arm64 | aarch64) archs=(aarch64) ;;
  # Newer releases use "x86", older releases use "i386".
  X86 | i386 | i686) archs=(x86 i386) ;;
  ARM | armv7l) archs=(armv7a arm) ;;
  *) fail "Unsupported runner architecture: ${RUNNER_ARCH:-$(uname -m)}" ;;
esac

command -v jq > /dev/null || fail "jq is required but was not found on PATH"

index="$(curl --fail --silent --show-error --location --retry 3 "$index_url")" \
  || fail "Could not download the Zig index from $index_url"

# jq on Windows can print CRLF line endings.
jq() { command jq "$@" | tr -d '\r'; }

jq -e --arg v "$version" 'has($v)' <<< "$index" > /dev/null \
  || fail "Zig version '$version' is not in $index_url. Available: $(jq -r 'keys_unsorted | join(", ")' <<< "$index")"

target=""
for arch in "${archs[@]}"; do
  if jq -e --arg v "$version" --arg t "$arch-$os" '.[$v] | has($t)' <<< "$index" > /dev/null; then
    target="$arch-$os"
    break
  fi
done
[[ -n "$target" ]] || fail "Zig $version has no build for ${archs[0]}-$os"

tarball="$(jq -r --arg v "$version" --arg t "$target" '.[$v][$t].tarball' <<< "$index")"
shasum="$(jq -r --arg v "$version" --arg t "$target" '.[$v][$t].shasum' <<< "$index")"
# For "master" the key is not the real version, so read it from the entry.
resolved="$(jq -r --arg v "$version" '.[$v].version // $v' <<< "$index")"

install_dir="${RUNNER_TOOL_CACHE:-$HOME/.cache}/zig/$resolved/$target"

if [[ -x "$install_dir/zig" || -x "$install_dir/zig.exe" ]]; then
  echo "Zig $resolved ($target) is already in the tool cache at $install_dir"
else
  echo "Downloading $tarball"
  work="$(mktemp -d "${RUNNER_TEMP:-/tmp}/setup-zig.XXXXXX")"
  archive="$work/$(basename "$tarball")"
  curl --fail --silent --show-error --location --retry 3 --output "$archive" "$tarball" \
    || fail "Could not download $tarball"

  if command -v sha256sum > /dev/null; then
    # Read from stdin: with a path that contains backslashes (Windows), sha256sum
    # adds a leading "\" escape to the output.
    actual="$(sha256sum < "$archive" | cut -d' ' -f1)"
  else
    actual="$(shasum -a 256 < "$archive" | cut -d' ' -f1)"
  fi
  [[ "$actual" == "$shasum" ]] || fail "Checksum mismatch for $tarball: expected $shasum, got $actual"

  mkdir -p "$work/extract"
  case "$archive" in
    *.zip) unzip -q "$archive" -d "$work/extract" ;;
    *.tar.xz) tar -xJf "$archive" -C "$work/extract" ;;
    *) fail "Unknown archive format: $archive" ;;
  esac

  # The archive holds one top-level directory. Its name format differs between releases.
  extracted=("$work/extract"/*)
  [[ ${#extracted[@]} -eq 1 && -d "${extracted[0]}" ]] || fail "Unexpected archive layout in $tarball"

  rm -rf "$install_dir"
  mkdir -p "$(dirname "$install_dir")"
  mv "${extracted[0]}" "$install_dir"
  rm -rf "$work"
fi

path_entry="$install_dir"
if [[ "$os" == windows ]] && command -v cygpath > /dev/null; then
  path_entry="$(cygpath -w "$install_dir")"
fi

echo "$path_entry" >> "$GITHUB_PATH"
{
  echo "version=$resolved"
  echo "zig-dir=$path_entry"
} >> "$GITHUB_OUTPUT"

"$install_dir/zig" version
echo "Installed Zig $resolved ($target) to $path_entry"
