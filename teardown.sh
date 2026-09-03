#!/usr/bin/env bash
# herdr-architect teardown: close the sol and advisor tabs, drop the env file, keep the report dir.
# usage: teardown.sh [--force]
# Refuses if either agent is not idle or done. --force closes a working agent; a blocked one is never closed.
set -euo pipefail
[ -n "${HERDR_WORKSPACE_ID:-}" ] || { echo "teardown: HERDR_WORKSPACE_ID unset" >&2; exit 1; }
env_file=/tmp/herdr-architect/$HERDR_WORKSPACE_ID.env
[ -f "$env_file" ] || { echo "teardown: no env file at $env_file (nothing to close)" >&2; exit 0; }
# shellcheck disable=SC1090
. "$env_file"

# resolve <name>: prints "status tab_id", or nothing when the agent is gone
resolve() {
  local info
  info=$(herdr agent get "$1" 2>/dev/null) || return 0
  python3 -c 'import json,sys; a=json.load(sys.stdin)["result"]["agent"]; print(a["agent_status"], a["tab_id"])' <<<"$info"
}

tabs=(); busy=0
for name in "$SOL" "$ADVISOR"; do
  read -r status tab <<<"$(resolve "$name")"
  case ${status:-gone} in
    gone) echo "$name: not running" ;;
    idle|done) tabs+=("$tab") ;;
    blocked) echo "$name is blocked in tab $tab: it is waiting on the user; not closing" >&2; busy=1 ;;
    *) if [ "${1:-}" = --force ]; then tabs+=("$tab"); else echo "$name is $status in tab $tab; rerun with --force to close anyway" >&2; busy=1; fi ;;
  esac
done
[ "$busy" = 0 ] || { echo "nothing closed; env file kept at $env_file" >&2; exit 1; }

for tab in "${tabs[@]}"; do herdr tab close "$tab" >/dev/null; echo "closed tab $tab"; done
rm -f "$env_file"
echo "env file removed; reports kept in $REPORT_DIR"
