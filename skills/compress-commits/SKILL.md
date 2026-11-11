---
name: compress-commits
description: Rewrite a stack of local, unpushed commits into a small number of clean, reviewable feature commits. Use whenever the user wants to squash, compress, condense, tidy, clean up, reorganize, or "fix up" their commit history before pushing or opening a PR, mentions a messy tree of back-and-forth commits (reverts of reverts, "fix fix", "wip", "update"), or gives a base SHA/ref and asks to collapse everything after it. Also use when they ask to split one big diff into logical commits. Not for rewriting commits that already exist on a remote branch unless they explicitly say to force it.
---

# Compress commits

Turn `BASE..HEAD` into the commits a careful human would have made if they had known the end result from the start: one commit per feature, dependencies first, no churn, one `cleanup` commit at the end for the leftovers.

The input is a base commit (SHA, ref, `HEAD~N`, `origin/main`). The base itself is never touched. Everything after it is rebuilt from scratch.

## Why rebuild instead of interactive rebase

LLM-driven development leaves histories where commit 3 half-reverts commit 1, commit 7 fixes a typo from commit 4, and "update" touches five features at once. Reordering or squashing those commits still carries the churn around. The net diff `BASE..HEAD` is the only thing that matters, so the workflow is: compute the net diff, group it by feature, commit the groups in dependency order. Nothing from the old commits survives except their intent.

## Workflow

### 1. Preconditions and safety net

```bash
BASE=$(git rev-parse --verify "$1^{commit}")
git merge-base --is-ancestor "$BASE" HEAD        # otherwise stop: base is not behind HEAD
git rev-list --merges "$BASE"..HEAD              # must be empty: merges are out of scope, stop and say so
git log --format='%h %s' "$BASE"..HEAD
```

Refuse to rewrite published history. For the first commit after the base, check every remote-tracking branch:

```bash
FIRST=$(git rev-list --reverse "$BASE"..HEAD | head -1)
git branch -r --contains "$FIRST"
```

If any branch is listed, stop and show it. The only exception is the user saying "force" (or equivalent) in the request that invoked the skill; a prior "force" never carries over.

