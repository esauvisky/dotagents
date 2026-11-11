#!/usr/bin/env bash
# PreToolUse hook (Bash): guard git push and friends.
# Denies pushes that neither the current user prompt nor a [deploy]/[publish]
# commit marker authorize. Warns about credential env vars inherited from the
# interactive shell when the push would trigger CI.
#
# stdin JSON: {"session_id", "tool_name", "tool_input": {"command", ...}, "prompt"?}
# exit 2 = block (stderr is shown to the model); exit 0 = allow.

set -uo pipefail

INPUT=$(cat)
CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
PROMPT=$(jq -r '.prompt // empty' <<<"$INPUT")

is_push() {
  grep -qE '(^|[^a-z-]|\s)git\s+push(\s|$)' <<<" $CMD "
}

prompt_allows() {
  grep -qiE '(push|deploy|publish|send it|ship it).*(please|yeah|yes|go|ok|now|!)|push it|deploy it|publish it|\[deploy\]|\[publish\]|bump.*and push|push and deploy' <<<"$PROMPT"
}

warn_creds() {
  for v in GITLAB_TOKEN GITHUB_TOKEN DOCKER_TOKEN NPM_TOKEN PYPI_TOKEN CF_API_TOKEN; do
    if [ -n "${!v:-}" ]; then
      echo "note: \$${v} is set in this hook's shell (inherited from .bash_globals); it leaks into CI-triggering commands" >&2
    fi
  done
}

if ! is_push; then
  exit 0
fi

prompt_denies() {
  grep -qiE "(don.?t|do not|never|no|not)\\s+(git\\s+)?(push|deploy|publish)" <<<"$PROMPT"
}

prompt_allows() {
  grep -qiE '(push|deploy|publish|send it|ship it).*(please|yeah|yes|go|ok|now|!)|push it|deploy it|publish it|\[deploy\]|\[publish\]|bump.*and push|push and deploy|(and|then)\s+(push|deploy|publish)\b' <<<"$PROMPT"
}

# an explicit "don't push" in the current prompt wins over everything, including the marker
if [ -n "$PROMPT" ] && prompt_denies; then
  echo "push blocked: the current prompt says not to push." >&2
  exit 2
fi

if [ -n "$PROMPT" ] && prompt_allows; then
  warn_creds
  exit 0
fi

REPO_TOP=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [ -n "$REPO_TOP" ]; then
  if git -C "$REPO_TOP" log --format='%s' @{push}.. 2>/dev/null | grep -qiE '\[(deploy|publish)\]'; then
    warn_creds
    exit 0
  fi
  BRANCH=$(git -C "$REPO_TOP" symbolic-ref --short HEAD 2>/dev/null || true)
  if [ -n "${BRANCH:-}" ] \
     && git -C "$REPO_TOP" log --format='%s' "origin/${BRANCH}.." 2>/dev/null | grep -qiE '\[(deploy|publish)\]'; then
    warn_creds
    exit 0
  fi
fi

echo "push blocked: no [deploy]/[publish] marker on unpushed commits and the current prompt does not authorize a push." >&2
echo "To authorize: ask the user, or amend the commit subject to include [deploy] or [publish]." >&2
exit 2
