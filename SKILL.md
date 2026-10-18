---
name: herdr-architect
description: Architect pattern over Herdr tabs. This session is the architect and never types implementation code. GPT-5.6 Sol (Codex in a Herdr tab) implements from written specs; Fable 5.1 (Claude Code in a second Herdr tab, plan mode) advises at commitment boundaries and reviews every deliverable before it is reported done. USE WHEN the user asks to build or fix something "with Sol", "via Codex", "with the architect pattern", or asks for a Fable review. Requires HERDR_ENV=1, codex, claude, python3.
---

# Herdr architect

| Role | Who | Where |
|---|---|---|
| Architect | this session, any model | calling pane: specs, verification, reporting; no implementation code |
| Implementer | GPT-5.6 Sol (Codex) | tab `$SOL`, persistent, one topic at a time |
| Advisor | Fable 5.1 (Claude Code, plan mode) | tab `$ADVISOR`, read-only, cleared after every consult |

Every Herdr command this pattern needs is below. Open `herdr --skill` only when one of them errors.

## Rules

- **Emit judgment, not volume.** A code block longer than an interface signature is a spec you have not delegated yet. Fixing Sol's bug by hand is the same failure: send a corrective prompt instead.
- **Keep this context lean.** Read Sol's report file, not its scrollback. Never paste transcripts or full diffs into the conversation.
- **Never idle while Sol works.** Hand off, then write the next spec or the consult. Waiting is the last thing you do, not the first.
- **Reports are claims.** Read the diff and re-run verification yourself. An empty diff is a refusal whatever the report says.
- **Never approve on the user's behalf.** A `blocked` state means Codex wants something outside its sandbox: show it to the user and wait.

## Setup, once per deliverable

```bash
~/.claude/skills/herdr-architect/setup.sh <slug> [high|xhigh|max|ultra]
```

Preflight (`HERDR_ENV=1`, `herdr`, `codex`, `claude`, `python3`), report dir, both tabs. A live `sol*` or `advisor*` agent in `$HERDR_WORKSPACE_ID` is reused (`/new` and `/clear` sent); otherwise the tabs are created in `$PWD` without taking focus, and the Codex and Claude folder-trust dialogs are accepted. It writes `/tmp/herdr-architect/$HERDR_WORKSPACE_ID.env` holding `SOL`, `ADVISOR`, `REPORT_DIR` (under `~/.local/state/herdr-architect/`), `SKILL_DIR`, and `BASE` (tree snapshot at setup, untracked files included); every command below starts by sourcing it. A non-zero exit says what failed. A missing prerequisite means stop and say so; never implement the work yourself. A blocked agent screen goes to the user; rerun once resolved.

The tabs live for one deliverable: setup reuses a live pair, `teardown.sh` at the end closes them. Skip teardown only when the user has said more Sol work is coming this session. Sol's effort holds for the life of the tab (to change it, run teardown and rerun setup): `high` by default, `xhigh` for tricky multi-file logic, `max` for concurrency, security, or hard debugging, `ultra` only for wide refactors. Sol runs with `-a on-request -s workspace-write --add-dir <reports root>`, full-auto inside the working tree, /tmp and the reports root; never bypass the sandbox. The advisor runs `claude --model fable --permission-mode plan` with `advisor-prompt.md` appended to its system prompt.

## Delegating to Sol

Sol shares none of your conversation. A spec has six parts: **objective** (one paragraph), **files** (exact paths), **interfaces** (the contracts other code depends on: CLI flags, signatures, schemas, seams for tests; internal module layout is Sol's call unless it matters), **constraints** (the project's own; `sol-rules.md` adds the standing ones), **verification** (the command that proves it), and **report path** (`$REPORT_DIR/<task-id>.md`). A spec you cannot finish writing means a decision is not made yet; make it, do not hand ambiguity to Sol.

```bash
# spec written to $REPORT_DIR/spec-<task-id>.md
. /tmp/herdr-architect/$HERDR_WORKSPACE_ID.env
herdr agent prompt "$SOL" "$(cat "$REPORT_DIR/spec-<task-id>.md" "$SKILL_DIR/sol-rules.md")" --wait --until working --timeout 10000
# returns within a second once Sol is working; now write the next spec or consult
herdr agent wait "$SOL" --timeout 1800000
cat "$REPORT_DIR/<task-id>.md"; git add -N . && git diff --stat $BASE
# then re-run the verification command yourself
```

`agent_prompt_stalled` means the prompt never started: check `agent get "$SOL"` and the screen, then `agent wait`; do not re-send. No report file means Sol did not finish: read `herdr agent read "$SOL" --source recent-unwrapped --lines 60`. A wrong or partial result gets a short corrective follow-up in the same tab, since Sol keeps its context. After the second failed attempt on one task, stop and consult the advisor.

Send `/new` (no `--wait`) before a task in an unrelated area, or when the status line shows context above about 70 percent; the next spec is then fully self-contained again. A second Codex tab (`sol-2`, started by hand with the flags in `setup.sh`) is only for disjoint files when the user asks for speed.

## Consulting the advisor

Consult before committing to an architecture, migration, API shape, or refactor strategy; when a problem has resisted two attempts; and **once at the end of a deliverable**, before reporting done. When the deliverable has several tasks, review the finished task while Sol works on the next one.

```bash
. /tmp/herdr-architect/$HERDR_WORKSPACE_ID.env
git add -N . && git diff $BASE > "$REPORT_DIR/review.diff"   # final review only; edits that predate setup stay out
herdr agent prompt "$ADVISOR" "$(cat "$REPORT_DIR/consult.md")" --wait --timeout 600000
herdr agent read "$ADVISOR" --source recent-unwrapped --lines 200
herdr agent prompt "$ADVISOR" "/clear"    # after reading: the tab is clean for the next consult
```

The consult carries the goal, the constraints, and either the options considered or the diff path plus verification evidence. Point at files by path; the advisor reads them. Its answer is the `●` block between the echoed consult and the empty `❯` input line, and ends with `VERDICT: ship | fix-first | rethink`. Act on it or surface the disagreement.

`fix-first` goes back to Sol as a numbered spec of exactly the flagged items. Verify the fix yourself against that list; a fresh review is needed only when the fix touched more than the flagged items or the verdict was `rethink`.

## Done

Final consult answered, then:

```bash
~/.claude/skills/herdr-architect/teardown.sh    # refuses while an agent is working or blocked
```

Then report once. The user reads nothing else, so it stands alone; it comes from the Sol reports, your verification run, and the advisor's answer, never from scrollback. Bold labels, each a line or a short list:

```
Outcome:  done | stopped, and why in one sentence
Changed:  file or file group: what it does now, one per line; Sol's judgment calls; corrective rounds and what was wrong
Verified: the command you re-ran and the lines of output that prove it, in a code block
Review:   advisor verdict; each flagged item and how it was resolved
Open:     gaps from the Sol reports, anything unverified, decisions for the user, or none
Where:    $REPORT_DIR
```
