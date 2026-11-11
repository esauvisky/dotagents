#!/usr/bin/env bash
# Stop hook: remind about unverified work when the session ends.
# If the repo's AGENTS.md declares a `## Checks` section with the canonical
# check/test command and it never ran in this session's Bash history, print a
# loud reminder so unverified work doesn't slip through.
#
# stdin JSON: {"session_id", "transcript_path", "stop_hook_active", ...}
# Non-blocking (exit 0); output on stderr is informational.

set -uo pipefail

INPUT=$(cat)
TRANSCRIPT=$(jq -r '.transcript_path // empty' <<<"$INPUT")
CWD=$(jq -r '.cwd // empty' <<<"$INPUT")

[ -n "$TRANSCRIPT" ] || exit 0

REPO_TOP=$(git -C "${CWD:-$PWD}" rev-parse --show-toplevel 2>/dev/null || true)
[ -n "$REPO_TOP" ] || exit 0

AGENTS="$REPO_TOP/AGENTS.md"
[ -f "$AGENTS" ] || exit 0

# The repo's canonical check command: the first `check:` line under an explicit
# `## Checks` heading. Repos opt in by declaring that section. Backticks are
# stripped so the extracted command matches what a real Bash call looks like.
CHECK=$(awk '/^## Checks/{insec=1; next} /^## /{insec=0} insec && /check:/{sub(/^ *check: */,""); gsub(/`/,""); print; exit}' "$AGENTS" 2>/dev/null)
[ -n "$CHECK" ] || exit 0

# dirty tree?
if [ -n "$(git -C "$REPO_TOP" status --porcelain 2>/dev/null)" ]; then
  DIRTY="yes"
else
  DIRTY="no"
fi

# did the check run in this session?
check_ran() {
  # cheapest reliable signal: the command string appears in assistant Bash tool_use in this transcript
  zgrep -qF "$CHECK" "$TRANSCRIPT" 2>/dev/null \
    || grep -aF "$CHECK" "$TRANSCRIPT" 2>/dev/null >/dev/null \
    || jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Bash") | .input.command' "$TRANSCRIPT" 2>/dev/null | grep -qF -- "$CHECK"
}

if ! check_ran && [ "$DIRTY" = yes ]; then
  echo "UNVERIFIED WORK: the tree is dirty but the repo's check never ran this session." >&2
  echo "Check command from ${AGENTS}:" >&2
  echo "  $CHECK" >&2
  echo "Run it before calling this done, or say you can't and why." >&2
fi

exit 0
