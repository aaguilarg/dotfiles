---
name: pre-review
description: Address the user's local pre-review notes (.git/pre-review.jsonl, written with :PreReview in Neovim) on the current branch - verify each note, fix it, fold each fix into the commit it belongs to, report per note. Use when the user says "address my notes", "pre-review", or runs /pre-review [base].
argument-hint: "[base-branch]"
---

# Pre-review notes

The user reviewed the branch commit by commit in Neovim (`:PreReview [base]`, module
`~/dotfiles/nvim/lua/custom/pre_review.lua`) and left notes. Asking for this skill is the user's
go-ahead for **local** fixup commits and an autosquash rebase on the current branch. It is never a
go-ahead to push, force-push or write to GitHub; print those commands for the user instead.

## Input

Base branch: the argument if given, else `master` (a stacked branch passes its parent). Run:

- `git rev-parse --git-path pre-review.jsonl` (the notes file; one per worktree)
- `git status --short`
- `git log --reverse --format='%h %s' $(git merge-base <base> HEAD)..HEAD`

One JSON object per line in the notes file:

| Field | Meaning |
|-------|---------|
| `id` | `n1`, `n2`, ... use it in the report |
| `commit`, `subject` | commit the note was written on (full sha + title at that time) |
| `path` | file; absent = the note is about the commit itself (title, order, split, squash) |
| `side`, `line`, `end_line` | `new` = line number in the file at `commit`; `old` = in `commit^`; no `line` = whole file |
| `code` | the diff line(s) under the cursor, with their `+`/`-`/space prefix |
| `note` | the user's words |

## Steps

1. Stop if the tree is dirty or the notes file is missing or empty.
2. Resolve each note's commit. If `commit` is not an ancestor of HEAD (the branch was rewritten),
   find it by `subject`; if that is not unique, ask.
3. Check every note against the code before changing anything: `git show <commit>:<path>` at
   `line`, compare with `code`, then read the same code at HEAD (a later commit may have changed or
   removed it). One verdict per note:
   - `fix`: the note is right, or is a direct instruction.
   - `reword`: the note is about the commit title or message.
   - `answer`: the note is a question and the code is right as it is. Change nothing; explain why.
   - `ask`: ambiguous, or the fix changes behavior or scope beyond the note.
4. If any note is `ask`, ask all of them in one message and wait.
5. `git update-ref refs/pre-review/before HEAD` (the re-review compares against it; no backup branch).
6. Work commit by commit, oldest first. Make the edits, then `git commit --fixup=<sha>`. A fix also
   needed in later commits (a rename, a moved line) gets one fixup per commit it touches. Reword with
   `git commit --allow-empty -m "amend! <old subject>" -m "<new full message>"`
   (`--fixup=reword:` cannot take `-m`).
7. `GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash $(git merge-base <base> HEAD)`. On a conflict,
   resolve it only when the resolution is mechanical; otherwise `git rebase --abort` and report.
   Afterwards no `fixup!`/`amend!` subject may remain.
8. Run the specs, lint and typecheck of the workspaces the fixes touched.
9. Report one row per note: id, verdict, what changed, new short sha. Then give the user:
   - re-review: `:PreReview <base>` again, or `git range-diff <base> refs/pre-review/before HEAD`
     (unchanged commits show `=`, changed ones `!` with only the delta);
   - if the branch is already pushed: `git push --force-with-lease`, for them to run.
10. Move the notes file to `<git-dir>/pre-review-archive/<UTC timestamp>.jsonl`.
11. If a note states a reusable rule (for example "use a heredoc for long messages", "class << self
    over private_class_method"), say so and propose where it belongs (a project skill or CLAUDE.md).
    Do not edit those files without the user's OK.
