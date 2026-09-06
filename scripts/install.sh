#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
repo_root=${script_dir:h}
user_home=${HOME:?}
label='org.kadirseker.TubitakJnlpGuard'
bundle_id='org.kadirseker.TubitakJnlpGuard'
support_dir="$user_home/Library/Application Support/TubitakJnlpGuard"
installed_app="$support_dir/TUBITAK JNLP Guard.app"
authorization_marker="$support_dir/authorization.ok"
launch_agent="$user_home/Library/LaunchAgents/$label.plist"
log_file="$user_home/Library/Logs/TubitakJnlpGuard.log"
downloads_dir="$user_home/Downloads"
stage_root=$(/usr/bin/mktemp -d /tmp/tubitak-jnlp-guard-install.XXXXXX)

cleanup() {
  /bin/rm -rf -- "$stage_root"
}
trap cleanup EXIT

print -- 'Building TUBITAK JNLP Guard locally...'
"$repo_root/scripts/build-app.sh" "$stage_root" >/dev/null

/bin/mkdir -p "$support_dir" "$user_home/Library/LaunchAgents" "$user_home/Library/Logs"
case "$installed_app" in
  "$support_dir"/*.app) /bin/rm -rf -- "$installed_app" ;;
  *) print -u2 -- 'error: refused to replace an unexpected app path'; exit 1 ;;
esac
/usr/bin/ditto "$stage_root/TUBITAK JNLP Guard.app" "$installed_app"

launch_services='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
"$launch_services" -f "$installed_app"

/bin/rm -f -- "$authorization_marker"
print -- 'A macOS Downloads permission prompt will appear. Choose Allow.'
/usr/bin/open -n -W "$installed_app" --args --authorize

if [[ ! -f "$authorization_marker" ]]; then
  print -u2 -- 'error: Downloads access was not granted. Run this installer again and choose Allow.'
  exit 1
fi

staged_agent="$stage_root/$label.plist"
/bin/cp "$repo_root/Resources/LaunchAgent.plist" "$staged_agent"
/usr/bin/plutil -replace ProgramArguments.0 \
  -string "$installed_app/Contents/MacOS/TubitakJnlpGuard" \
  "$staged_agent"
/usr/bin/plutil -replace WatchPaths.0 -string "$downloads_dir" "$staged_agent"
/usr/bin/plutil -replace StandardOutPath -string "$log_file" "$staged_agent"
/usr/bin/plutil -replace StandardErrorPath -string "$log_file" "$staged_agent"
/usr/bin/plutil -lint "$staged_agent"

uid_value=$(/usr/bin/id -u)
/bin/launchctl bootout "gui/$uid_value/$label" >/dev/null 2>&1 || true
/usr/bin/install -m 644 "$staged_agent" "$launch_agent"
/bin/launchctl bootstrap "gui/$uid_value" "$launch_agent"
/bin/launchctl kickstart -k "gui/$uid_value/$label"

print -- ''
print -- 'Installed successfully.'
print -- 'New trusted TUBITAK JNLP downloads will be processed automatically.'
print -- "Log: $log_file"
print -- "Bundle ID: $bundle_id"
