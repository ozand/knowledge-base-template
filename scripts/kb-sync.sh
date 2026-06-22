#!/usr/bin/env bash
# kb-sync.sh — sync ~/.pi/kb to ozand/knowledge-bases mono-repo (pi-kb/ subdirectory)
#
# Usage:
#   kb-sync [--pull-only] [--push-only] [--dry-run]
#
# What it does:
#   1. Clones ozand/knowledge-bases to a temp dir
#   2. Rsyncs ~/.pi/kb/* → temp/pi-kb/
#   3. Commits any changes with a sync message
#   4. Pushes to origin/main
#
# The local ~/.pi/kb git repo is used for local commit history only.
# The mono-repo is the shared remote source of truth.

set -euo pipefail

KB_LOCAL="${KB_LOCAL:-$HOME/.pi/kb}"
MONO_REPO="https://github.com/ozand/knowledge-bases.git"
KB_SUBDIR="pi-kb"
PULL_ONLY=false
PUSH_ONLY=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pull-only) PULL_ONLY=true;  shift ;;
    --push-only) PUSH_ONLY=true;  shift ;;
    --dry-run)   DRY_RUN=true;    shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# --- Check local pending commits ---
LOCAL_PENDING=0
if git -C "$KB_LOCAL" rev-parse --git-dir &>/dev/null; then
  LOCAL_PENDING=$(git -C "$KB_LOCAL" log --oneline 2>/dev/null | wc -l || echo 0)
fi

echo "🔄 kb-sync starting..."
echo "   Local KB:  $KB_LOCAL ($LOCAL_PENDING local commits)"
echo "   Mono-repo: $MONO_REPO"

# --- Clone mono-repo to temp dir ---
SYNC_TMP=$(mktemp -d)
trap 'rm -rf "$SYNC_TMP"' EXIT

echo "📥 Cloning mono-repo..."
gh repo clone ozand/knowledge-bases "$SYNC_TMP" -- --quiet 2>&1

# --- Pull: copy mono-repo pi-kb/ → local KB ---
if [[ "$PUSH_ONLY" == "false" ]]; then
  echo "📥 Pulling remote changes → local..."
  if [[ "$DRY_RUN" == "false" ]]; then
    rsync -a --delete \
      --exclude='.git' \
      --exclude='*.pyc' \
      "$SYNC_TMP/$KB_SUBDIR/" "$KB_LOCAL/"
    echo "   ✓ Local KB updated from remote"
  else
    rsync -a --delete --dry-run \
      --exclude='.git' \
      "$SYNC_TMP/$KB_SUBDIR/" "$KB_LOCAL/"
  fi
fi

# --- Push: copy local KB → mono-repo pi-kb/ ---
if [[ "$PULL_ONLY" == "false" ]]; then
  echo "📤 Pushing local changes → remote..."
  rsync -a --delete \
    --exclude='.git' \
    --exclude='*.pyc' \
    "$KB_LOCAL/" "$SYNC_TMP/$KB_SUBDIR/"

  cd "$SYNC_TMP"
  CHANGED=$(git status --short | wc -l)

  if [[ "$CHANGED" -eq 0 ]]; then
    echo "   ✓ Remote already up-to-date (no changes)"
  elif [[ "$DRY_RUN" == "true" ]]; then
    echo "   (dry-run) Would commit $CHANGED changed file(s)"
    git status --short
  else
    SYNC_DATE=$(date -u +"%Y-%m-%d %H:%M UTC")
    git add -A
    git commit -m "kb: sync pi-kb — $SYNC_DATE"
    git push origin main
    echo "   ✓ Pushed $CHANGED changed file(s) to remote"
  fi
fi

echo ""
echo "✓ kb-sync complete"
