#!/usr/bin/env bash
set -euo pipefail

SUBCMD="${1:-}"
shift || true

usage() {
  echo "git wt init <repo-url>"
  echo "git wt add <folder> [branch] [base]"
  echo "git wt remove <folder>"
  echo "git wt run <git-args...>"
}

# Name of the bare directory (kept as .bare here).
BARE_NAME="${GIT_WT_BARE_DIR:-.bare}"

# ---------- INIT ----------
cmd_init() {
  REPO_URL="${1:-}"
  [ -n "$REPO_URL" ] || { usage; exit 1; }

  REPO_NAME=$(basename "$REPO_URL" .git)

  mkdir -p "$REPO_NAME"
  cd "$REPO_NAME"

  # clone into the configured bare dir name if it doesn't exist
  if [ ! -d "$BARE_NAME" ]; then
    git clone --bare "$REPO_URL" "$BARE_NAME"
  fi

  # create a .git file that points to the bare repo (so standard `git` in
  # this working tree talks to the bare repo)
  echo "gitdir: ./$BARE_NAME" > .git

  # now run git commands from repo root (they will follow the .git pointer)
  git fetch origin --prune

  [ -d main ] || git worktree add main main

  if git show-ref --verify --quiet refs/remotes/origin/stage; then
    [ -d stage ] || git worktree add stage stage
  else
    echo "⚠ stage branch does not exist"
  fi

  [ -d review ] || git worktree add review --detach

  echo
  echo "Done!"
  echo
  echo "Structure:"
  echo "  $REPO_NAME/"
  echo "    ├── $BARE_NAME/"
  echo "    ├── main/"
  echo "    └── stage/"
  echo "    └── review/"
  echo
}

# ---------- ADD ----------
cmd_add() {
    git fetch origin --prune

    BRANCH="${1:-}"
    FOLDER="${2:-}"
    BASE="${3:-main}"

    [ -n "$BRANCH" ] || { echo "❌ branch required"; exit 1; }
    [ -d "$BRANCH" ] && { echo "❌ folder already exists"; exit 1; }

    # default folder name = branch name
    [ -n "$FOLDER" ] || FOLDER="$BRANCH"

    # does branch exist (local or remote)?
    if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
        echo "▶ Using existing remote branch: origin/$BRANCH"
        git worktree add "$FOLDER" --track "origin/$BRANCH"

    elif git show-ref --verify --quiet "refs/heads/$BRANCH"; then
        echo "▶ Using existing local branch: $BRANCH"
        git worktree add "$FOLDER" "$BRANCH"

    else
        echo "▶ Creating new branch: $BRANCH from $BASE"

        # base must exist (local or remote)
        if ! git show-ref --verify --quiet "refs/heads/$BASE" &&
            ! git show-ref --verify --quiet "refs/remotes/origin/$BASE"; then
          echo "❌ base branch does not exist: $BASE"
          exit 1
        fi

        git worktree add -b "$BRANCH" "$FOLDER" "$BASE"
    fi
}

# ---------- REMOVE ----------
cmd_remove() {
  FOLDER="${1:-}"
  [ -n "$FOLDER" ] || { usage; exit 1; }
  [ -d "$FOLDER" ] || { echo "❌ folder not found"; exit 1; }

  git worktree remove "$FOLDER"
}

# ---------- RUN ----------
cmd_run() {
    [ $# -gt 0 ] || { echo "❌ git command required"; exit 1; }
    git "$@"
}

# ---------- DISPATCH ----------
case "$SUBCMD" in
  init)   cmd_init "$@" ;;
  add)    cmd_add "$@" ;;
  remove) cmd_remove "$@" ;;
  run)    cmd_run "$@" ;;
  *)      usage; exit 1 ;;
esac