Then make the rewrite reversible before touching anything:

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
BACKUP="refs/compress-backup/${BRANCH//\//-}-$(date +%Y%m%d-%H%M%S)"
git update-ref "$BACKUP" HEAD
```

Print the restore command right away so it is in the transcript even if something goes wrong later:

```
git reset --hard <BACKUP>
```

If the working tree is dirty (`git status --porcelain` non-empty), stash it including untracked files: `git stash push -u -m compress-commits`. Remember that you did; it must be popped at the end. If the pop conflicts at the end, leave the stash in place and tell the user, do not try to resolve it.

### 2. Understand the net change

Start with the summary, not the full diff:

```bash
git diff --stat "$BASE" HEAD
git log --oneline "$BASE"..HEAD
```

The stat tells you which files changed and how much. The oneline log gives you the author's intent. Do **not** read `git log --stat` or `git log -p`; the subjects are enough for intent and the old patches are mostly churn.

Now read only the files you need detail on. Files that are clearly one feature (new file in a feature directory, deletion of a feature file, a file touched by only one logical change according to the stat) do not need their diff read at all; you will `git add` them whole. Read the diff only for **shared files** (files whose hunks belong to more than one commit) and **ambiguous files** (you cannot tell from the stat which feature they belong to):

```bash
git diff "$BASE" HEAD -- path/to/shared1 path/to/shared2
```

While reading, note two lists:

- **Features**: the independent, reviewable units of work. A feature is something a reviewer could approve on its own and a user could notice: "add blacklist option", "merge randomized MACs by hostname", "add benchmark runner". Fixes belong to the feature they fix. A helper that exists only for one feature belongs to that feature. Tests for a feature belong with the feature.
- **Leftovers**: things that exist in the net diff only because of the back-and-forth. Typical: an import that nothing uses anymore, a helper whose only caller was reverted, a debug print, commented-out code from an abandoned attempt, a comment describing behavior that no longer exists, a stale TODO. The user wants a cleaner result than the original HEAD, so these are to be removed, not preserved. Be certain before removing: confirm with grep that a symbol really has no callers. Never remove anything that changes behavior, and never "improve" code that is not a leftover.

### 3. Plan the commits

Decide the full commit list before staging anything, and write it down as a short list: one-line message plus the files or hunks it owns. Then execute the list; do not re-derive it while staging.

The target is what a reviewer wants to read: a handful of commits, each one a complete feature. Ten to fifteen messy commits usually become three to six. Going from 13 to 11 is not compression; it just renames the churn. When in doubt, merge.

Grouping rules, in priority:

1. **Dependencies first.** If commit B uses a symbol, file, option, or schema that commit A introduces, A comes first. Data and config before logic, logic before UI, shared helpers before their first user.
2. **Same feature stays together**, even when it spans many files. Splitting a feature across commits because the files are different is the mistake this skill exists to fix.
3. **One feature per commit.** If the subject needs "and" or "with X and Y" to be honest, it is two features; split it, or admit they are one and name it after the whole. "Parallelize chunk generation" and "retry on content-filter errors" are two commits even when they live in the same function.
4. **Small things are not features.** A change a user would not notice on its own (a lowercased id suffix, a renamed local, a guard moved three lines, a missing label) goes into the feature it belongs to, or into cleanup if it belongs to none. A commit under roughly fifteen lines needs a reason to exist on its own; "it was a separate commit before" is not one.
5. **Fixes to code that already existed at the base** (bugs this stack did not introduce) are cleanup when they are small. They become their own commit only when they are big enough that a reviewer would want to look at them in isolation.
6. **Cleanup last, and only one.** Version bumps, changelog entries, `.gitignore`, formatting-only hunks, typo fixes, lockfile noise, small pre-existing-bug fixes, and leftovers that were already dead at the base go into a single final commit named `cleanup`. Leftovers that *this stack* made dead are deleted inside the feature commit that made them dead, because deleting the now-unused thing is part of that change. If nothing is left for cleanup, there is no cleanup commit; do not create an empty one, and do not use the last slot for an unrelated fix.
7. **Intermediate commits should stand on their own** when it costs nothing: aim for every commit to at least parse and import. When keeping two features apart would break the build in between, keep them apart and say so in the report.

Message style: a single line, imperative, lowercase, a few words saying what changed (`add blacklist option to config flow`). No body, no trailers, no `Co-Authored-By`, no conventional-commit prefixes unless the repo's existing history (`git log --oneline -30 "$BASE"`) uses them consistently.

### 4. Rebuild

Drop the old commits but keep their net result in the working tree:

```bash
git reset --mixed "$BASE"
```

Now the index is empty and the working tree equals the old HEAD. Build each planned commit by staging only what it owns.

**Batch whole-file adds first.** Most files belong entirely to one commit. Stage them all in one call:

```bash
git add -- file1 file2 file3                # whole files, one git-add per commit
```

This covers new files, deleted files, and modified files that are not shared between commits. Do it first; it is fast and handles the majority of files.

**Hunk-stage shared files** with the bundled helper. Use it for any file that has hunks belonging to different commits. Do not hand-roll `git apply`, do not reduce diff context (`-U0`, `-U1`, `--unidiff-zero`); those mis-anchor on repeated lines. The helper uses the default context and handles the plumbing:

```bash
python3 <skill-dir>/scripts/hunks.py list path/to/file        # numbered hunks
python3 <skill-dir>/scripts/hunks.py stage path/to/file 1,4   # stage those hunks
```

After staging some hunks, numbering restarts for what remains. Run `list` again before the next `stage` on the same file.

**Intra-hunk splits** (rare: a single hunk mixes two features): copy the file aside, edit the working copy down to what the earlier commit should contain, `git add` it, then copy the full version back. Never write an intermediate file state from memory; always derive it by editing the final version down.

**Leftovers**: edit out of the working tree while building the commit that made them dead (or cleanup for pre-base leftovers).

Review staged content only for shared-file commits where you used hunk staging: `git diff --cached --stat`. For commits that are all whole-file adds, you already know what is staged; skip the review. Then commit.

Everything that remains after the last feature commit is the cleanup commit: `git add -A`, commit. No final sanity check needed; the verify step catches errors.

### 5. Verify and report

```bash
git status --porcelain                      # must be empty
git diff --stat "$BACKUP" HEAD              # only the leftovers you removed on purpose
```

Any file in the stat that you cannot explain as a deliberate leftover removal means a hunk was dropped. Read the diff for only those files and fix them before reporting. If the stat is empty or everything is explained, move on.

Pop the stash if you made one.

Report, in this order:

1. The new commit list (`git log --oneline "$BASE"..HEAD`).
2. What was removed on purpose relative to the old HEAD, one line each, with the reason.
3. Any commit that may not build on its own and why.
4. The restore command: `git reset --hard <BACKUP>`.

Keep the backup ref; the user deletes it when they are satisfied.

## What not to do

- Do not push, and do not create a branch or worktree. The rewrite happens in place on the current branch.
- Do not keep a hunk only because an old commit had it; the net diff decides.
- Do not refactor, rename, reformat, or fix things that are not leftovers of the churn. A cleaner history is the goal, not cleaner code.
- Do not fold unrelated small changes into a feature commit because they touch the same file. Hunk-level staging exists for exactly this.
- Do not ask for confirmation of the plan; the backup ref is the undo.
