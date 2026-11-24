---
name: pr-triage
description: Triage the review comments on a pull request - start a background watcher when a PR is opened or marked ready, and when the review lands, check every comment against the code with an agent and post a sorted list (worth doing / your call / skip). Use after opening or readying a PR, when the user says a PR is ready or asks what the reviewers said, or when the session-start status line reports a new review.
---

# PR review triage

Tool: `pr-review-digest` (on PATH; source `~/dotfiles/bin/pr-review-digest`). It is read-only against
GitHub and keeps local state in `~/.local/state/pr-review-digest/`. Never comment, reply, resolve
threads, approve, push or re-run a review bot yourself; print those commands for the user.

## 1. Start the watcher

- Right after you push and open a PR at the user's request (draft or ready), or when the user says they
  marked one ready or re-ran the review bot.
- Run `pr-review-digest <PR> --repo <owner/name> --wait` with `run_in_background: true`. It waits for the
  PR to be ready (up to 8 h), then for the review: a configured bot (20 min limit) or, in repos without
  one, any review by someone else (8 h). It costs no tokens while waiting, and dies with the session; the
  session-start status line covers that.
- How a repo's bot behaves (how to re-run it, how long it takes, whether it reviews again after a push)
  is in CLAUDE.md when the user has described it.
- Exit codes: 0 digest printed; 3 timed out (say whether it was still a draft or the review never
  finished); 5 the PR was closed or merged.

## 2. When it finishes (exit 0), without waiting to be asked

1. `pr-review-digest <PR> --repo <owner/name> --format json`. Work on the items with `"open": true`;
   resolved threads and items in the decision record were handled before.
2. Launch one agent to check every open item against the code, read-only. Give it the repo path, the PR
   head and base, the items (`key`, `id`, `source`, `severity`, `path`, `line`, `outdated`, `fix_in`,
   `body`, `url`) and where prior decisions live (the project hub, if any). Ask for one verdict per item:
   `worth doing`, `your call` (with a recommendation) or `skip` (wrong, already decided, out of scope, no
   longer applies), plus effort S/M/L, the evidence (`file:line`, doc) and the commit to fix it in.
   Check against the working tree, not the reviewed sha.
3. Post the triage, outcome first, in three groups: WORTH DOING, YOUR CALL, SKIP. Inside each: humans
   first, then severity, then effort (small first), then commit order. Each item: key, tag, `file:line`,
   fix-in commit, one sentence, the verdict with its evidence, the bare URL. End with
   `Pick: e.g. "b2 b3"`.
4. `pr-review-digest <PR> --repo <owner/name> --mark-seen`, so the run is not reported again.

## 3. After the user picks

- Fix only the picked items. Fold each fix into its commit: `git commit --fixup=<sha>` (reword with
  `git commit --allow-empty -m "amend! <old subject>" -m "<new message>"`), then
  `git update-ref refs/pr-triage/before HEAD` and
  `GIT_SEQUENCE_EDITOR=: git rebase -i --autosquash $(git merge-base origin/<base> HEAD)`. No `fixup!` or
  `amend!` subject may remain. Run the specs, lint and typecheck of the touched workspaces.
- Picking items is the go-ahead for these local commits only. Force-push only when the user says so;
  otherwise print `git push --force-with-lease`.
- Record every decided item, picked or not:
  `pr-review-digest <PR> --repo <owner/name> --record <id> done|skipped|deferred "<reason>"` (the item's
  `id` from the JSON). Recorded items stop showing as open, so a declined note is not proposed again.
- Tell the user which threads they can resolve on GitHub (done and skipped ones).
- Log the round in the active project hub's session log, if there is one.

## Session start

A SessionStart hook runs `pr-review-digest --status` for the current branch's PR and adds one line to
the context. "new review": run step 2. "draft" or "bot reviewing": offer to start the watcher.
