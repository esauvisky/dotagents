#!/usr/bin/env bash
set -euo pipefail

agents="$HOME/.agents"
top=$(git -C "$agents" rev-parse --show-toplevel)
if [[ "$top" != "$agents" ]]; then
  echo "install: $agents must be the dotagents checkout" >&2
  exit 1
fi

mkdir -p "$HOME/.claude/skills" "$HOME/.local/bin"

ln -s "$agents/AGENTS.md" "$HOME/.claude/CLAUDE.md"
ln -s "$agents/hooks" "$HOME/.claude/hooks"
ln -s "$agents/commands" "$HOME/.claude/commands"
ln -s "$agents/bin/cfind" "$HOME/.local/bin/cfind"
for s in compress-commits learn prelude; do
  ln -s "$agents/skills/$s" "$HOME/.claude/skills/$s"
done
