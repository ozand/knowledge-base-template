#!/usr/bin/env bash
# bootstrap.sh — Knowledge Base bootstrap script
#
# Usage:
#   ./bootstrap.sh --kb <kb-dir>        Install an existing KB from this repo
#   ./bootstrap.sh --new <name>         Create a new KB from _template/
#   ./bootstrap.sh --help
#
# What it does:
#   1. Reads <kb-dir>/kb.yaml for configuration
#   2. Copies shared scripts to ~/.local/bin/
#   3. Registers KB skills in Pi agent settings (if Pi is installed)
#   4. Configures git remote (if remote is set in kb.yaml)
#   5. Runs post_install hooks from kb.yaml
#
# Requirements:
#   - bash 4+
#   - Python 3 + PyYAML  (or uv for auto-install)
#   - gh CLI (for git sync features)
#   - Pi coding agent (optional — for skill registration)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*" >&2; }

usage() {
  echo "Usage:"
  echo "  $0 --kb <kb-dir>     Install KB from this repo directory"
  echo "  $0 --new <name>      Create a new KB from _template/"
  echo "  $0 --help"
  exit 0
}

# --- Parse args ---
MODE=""
KB_ARG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --kb)   MODE="install"; KB_ARG="$2"; shift 2 ;;
    --new)  MODE="new";     KB_ARG="$2"; shift 2 ;;
    --help|-h) usage ;;
    *) error "Unknown option: $1"; usage ;;
  esac
done

[[ -z "$MODE" ]] && usage

# --- Helper: read value from kb.yaml without pyyaml ---
# Uses basic grep/sed for simple key: value lines
read_yaml_key() {
  local file="$1" key="$2"
  grep -E "^${key}:" "$file" | head -1 | sed "s/^${key}:[[:space:]]*//" | tr -d '"'"'" | xargs
}

