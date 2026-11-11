# dotagents

My global agent configuration: one `AGENTS.md` with instructions, skills, slash commands, hooks, and a terminal helper. Built for Claude Code. The layout follows the `~/.agents` convention so other harnesses can reuse the same files.

## Layout

| Path | What it is |
|---|---|
| `AGENTS.md` | Global instructions. Linked as `~/.claude/CLAUDE.md`. |
| `bin/cfind` | Terminal command that finds an earlier session by description and resumes it. |
| `commands/deploy.md` | `/deploy`: bump version, commit, push, watch the pipeline. |
| `commands/release-note.md` | `/release-note`: draft a release announcement from commits and Discord exports. |
| `hooks/guard-push.sh` | PreToolUse (Bash): blocks `git push` unless the prompt or a `[deploy]`/`[publish]` commit marker authorizes it. Warns about credential variables inherited from the shell. |
| `hooks/stop-verify.sh` | Stop: reminds you when the repo's `## Checks` command never ran in the session. |
| `hooks/auto-title.sh` | Stop: every 10 user turns, writes a short AI-generated title for the session. Titles set by hand are never overwritten. |
| `hooks/split-session.sh` | UserPromptSubmit: a message starting with `%` forks the session into a new terminal. `%<text>` also sends `<text>` to the fork as its first prompt. |
| `skills/compress-commits` | Rewrites local, unpushed commits into a few clean feature commits. |
| `skills/learn` | `/learn`: scans the session, proposes skills, commands, hooks, or AGENTS.md entries, and builds the ones you pick. |

## Commands

### `cfind "<description>"`

Asks a model to pick from the 50 most recently modified sessions across all projects. It shows up to three matches. Type a number to `cd` into that session's directory and resume it.

Requires `claude` and `jq` on `PATH`.

### `%` prefix (hook)

- `%` forks the current session into a new `gnome-terminal` window.
- `%do this and that` forks the session and sends `do this and that` immediately.
- `%/learn` forks the session and runs `/learn` there.

The original message is blocked, so it never reaches the model in the current session.

Requires `jq` and `gnome-terminal`. Linux with GNOME.

### `/deploy`, `/release-note`

Project-specific. They assume a git repo with a deploy pipeline, and `/release-note` assumes optional Discord exports. Adapt them before use.

## Restore on a new machine

```
git clone git@github.com:esauvisky/dotagents.git ~/.agents
~/.agents/install.sh
```

Then merge the hook block below into `~/.claude/settings.json`.

`install.sh` creates the symlinks listed below. It fails if a target already exists, so it never overwrites a file.

## Symlinks created by `install.sh`

- `~/.claude/CLAUDE.md` → `AGENTS.md`
- `~/.claude/hooks` → `hooks/`
- `~/.claude/commands` → `commands/`
- `~/.claude/skills/<name>` → `skills/<name>` for each shipped skill
- `~/.local/bin/cfind` → `bin/cfind`
- `~/.<harness>/skills` → `~/.agents/skills` for each other harness that is installed (`.iflow`, `.qwen`, `.augment`, `.openhands`, `.openclaw`, `.qoder`, `.config/goose`)

Other harnesses see everything in `~/.agents/skills`, including skills installed there from third-party sources.

## Hook registration

Hooks run only when they appear in `~/.claude/settings.json`. That file isn't in this repo because it holds credentials. Add these entries:

```json
{
  "hooks": {
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "$HOME/.claude/hooks/guard-push.sh"}]}
    ],
    "Stop": [
      {"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/stop-verify.sh"}]},
      {"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/auto-title.sh"}]}
    ],
    "UserPromptSubmit": [
      {"hooks": [{"type": "command", "command": "$HOME/.claude/hooks/split-session.sh"}]}
    ]
  }
}
```

## Dependencies

- `claude` (Claude Code CLI)
- `jq`
- `git`
- `gnome-terminal` (for `%`)
- `gio` (for trashing files instead of deleting them)

## Not included

- **Third-party skills**, including `prelude`. Install them from their upstream repositories.
- **Skills with personal paths or third-party code:** `re-android`, `reverse-engineer-anything`, `playstore`, `huashu-design`, `humanizer`.
- **Credentials and per-machine state:** `settings.json`, OAuth and credential files, session and transcript history, eval workspaces.
