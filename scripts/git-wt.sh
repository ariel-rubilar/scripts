#!/usr/bin/env bash
set -euo pipefail

SUBCMD="${1:-}"
shift || true

usage() {
  echo "git wt init <repo-url>"
  echo "git wt add <folder> [branch] [base]"
  echo "git wt remove <folder>"
  echo "git wt run <git-command>"
}

git_bare() {
    ROOT="$(pwd)"
    BARE="$ROOT/.bare"
    [ -d "$BARE" ] || { echo "❌ run from repo root"; exit 1; }
    git --git-dir="$BARE" "$@";
}

# ---------- INIT ----------
cmd_init() {
  REPO_URL="${1:-}"
  [ -n "$REPO_URL" ] || { usage; exit 1; }

  REPO_NAME=$(basename "$REPO_URL" .git)

  mkdir -p "$REPO_NAME"
  cd "$REPO_NAME"

  if [ ! -d ".bare" ]; then
    git clone --bare "$REPO_URL" .bare
  fi

  git_bare() { git --git-dir="$PWD/.bare" "$@"; }

  git_bare fetch origin --prune

  [ -d main ] || git_bare worktree add main main

  if git_bare show-ref --verify --quiet refs/remotes/origin/stage; then
    [ -d stage ] || git_bare worktree add stage stage
  else
    echo "⚠ stage branch does not exist"
  fi

  [ -d review ] || git_bare worktree add review --detach

  echo
  echo "Done!"
  echo
  echo "Structure:"
  echo "  $REPO_NAME/"
  echo "    ├── .bare/"
  echo "    ├── main/"
  echo "    └── stage/"
  echo "    └── review/"
  echo
}

# ---------- ADD ----------
cmd_add() {

    git_bare fetch origin --prune

    FOLDER="${1:-}"
    BRANCH="${2:-}"
    BASE="${3:-main}"

    [ -n "$FOLDER" ] || { echo "❌ folder required"; exit 1; }
    [ -d "$FOLDER" ] && { echo "❌ folder already exists"; exit 1; }

    # default branch name = folder name
    [ -n "$BRANCH" ] || BRANCH="$FOLDER"

    # does branch exist (local or remote)?
    if git_bare show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
        echo "▶ Using existing remote branch: origin/$BRANCH"
        git_bare worktree add "$FOLDER" --track "$BRANCH"

    elif git_bare show-ref --verify --quiet "refs/heads/$BRANCH"; then
        echo "▶ Using existing local branch: $BRANCH"
        git_bare worktree add "$FOLDER" "$BRANCH"

    else
        echo "▶ Creating new branch: $BRANCH from $BASE"

        # base must exist
        if ! git_bare show-ref --verify --quiet "refs/heads/$BASE" &&
            ! git_bare show-ref --verify --quiet "refs/remotes/origin/$BASE"; then
        echo "❌ base branch does not exist: $BASE"
        exit 1
        fi

        git_bare worktree add -b "$BRANCH" "$FOLDER" "$BASE"
    fi
}

# ---------- REMOVE ----------
cmd_remove() {

  FOLDER="${1:-}"
  [ -n "$FOLDER" ] || { usage; exit 1; }
  [ -d "$FOLDER" ] || { echo "❌ folder not found"; exit 1; }

  git_bare worktree remove "$FOLDER"
}

# ---------- RUN ----------
cmd_run() {
    [ $# -gt 0 ] || { echo "❌ git command required"; exit 1; }
    git_bare "$@"
}

# ---------- DISPATCH ----------
case "$SUBCMD" in
  init)   cmd_init "$@" ;;
  add)    cmd_add "$@" ;;
  remove) cmd_remove "$@" ;;
  run)    cmd_run "$@" ;;
  *)      usage; exit 1 ;;
esac
