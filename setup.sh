#!/usr/bin/env bash
# herdr-architect setup: preflight, report dir, sol + advisor tabs.
# usage: setup.sh <slug> [high|xhigh|max|ultra]
# Reuses live agents in this workspace (sends sol /new, advisor /clear); otherwise creates them.
# Writes /tmp/herdr-architect/<workspace>.env with SOL, ADVISOR, REPORT_DIR and prints it.
set -euo pipefail
slug=${1:?usage: setup.sh <slug> [high|xhigh|max|ultra]}
effort=${2:-high}
skill_dir=$(cd "$(dirname "$0")" && pwd)

[ "${HERDR_ENV:-}" = 1 ] || { echo "preflight: not inside herdr (HERDR_ENV != 1)" >&2; exit 1; }
[ -n "${HERDR_WORKSPACE_ID:-}" ] || { echo "preflight: HERDR_WORKSPACE_ID unset" >&2; exit 1; }
for c in herdr codex claude python3; do
  command -v "$c" >/dev/null || { echo "preflight: missing $c" >&2; exit 1; }
done
ws=$HERDR_WORKSPACE_ID
report_dir=/tmp/herdr-architect/$(date +%Y%m%d-%H%M%S)-$slug
mkdir -p "$report_dir"
agents=$(herdr agent list)

# live agent of <kind> in this workspace whose name starts with <prefix>: prints "name status"
find_agent() {
  printf '%s' "$agents" | python3 -c '
import json, sys
kind, prefix, ws = sys.argv[1:4]
for a in json.load(sys.stdin)["result"]["agents"]:
    n = a.get("name") or ""
    if a["workspace_id"] == ws and a["agent"] == kind and n.startswith(prefix):
        print(n, a["agent_status"]); break' "$1" "$2" "$ws"
}
name_taken() {
  printf '%s' "$agents" | python3 -c '
import json, sys
sys.exit(0 if any(a.get("name") == sys.argv[1] for a in json.load(sys.stdin)["result"]["agents"]) else 1)' "$1"
}
pick_name() { if name_taken "$1"; then echo "$1-$slug"; else echo "$1"; fi; }

# start_agent <name> <kind> <agent args...>: new tab in $PWD, start, accept Claude's trust dialog if shown
start_agent() {
  local name=$1 kind=$2; shift 2
  local r pane out
  r=$(herdr tab create --workspace "$ws" --cwd "$PWD" --label "$name" --no-focus)
  pane=$(printf '%s' "$r" | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["root_pane"]["pane_id"])')
  if out=$(herdr agent start "$name" --kind "$kind" --pane "$pane" -- "$@" 2>&1); then
    echo "$name: created in pane $pane"; return
  fi
  if printf '%s' "$out" | grep -q agent_not_ready \
     && herdr agent read "$name" --source visible --lines 40 | grep -q 'Yes, I trust this folder'; then
    herdr agent send-keys "$name" down >/dev/null
    herdr agent send-keys "$name" enter >/dev/null
    herdr agent wait "$name" --until idle --until done --timeout 60000 >/dev/null
    echo "$name: created in pane $pane (trust dialog accepted)"; return
  fi
  echo "$name: start failed in pane $pane; screen follows. Handle it, then rerun setup.sh (it will reuse)." >&2
  printf '%s\n' "$out" >&2
  herdr agent read "$name" --source visible --lines 25 >&2 || true
  exit 2
}

# reuse_or_start <prefix> <kind> <reset command> <agent args...>: sets $name
reuse_or_start() {
  local prefix=$1 kind=$2 reset=$3; shift 3
  local found status
  found=$(find_agent "$kind" "$prefix"); status=${found#* }; name=${found%% *}; reused=0
  if [ -n "$name" ]; then
    case $status in
      idle|done) herdr agent prompt "$name" "$reset" >/dev/null; echo "$name: reused ($reset sent)"; reused=1 ;;
      *) echo "$name is $status; finish or close it before starting a new deliverable" >&2; exit 3 ;;
    esac
  else
    name=$(pick_name "$prefix")
    start_agent "$name" "$kind" "$@"
  fi
}

reuse_or_start sol codex /new -m gpt-5.6-sol -c "model_reasoning_effort=$effort" -a on-request -s workspace-write
sol=$name
if [ "$reused" = 1 ] && [ -n "${2:-}" ]; then
  echo "note: $sol was reused and keeps the effort it was launched with; close its tab (herdr tab close) and rerun to get $effort" >&2
fi
reuse_or_start advisor claude /clear --model fable --permission-mode plan \
  --append-system-prompt-file "$skill_dir/advisor-prompt.md"
advisor=$name

env_file=/tmp/herdr-architect/$ws.env
printf 'SOL=%s\nADVISOR=%s\nREPORT_DIR=%s\n' "$sol" "$advisor" "$report_dir" > "$env_file"
echo "env: $env_file"; cat "$env_file"
