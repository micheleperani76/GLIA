# GLIA — `-p` Project Mode v2 — Design Draft

Version: 0.1 (draft)
Status: PLANNING — not implemented yet
Scope: rework of the `-p` project-coding mode. Bash only. Fully in-house.

---

## 1. Goal

Turn `-p` from a weak one-shot suggestion into a real, safe local editing
mode: the AI proposes a change, GLIA shows the exact command, the user
confirms, GLIA applies it and keeps a local safety net to undo.

No external coding tool is used. We reimplement the useful patterns in bash.

## 2. Principles (GLIA pillars, non-negotiable)

- Show the command: always print the real diff AND the real `git` command
  before doing anything ("You can do this yourself with:").
- Teach, do not hide: the user must be able to reproduce every step by hand.
- Dry-run + log for anything that touches files.
- Config (paths, model names) at the top of the file.
- Bash only, modular; split into files if it grows.
- Menu / exit option always available.

## 3. Core flow (git-native)

1. Context: user passes one or more files to work on; GLIA loads them,
   truncated to fit the model context window (num_ctx).
2. Ask: user describes the change.
3. Model returns a standard *unified diff* (the format `git diff` produces).
4. GLIA shows the diff (colored) and the exact command it would run.
5. User confirms (dry-run by default; apply only on explicit yes).
6. GLIA applies with `git apply`, then offers an optional local commit
   with an auto-generated message.
7. Undo: since every applied change is a commit, undo = `git revert`/`reset`.
   All local. Nothing is pushed to GitHub unless the user runs `git push`.

## 4. Components to build (bash functions)

- pmode_collect_context()   : gather target files, enforce num_ctx budget.
- pmode_build_prompt()      : system prompt forcing unified-diff output only.
- pmode_get_diff()          : call the local model, capture the diff.
- pmode_show_diff()         : pretty-print diff + the `git apply` command.
- pmode_apply()             : dry-run check (`git apply --check`) then apply.
- pmode_commit()            : optional local commit, auto message.
- pmode_undo()              : revert last AI commit.
- pmode_log()               : append what happened to a log file.

## 5. Config block (to place at top of file)

- PMODE_MODEL        : local model used for -p (project code_model).
- PMODE_NUM_CTX      : context window budget.
- PMODE_LOG          : path of the operations log.
- PMODE_DRYRUN       : default true.

## 6. Phased roadmap

- Phase 1 (MVP): single file, get unified diff, show + `git apply --check`,
  apply on confirm, log. No commit yet.
- Phase 2: optional local auto-commit + undo.
- Phase 3: multiple files in one change.
- Phase 4: lite repo-map (tree + grep of function names/headers) so the
  model knows the project without loading everything.

## 7. Open questions

- Best system prompt to force clean unified diffs from a 7B local model.
- Fallback when `git apply` fails (fuzzy patch? ask model to regenerate?).
- How much of the file to send vs. just relevant hunks, given num_ctx.
