#!/usr/bin/env python3
"""Stage individual hunks of one file (index vs working tree).

    hunks.py list  <file>          print the unstaged hunks of <file>, numbered from 1
    hunks.py stage <file> 1,3      stage only those hunks (numbers from the latest `list`)

Numbering is over what is still unstaged, so re-run `list` after each `stage`.
New untracked files have no hunks: use `git add`.
"""
import subprocess
import sys


def unstaged_diff(path):
    return subprocess.run(
        ["git", "diff", "--no-color", "-U3", "--", path],
        check=True, capture_output=True, text=True,
    ).stdout


def split(diff):
    header, hunks, current = [], [], None
    for line in diff.splitlines(keepends=True):
        if line.startswith("@@"):
            current = [line]
            hunks.append(current)
        elif current is None:
            header.append(line)
        else:
            current.append(line)
    return "".join(header), ["".join(h) for h in hunks]


def main(argv):
    if len(argv) < 3 or argv[1] not in ("list", "stage"):
        sys.exit(__doc__)
    command, path = argv[1], argv[2]
    diff = unstaged_diff(path)
    if not diff:
        sys.exit(f"{path}: no unstaged changes (untracked file? use git add)")
    header, hunks = split(diff)

    if command == "list":
        for i, hunk in enumerate(hunks, 1):
            print(f"===== hunk {i} =====")
            print(hunk, end="")
        return

    if len(argv) != 4:
        sys.exit("stage needs a comma-separated list of hunk numbers")
    wanted = sorted({int(n) for n in argv[3].split(",")})
    bad = [n for n in wanted if n < 1 or n > len(hunks)]
    if bad:
        sys.exit(f"no such hunk(s) {bad}; {path} has {len(hunks)} unstaged hunk(s)")
    patch = header + "".join(hunks[n - 1] for n in wanted)
    subprocess.run(["git", "apply", "--cached", "-"], input=patch, text=True, check=True)
    print(f"staged hunk(s) {wanted} of {path}; {len(hunks) - len(wanted)} left unstaged")


if __name__ == "__main__":
    main(sys.argv)
