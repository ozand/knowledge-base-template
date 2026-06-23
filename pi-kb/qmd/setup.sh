#!/usr/bin/env bash
# setup.sh — Setup optional QMD integration module for Knowledge Base.

set -euo pipefail

KB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
QMD_YAML="$KB_DIR/qmd/qmd.yaml"

info() { echo -e "\033[1;32m[INFO]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; exit 1; }

# --- Check requirements ---
command -v node >/dev/null 2>&1 || error "Node.js is required but not found."
node_version=$(node -v | tr -d 'v' | cut -d. -f1)
[[ "$node_version" -lt 22 ]] && error "Node.js v22 or higher is required. Found v$node_version."

# --- Install QMD ---
if ! command -v qmd >/dev/null 2>&1; then
  info "Installing @tobilu/qmd globally via npm..."
  npm install -g @tobilu/qmd
else
  info "QMD CLI already installed: $(qmd --version 2>/dev/null || echo 'unknown version')"
fi

# --- Load configuration ---
_read_yaml() {
  local key="$1"
  python3 -c "
import sys, re
key = sys.argv[2]
with open(sys.argv[1]) as f:
    content = f.read()
# Simple regex to parse key: value or parent: \n  key: value
if '.' in key:
    parent, child = key.split('.')
    pattern = rf'^{parent}:\s*\n(?:\s+.*\n)*?\s+{child}:\s*(.*)$'
else:
    pattern = rf'^{key}:\s*(.*)$'
match = re.search(pattern, content, re.MULTILINE)
if match:
    val = match.group(1).strip().strip('\"').strip(\"'\")
    print(val)
else:
    print('')
" "$QMD_YAML" "$key"
}

# Resolve paths
lessons_dir=$(eval echo "$(_read_yaml "collections.lessons")")
sources_dir=$(eval echo "$(_read_yaml "collections.sources")")
docs_dir=$(eval echo "$(_read_yaml "collections.docs")")
kb_name=$(_read_yaml "kb_name")

mkdir -p "$lessons_dir" "$sources_dir" "$docs_dir"

# --- Add collections to QMD ---
info "Configuring QMD collections..."
qmd collection add "$lessons_dir" --name "${kb_name}-lessons" --mask "**/*.md" || true
qmd collection add "$sources_dir" --name "${kb_name}-sources" --mask "**/*.md" || true
qmd collection add "$docs_dir" --name "${kb_name}-docs" --mask "**/*.md" || true

# --- Run performance probe ---
info "Running QMD performance probe (downloading models if needed, ~2GB)..."
info "This can take a few minutes on first run..."

# Run a test query in hybrid mode and measure time
start_time=$(date +%s)
# Trigger model load and search on local lessons
qmd search "auth" -c "${kb_name}-lessons" >/dev/null 2>&1 || true
end_time=$(date +%s)
elapsed=$((end_time - start_time))

info "Probe complete. Initial warm-up time: ${elapsed} seconds."

# Decide reranker profile
if [[ "$elapsed" -gt 15 ]]; then
  warn "Host performance appears constrained. Recommending CPU-friendly search."
  # Set disable_reranker: true in config
  sed -i 's/disable_reranker: auto/disable_reranker: true/' "$QMD_YAML"
  info "Set performance.disable_reranker to 'true' in qmd/qmd.yaml"
else
  sed -i 's/disable_reranker: auto/disable_reranker: false/' "$QMD_YAML"
  info "Set performance.disable_reranker to 'false' (using hybrid reranker)"
fi

# --- Run initial embedding ---
info "Generating vector embeddings for lessons..."
qmd update -c "${kb_name}-lessons"
qmd embed -c "${kb_name}-lessons"

# --- Register Pi skills ---
# Add qmd/skills/ path to settings.json if Pi is used
SETTINGS_FILE="$HOME/.pi/agent/settings.json"
QMD_SKILLS_PATH="$KB_DIR/qmd/skills"

if [[ -f "$SETTINGS_FILE" ]]; then
  info "Registering QMD skills in Pi settings..."
  python3 -c "
import sys, json, os
path = sys.argv[1]
settings_path = sys.argv[2]
try:
    with open(settings_path, 'r') as f:
        data = json.load(f)
except Exception:
    data = {}
skills = data.setdefault('skills', [])
# Resolve real path
realpath = os.path.realpath(path)
if realpath not in skills:
    skills.append(realpath)
    with open(settings_path, 'w') as f:
        json.dump(data, f, indent=2)
    print(f'   Added {realpath} to skills list.')
else:
    print('   Skills path already registered.')
" "$QMD_SKILLS_PATH" "$SETTINGS_FILE"
fi

info "✓ QMD setup complete."
