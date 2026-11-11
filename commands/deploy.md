---
description: Bump version, commit, push and watch the deploy pipeline (authorized by the [deploy] marker this command creates)
argument-hint: [message] [--no-bump]
allowed-tools: Bash(git add:*), Bash(git commit:*), Bash(git log:*), Bash(git status:*), Bash(git diff:*), Bash(ssh:*), Bash(git push:*)
---

# /deploy: commit with [deploy] marker, push, watch the pipeline

You are in repo: $ARGUMENTS message.

Steps:

1. **Pre-flight**
   - `git status --porcelain` — confirm what's changing; if the tree is clean, there is nothing to do: say so and stop.
   - Identify the version source: `package.json` ("version" field), `pyproject.toml` (`[project] version`), `Chart.yaml` (`appVersion`/`version`), `gradle` (`versionCode`/`versionName` in `app/build.gradle[.kts]`), or an `VERSION`/`VERSION.txt` file. If exactly one exists, bump it (patch level, `X.Y.Z` → `X.Y.Z+1`; for gradle, versionCode +1 and versionName patch bump). If several version sources exist, ask which one is canonical.
   - If `--no-bump` was passed, skip the bump.
   - Run the repo's `## Checks` command from AGENTS.md first if the change is code (not config-only); if it fails, stop and report.

2. **Commit with marker**
   - Stage only the files discussed (never `git add -A` when the change spans unrelated work; ask if ambiguous).
   - Subject: `<short what changed> [deploy]` — single line, no body, e.g. `fix widget timeout [deploy]`. Ask the user to confirm the message before committing if this is the first push in this task; otherwise just show the version bump in the subject, e.g. `bump to 1.2.4 [deploy]`.
   - `git add` + `git commit` with the marker subject.

3. **Push**
   - `git push`. The push-guard hook authorizes exactly this: the unpushed commits now carry `[deploy]`.

4. **Watch the pipeline**
   - Identify how this repo deploys: GitLab CI (`.gitlab-ci.yml` present) → poll the pipeline: `glab ci status` or the repo's CI watch command if documented in AGENTS.md; docker stack on h1-h5.pokemod.dev → `ssh <host> docker service ls | grep <stack>` then `docker service logs --tail 50 <service>` to confirm the new version came up. If the AGENTS.md documents the canonical watch command, use that one.

5. **Report**
   - Version bumped: from → to. Commit hash + subject. Pipeline result (pass/fail and links). Service logs tail if it deployed.
   - If anything fails, report exactly what failed with the tail of the error and stop — do not attempt counter-fixes without being asked.