# --- Helper: install scripts (symlink strategy, hash-aware) ---
# Creates symlinks from ~/.local/bin/ → repo scripts/ so updates to the
# repo automatically propagate without re-running bootstrap.
# Falls back to copy if the symlink target would cross filesystem boundaries.
install_scripts() {
  local kb_dir="$1"
  local kb_yaml="$kb_dir/kb.yaml"

  mkdir -p "$HOME/.local/bin"

  _install_one_script() {
    local src="$1" dst_name="$2"
    local dst="$HOME/.local/bin/$dst_name"

    # If dst is already a symlink pointing to the right source — skip
    if [[ -L "$dst" ]] && [[ "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
      info "Script up-to-date (symlink): ~/.local/bin/$dst_name"
      return
    fi

    # If dst exists as a regular file, compare hashes to detect drift
    if [[ -f "$dst" ]] && [[ ! -L "$dst" ]]; then
      local src_hash dst_hash
      src_hash=$(sha256sum "$src" | cut -d' ' -f1)
      dst_hash=$(sha256sum "$dst" | cut -d' ' -f1)
      if [[ "$src_hash" != "$dst_hash" ]]; then
        warn "Script drift detected: ~/.local/bin/$dst_name differs from repo — updating"
      else
        info "Script up-to-date (copy): ~/.local/bin/$dst_name"
        return
      fi
    fi

    # Create symlink (preferred) — if it fails (cross-fs), fall back to copy
    rm -f "$dst"
    if ln -s "$(realpath "$src")" "$dst" 2>/dev/null; then
      chmod +x "$src"
      info "Installed script (symlink): ~/.local/bin/$dst_name → $src"
    else
      cp "$src" "$dst"
      chmod +x "$dst"
      info "Installed script (copy): ~/.local/bin/$dst_name"
    fi
  }

  # Install shared scripts from repo root scripts/
  for script in "$REPO_ROOT/scripts/"*.sh; do
    [[ -f "$script" ]] || continue
    _install_one_script "$script" "$(basename "$script" .sh)"
  done

  # Install KB-specific scripts (from scripts: block in kb.yaml)
  if [[ -f "$kb_yaml" ]]; then
    local src dst
    while IFS= read -r line; do
      if [[ "$line" =~ src:[[:space:]]*(.+) ]]; then
        src="${BASH_REMATCH[1]// /}"
      elif [[ "$line" =~ dst:[[:space:]]*(.+) ]]; then
        dst="${BASH_REMATCH[1]// /}"
        local src_path="$kb_dir/$src"
        [[ -f "$src_path" ]] && _install_one_script "$src_path" "$dst"
      fi
    done < <(grep -A1 "src:" "$kb_yaml" 2>/dev/null || true)
  fi
}

# --- Helper: register Pi skills ---
register_pi_skills() {
  local skills_path="$1"
  local pi_settings="$HOME/.pi/agent/settings.json"

  if [[ ! -f "$pi_settings" ]]; then
    warn "Pi agent not found at $pi_settings — skipping skill registration"
    return
  fi

  # Check if already registered (idempotent)
  if grep -q "\"$skills_path\"" "$pi_settings" 2>/dev/null; then
    info "Pi skills already registered: $skills_path"
    return
  fi

  # Add to skills array using Python (most reliable JSON editing)
  python3 - "$pi_settings" "$skills_path" << 'PYEOF'
import json, sys
settings_path, skills_path = sys.argv[1], sys.argv[2]
with open(settings_path) as f:
    s = json.load(f)
skills = s.setdefault("skills", [])
if skills_path not in skills:
    skills.append(skills_path)
    with open(settings_path, "w") as f:
        json.dump(s, f, indent=2)
    print(f"✓ Registered in Pi settings: {skills_path}")
else:
    print(f"✓ Already registered: {skills_path}")
PYEOF
}

# --- Helper: check dependencies ---
check_deps() {
  local ok=true

  if python3 -c "import yaml" 2>/dev/null; then
    info "Python3 + PyYAML: ok"
  elif command -v uv &>/dev/null; then
    info "Python3 + uv (PyYAML auto-loaded): ok"
  else
    warn "PyYAML not found. Install: sudo pacman -S python-yaml  OR  pip install pyyaml  OR  install uv"
    ok=false
  fi

  if command -v gh &>/dev/null; then
    info "gh CLI: ok"
  else
    warn "gh CLI not found — git sync features (kb-sync) will not work"
  fi

  $ok
}

# ============================================================
# MODE: install — bootstrap an existing KB
# ============================================================
install_kb() {
  local kb_dir="$REPO_ROOT/$KB_ARG"

  if [[ ! -d "$kb_dir" ]]; then
    error "KB directory not found: $kb_dir"
    exit 1
  fi

  local kb_yaml="$kb_dir/kb.yaml"
  if [[ ! -f "$kb_yaml" ]]; then
    error "kb.yaml not found in $kb_dir"
    exit 1
  fi

  local kb_name local_path pi_skills_path remote
  kb_name=$(read_yaml_key "$kb_yaml" "name")
  local_path=$(read_yaml_key "$kb_yaml" "local_path" | sed "s|~|$HOME|g")
  pi_skills_path=$(read_yaml_key "$kb_yaml" "pi_skills_path" | sed "s|~|$HOME|g")
  remote=$(read_yaml_key "$kb_yaml" "remote" || true)

  echo "🚀 Installing KB: $kb_name"
  echo "   Source:    $kb_dir"
  echo "   Dest:      $local_path"
  echo ""

  check_deps || true

  # Copy KB files to local_path
  mkdir -p "$local_path"
  rsync -a --exclude='.git' "$kb_dir/" "$local_path/"
  info "Copied KB files → $local_path"

  # Install scripts
  install_scripts "$kb_dir"

  # Register Pi skills
  if [[ -n "$pi_skills_path" ]]; then
    register_pi_skills "$pi_skills_path"
  fi

  # Configure git remote
  if [[ -n "$remote" ]]; then
    if git -C "$local_path" rev-parse --git-dir &>/dev/null; then
      if git -C "$local_path" remote get-url origin &>/dev/null; then
        info "Git remote already configured"
      else
        git -C "$local_path" remote add origin "$remote"
        info "Git remote added: $remote"
      fi
    else
      git -C "$local_path" init
      git -C "$local_path" remote add origin "$remote"
      info "Git repo initialized with remote: $remote"
    fi
  fi

  # Run post_install hooks
  echo ""
  echo "📋 Running post-install hooks..."
  while IFS= read -r hook; do
    hook=$(echo "$hook" | sed 's/^[[:space:]]*-[[:space:]]*//' | tr -d '"')
    [[ -z "$hook" ]] && continue
    eval "$hook"
  done < <(awk '/^hooks:/,/^[^ ]/' "$kb_yaml" | grep -E "^\s+-\s+" || true)

  echo ""
  info "Bootstrap complete!"
  echo "   Open viz.html: xdg-open $local_path/viz.html"
  echo "   Add a lesson:  /kb-capture  (in Pi agent)"
  echo "   Sync:          kb-sync"
}

# ============================================================
# MODE: new — create KB from _template/
# ============================================================
new_kb() {
  local template_dir="$REPO_ROOT/_template"
  local new_dir="$REPO_ROOT/$KB_ARG"

  if [[ ! -d "$template_dir" ]]; then
    error "_template/ not found in $REPO_ROOT"
    exit 1
  fi

  if [[ -d "$new_dir" ]]; then
    error "Directory already exists: $new_dir"
    exit 1
  fi

  echo "🆕 Creating new KB: $KB_ARG"
  echo "   From template: $template_dir"
  echo "   Destination:   $new_dir"
  echo ""

  cp -r "$template_dir" "$new_dir"

  # Update kb.yaml with new name
  local kb_yaml="$new_dir/kb.yaml"
  sed -i "s/^name:.*/name: $KB_ARG/" "$kb_yaml"
  sed -i "s|~/.kb/my-kb|~/.kb/$KB_ARG|g" "$kb_yaml"

  # Update index.yaml date
  local today
  today=$(date +%Y-%m-%d)
  sed -i "s/YYYY-MM-DD/$today/g" "$new_dir/index.yaml"
  sed -i "s/YYYY-MM-DD/$today/g" "$new_dir/_template/lessons/KB-0000-example.md" 2>/dev/null || true

  info "Created KB: $new_dir"
  echo ""
  echo "Next steps:"
  echo "  1. Edit $kb_yaml — set local_path, pi_skills_path, remote"
  echo "  2. Run: $0 --kb $KB_ARG"
  echo "  3. Start adding lessons with /kb-capture in Pi agent"
}

# ============================================================
# Run
# ============================================================
case "$MODE" in
  install) install_kb ;;
  new)     new_kb ;;
  *)       usage ;;
esac
