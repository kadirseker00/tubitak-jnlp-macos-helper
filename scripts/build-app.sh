#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
repo_root=${script_dir:h}
output_root=${1:-"$repo_root/dist"}
build_root=$(/usr/bin/mktemp -d /tmp/tubitak-jnlp-guard-build.XXXXXX)
app_name='TUBITAK JNLP Guard.app'
app_path="$output_root/$app_name"

cleanup() {
  /bin/rm -rf -- "$build_root"
}
trap cleanup EXIT

if ! command -v swift >/dev/null 2>&1; then
  print -u2 -- 'error: Swift is required. Install Xcode Command Line Tools first.'
  exit 1
fi

/bin/mkdir -p "$output_root"
case "$app_path" in
  "$output_root"/*.app) /bin/rm -rf -- "$app_path" ;;
  *) print -u2 -- 'error: refused to replace an unexpected path'; exit 1 ;;
esac

swift build \
  --package-path "$repo_root" \
  --configuration release \
  --scratch-path "$build_root/swift"

/bin/mkdir -p "$app_path/Contents/MacOS"
/usr/bin/install -m 755 \
  "$build_root/swift/release/TubitakJnlpGuard" \
  "$app_path/Contents/MacOS/TubitakJnlpGuard"
/usr/bin/install -m 644 \
  "$repo_root/Resources/Info.plist" \
  "$app_path/Contents/Info.plist"

/usr/bin/codesign --force --deep --sign - "$app_path"
/usr/bin/codesign --verify --deep --strict "$app_path"

print -- "$app_path"
