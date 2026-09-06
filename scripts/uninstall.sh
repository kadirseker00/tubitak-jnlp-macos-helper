#!/bin/zsh

set -euo pipefail

user_home=${HOME:?}
label='org.kadirseker.TubitakJnlpGuard'
bundle_id='org.kadirseker.TubitakJnlpGuard'
support_dir="$user_home/Library/Application Support/TubitakJnlpGuard"
launch_agent="$user_home/Library/LaunchAgents/$label.plist"
log_file="$user_home/Library/Logs/TubitakJnlpGuard.log"
uid_value=$(/usr/bin/id -u)

/bin/launchctl bootout "gui/$uid_value/$label" >/dev/null 2>&1 || true
/bin/rm -f -- "$launch_agent" "$log_file"

case "$support_dir" in
  "$user_home/Library/Application Support/TubitakJnlpGuard")
    /bin/rm -rf -- "$support_dir"
    ;;
  *)
    print -u2 -- 'error: refused to remove an unexpected support path'
    exit 1
    ;;
esac

/usr/bin/tccutil reset SystemPolicyDownloadsFolder "$bundle_id" >/dev/null 2>&1 || true
print -- 'TUBITAK JNLP Guard was removed.'
