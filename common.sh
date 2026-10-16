# Shared helpers for resolve.sh and install.sh. Source this file, do not run it.
# Sets: os, archs, version, index_url.

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

# jq on Windows can print CRLF line endings.
jq() { command jq "$@" | tr -d '\r'; }

# Downloads index.json to the file in $1.
fetch_index() {
  curl --fail --silent --show-error --location --retry 3 --output "$1" "$index_url" \
    || fail "Could not download the Zig index from $index_url"
  jq -e --arg v "$version" 'has($v)' "$1" > /dev/null \
    || fail "Zig version '$version' is not in $index_url. Available: $(jq -r 'keys_unsorted | join(", ")' "$1")"
}

# Prints a path in the native form of the runner (Windows paths on Windows).
native_path() {
  if [[ "$os" == windows ]] && command -v cygpath > /dev/null; then
    cygpath -w "$1"
  else
    echo "$1"
  fi
}
