#!/usr/bin/env bash
# Installs a Zig release that matches the runner OS/arch and adds it to PATH.
# Inputs come from the environment: INPUT_VERSION, INPUT_INDEX_URL, and from
# resolve.sh: ZIG_VERSION, ZIG_INSTALL_DIR, ZIG_INDEX_FILE.
set -euo pipefail
source "$GITHUB_ACTION_PATH/common.sh"

resolved="${ZIG_VERSION:?}"
install_dir="${ZIG_INSTALL_DIR:?}"

if [[ -x "$install_dir/zig" || -x "$install_dir/zig.exe" ]]; then
  echo "Zig $resolved is already in the tool cache at $install_dir"
else
  work="$(mktemp -d "${RUNNER_TEMP:-/tmp}/setup-zig.XXXXXX")"

  index_file="${ZIG_INDEX_FILE:-}"
  if [[ -z "$index_file" ]]; then
    index_file="$work/index.json"
    fetch_index "$index_file"
  fi

  target=""
  for arch in "${archs[@]}"; do
    if jq -e --arg v "$version" --arg t "$arch-$os" '.[$v] | has($t)' "$index_file" > /dev/null; then
      target="$arch-$os"
      break
    fi
  done
  [[ -n "$target" ]] || fail "Zig $version has no build for ${archs[0]}-$os"

  tarball="$(jq -r --arg v "$version" --arg t "$target" '.[$v][$t].tarball' "$index_file")"
  shasum="$(jq -r --arg v "$version" --arg t "$target" '.[$v][$t].shasum' "$index_file")"

  echo "Downloading $tarball"
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

[[ -z "${ZIG_INDEX_FILE:-}" ]] || rm -f "$ZIG_INDEX_FILE"

path_entry="$(native_path "$install_dir")"
echo "$path_entry" >> "$GITHUB_PATH"
echo "zig-dir=$path_entry" >> "$GITHUB_OUTPUT"

"$install_dir/zig" version
echo "Installed Zig $resolved to $path_entry"
