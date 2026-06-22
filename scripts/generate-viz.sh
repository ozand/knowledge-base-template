#!/usr/bin/env bash
# generate-viz.sh — generate a self-contained viz.html from a KB directory
#
# Usage:
#   generate-viz.sh <kb-root> [--out <path>] [--name <bundle-name>]
#
# Requirements:
#   - Python 3 with PyYAML  (or uv available for auto-install)
#   - lessons/*.md in OKF frontmatter format
#
# Output:
#   <kb-root>/viz.html  (or path specified with --out)

set -euo pipefail

KB_ROOT="${1:-}"
OUT_PATH=""
BUNDLE_NAME=""

if [[ -z "$KB_ROOT" ]]; then
  echo "Usage: generate-viz.sh <kb-root> [--out <path>] [--name <bundle-name>]" >&2
  exit 1
fi

shift
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)   OUT_PATH="$2";    shift 2 ;;
    --name)  BUNDLE_NAME="$2"; shift 2 ;;
    *)       echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

KB_ROOT="$(realpath "$KB_ROOT")"
OUT_PATH="${OUT_PATH:-$KB_ROOT/viz.html}"
BUNDLE_NAME="${BUNDLE_NAME:-$(basename "$KB_ROOT")}"

# --- Inline Python generator ---
PYTHON_SCRIPT='
import sys, json, re, pathlib
import yaml  # requires pyyaml

KB_ROOT   = pathlib.Path(sys.argv[1])
OUT_PATH  = pathlib.Path(sys.argv[2])
BUNDLE_NAME = sys.argv[3]

FRONTMATTER_RE = re.compile(r"^---\n(.*?)\n---\n?(.*)", re.DOTALL)
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)]+\.md)(?:#[^)]*)?\)")

PALETTE = {
    "pi-auth":             "#ef4444",
    "pi-model":            "#3b82f6",
    "pi-provider":         "#8b5cf6",
    "pi-extension":        "#f97316",
    "pi-skill":            "#eab308",
    "pi-session":          "#06b6d4",
    "runtime":             "#10b981",
    "agent-orchestration": "#64748b",
    "git":                 "#f59e0b",
    "shell":               "#84cc16",
    "environment":         "#0ea5e9",
    "tooling":             "#a855f7",
    "build":               "#ec4899",
    "vcs-hosting":         "#14b8a6",
}
DEFAULT_COLOR = "#94a3b8"

def parse_md(path):
    text = path.read_text(encoding="utf-8")
    m = FRONTMATTER_RE.match(text)
    if not m:
        return None, text
    try:
        fm = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError:
        return None, text
    return fm, m.group(2)

def extract_links(body, doc_dir, kb_root):
    out, seen = [], set()
    for m in LINK_RE.finditer(body):
        target = m.group(2)
        if "://" in target or target.startswith("/"):
            continue
        resolved = (doc_dir / target).resolve()
        try:
            rel = resolved.relative_to(kb_root).with_suffix("").as_posix()
        except ValueError:
            continue
        if rel and rel not in seen:
            seen.add(rel)
            out.append(rel)
    return out

lessons_dir = KB_ROOT / "lessons"
nodes, edges, bodies, seen_edges = [], [], {}, set()
concepts = {}

for md_path in sorted(lessons_dir.glob("*.md")):
    fm, body = parse_md(md_path)
    if not fm or not fm.get("id"):
        continue
    cid = md_path.stem
    concepts[cid] = {
        "id": cid,
        "kb_id": fm.get("id", cid),
        "type": fm.get("type", "Error Lesson"),
        "title": fm.get("title", cid),
        "category": fm.get("category", "runtime"),
        "tags": fm.get("tags", []),
        "severity": fm.get("severity", "medium"),
        "description": fm.get("title", ""),
        "body": body,
        "links_to": extract_links(body, md_path.parent, KB_ROOT),
    }

for cid, c in concepts.items():
    color = PALETTE.get(c["category"], DEFAULT_COLOR)
    size = 30 + min(60, len(c["body"]) // 100)
    nodes.append({"data": {
        "id": cid,
        "kb_id": c["kb_id"],
        "label": c["title"],
        "type": c["type"],
        "category": c["category"],
        "tags": c["tags"],
        "severity": c["severity"],
        "description": c["description"],
        "color": color,
        "size": size,
    }})
    bodies[cid] = c["body"]

for cid, c in concepts.items():
    for target in c["links_to"]:
        if target == cid or target not in concepts:
            continue
        key = (cid, target)
        if key in seen_edges:
            continue
        seen_edges.add(key)
        edges.append({"data": {"id": f"{cid}__{target}", "source": cid, "target": target}})

types = sorted({c["type"] for c in concepts.values()})
graph = {"nodes": nodes, "edges": edges, "bodies": bodies, "types": types, "palette": PALETTE}

HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{bundle_name} — KB Viewer</title>
<script src="https://cdn.jsdelivr.net/npm/cytoscape@3.28.1/dist/cytoscape.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/marked@12.0.0/marked.min.js"></script>
<style>
*{{box-sizing:border-box;margin:0;padding:0}}
body{{font-family:system-ui,sans-serif;background:#0f172a;color:#e2e8f0;display:flex;flex-direction:column;height:100vh;overflow:hidden}}
header{{display:flex;align-items:center;gap:12px;padding:10px 16px;background:#1e293b;border-bottom:1px solid #334155;flex-shrink:0}}
.title strong{{font-size:15px;color:#f1f5f9}}
.title .muted{{font-size:12px;color:#64748b;margin-left:6px}}
.controls{{display:flex;gap:8px;margin-left:auto;align-items:center}}
input,select,button{{background:#0f172a;border:1px solid #334155;color:#e2e8f0;border-radius:6px;padding:5px 10px;font-size:13px}}
button{{cursor:pointer}}
button:hover{{background:#1e293b}}
main{{display:flex;flex:1;overflow:hidden}}
#graph{{flex:1;position:relative}}
#detail{{width:380px;border-left:1px solid #334155;overflow-y:auto;padding:16px;background:#1e293b;flex-shrink:0}}
.muted{{color:#64748b;font-size:13px}}
.type-chip{{display:inline-block;padding:2px 8px;border-radius:999px;font-size:11px;font-weight:600;background:#334155;color:#94a3b8;margin-bottom:6px}}
h1{{font-size:16px;color:#f1f5f9;margin-bottom:4px}}
#detail-id{{font-size:11px;color:#64748b;margin-bottom:12px}}
dl.frontmatter{{display:grid;grid-template-columns:max-content 1fr;gap:4px 12px;font-size:12px;margin-bottom:12px}}
dt{{color:#64748b;font-weight:600}}
dd{{color:#cbd5e1}}
hr{{border:none;border-top:1px solid #334155;margin:12px 0}}
#detail-body{{font-size:13px;line-height:1.6;color:#cbd5e1}}
#detail-body h2{{font-size:13px;font-weight:700;color:#94a3b8;margin:12px 0 4px;text-transform:uppercase;letter-spacing:.05em}}
#detail-body code{{background:#0f172a;padding:1px 4px;border-radius:3px;font-size:12px}}
#detail-body pre{{background:#0f172a;padding:10px;border-radius:6px;overflow-x:auto;margin:6px 0}}
#detail-body a{{color:#60a5fa}}
#detail-body ul,#detail-body ol{{padding-left:18px;margin:4px 0}}
.severity-high{{color:#ef4444}}
.severity-critical{{color:#dc2626;font-weight:700}}
.severity-medium{{color:#f59e0b}}
.severity-low{{color:#10b981}}
#detail-backlinks{{margin-top:12px}}
#detail-backlinks h2{{font-size:12px;color:#64748b;font-weight:600;text-transform:uppercase;margin-bottom:6px}}
#backlinks-list li{{font-size:12px;color:#60a5fa;cursor:pointer;list-style:none;padding:2px 0}}
#backlinks-list li:hover{{text-decoration:underline}}
</style>
</head>
<body>
<header>
  <div class="title">
    <strong id="bundle-name"></strong>
    <span class="muted">KB Viewer</span>
  </div>
  <div class="controls">
    <input id="search" type="search" placeholder="Search title / id / tag" style="width:200px">
    <select id="filter-type"><option value="">All types</option></select>
    <select id="filter-cat"><option value="">All categories</option></select>
    <select id="layout">
      <option value="cose">force</option>
      <option value="concentric">concentric</option>
      <option value="breadthfirst">breadth-first</option>
      <option value="circle">circle</option>
      <option value="grid">grid</option>
    </select>
    <button id="reset">Reset view</button>
  </div>
</header>
<main>
  <section id="graph"></section>
  <section id="detail">
    <div id="detail-empty" class="muted">Click a node to see its details.</div>
    <article id="detail-content" hidden>
      <span class="type-chip" id="detail-type"></span>
      <h1 id="detail-title"></h1>
      <div class="muted" id="detail-id"></div>
      <dl class="frontmatter">
        <dt>Category</dt><dd id="detail-category"></dd>
        <dt>Severity</dt><dd id="detail-severity"></dd>
        <dt>Tags</dt><dd id="detail-tags"></dd>
      </dl>
      <hr>
      <div id="detail-body"></div>
      <section id="detail-backlinks" hidden>
        <h2>Cited by</h2>
        <ul id="backlinks-list"></ul>
      </section>
    </article>
  </section>
</main>
<script>
const BUNDLE_NAME = {bundle_name_json};
const BUNDLE_DATA = {bundle_data_json};

document.getElementById("bundle-name").textContent = BUNDLE_NAME;

// Populate filter dropdowns
const typeSelect = document.getElementById("filter-type");
BUNDLE_DATA.types.forEach(t => {
  const o = document.createElement("option"); o.value = t; o.textContent = t;
  typeSelect.appendChild(o);
});
const cats = [...new Set(BUNDLE_DATA.nodes.map(n => n.data.category))].sort();
const catSelect = document.getElementById("filter-cat");
cats.forEach(c => {
  const o = document.createElement("option"); o.value = c; o.textContent = c;
  catSelect.appendChild(o);
});

// Build backlink map
const backlinks = {};
BUNDLE_DATA.edges.forEach(e => {
  const t = e.data.target;
  if (!backlinks[t]) backlinks[t] = [];
  backlinks[t].push(e.data.source);
});

// Init Cytoscape
const cy = cytoscape({
  container: document.getElementById("graph"),
  elements: [...BUNDLE_DATA.nodes, ...BUNDLE_DATA.edges],
  style: [
    { selector: "node", style: {
      "background-color": "data(color)",
      "label": "data(label)",
      "color": "#f1f5f9",
      "font-size": "11px",
      "text-wrap": "wrap",
      "text-max-width": "120px",
      "width": "data(size)",
      "height": "data(size)",
      "text-valign": "bottom",
      "text-margin-y": "4px",
      "text-outline-color": "#0f172a",
      "text-outline-width": "2px",
    }},
    { selector: "node:selected", style: { "border-width": 3, "border-color": "#f8fafc" }},
    { selector: "node.faded", style: { opacity: 0.25 }},
    { selector: "edge", style: {
      "width": 2,
      "line-color": "#334155",
      "target-arrow-color": "#475569",
      "target-arrow-shape": "triangle",
      "curve-style": "bezier",
    }},
    { selector: "edge.highlighted", style: { "line-color": "#60a5fa", "target-arrow-color": "#60a5fa", "width": 3 }},
  ],
  layout: { name: "cose", animate: false, nodeRepulsion: 8000, idealEdgeLength: 120 },
});

function runLayout(name) {
  cy.layout({ name, animate: true, animationDuration: 400,
    ...(name === "cose" ? { nodeRepulsion: 8000, idealEdgeLength: 120 } : {})
  }).run();
}

// Detail panel
let selectedId = null;
function showDetail(nodeId) {
  selectedId = nodeId;
  const d = BUNDLE_DATA.nodes.find(n => n.data.id === nodeId)?.data;
  if (!d) return;
  document.getElementById("detail-empty").hidden = true;
  document.getElementById("detail-content").hidden = false;
  document.getElementById("detail-type").textContent = d.type;
  document.getElementById("detail-title").textContent = d.label;
  document.getElementById("detail-id").textContent = d.kb_id + " · " + d.id;
  document.getElementById("detail-category").textContent = d.category;
  const sevEl = document.getElementById("detail-severity");
  sevEl.textContent = d.severity;
  sevEl.className = "severity-" + d.severity;
  document.getElementById("detail-tags").textContent = (d.tags || []).join(", ") || "—";
  document.getElementById("detail-body").innerHTML = marked.parse(BUNDLE_DATA.bodies[nodeId] || "");

  const bl = backlinks[nodeId] || [];
  const blSection = document.getElementById("detail-backlinks");
  const blList = document.getElementById("backlinks-list");
  blList.innerHTML = "";
  if (bl.length) {
    blSection.hidden = false;
    bl.forEach(src => {
      const srcData = BUNDLE_DATA.nodes.find(n => n.data.id === src)?.data;
      const li = document.createElement("li");
      li.textContent = srcData ? srcData.label : src;
      li.onclick = () => { cy.getElementById(src).select(); showDetail(src); };
      blList.appendChild(li);
    });
  } else {
    blSection.hidden = true;
  }

  // Highlight connected edges
  cy.elements().removeClass("highlighted faded");
  const node = cy.getElementById(nodeId);
  const connected = node.connectedEdges();
  connected.addClass("highlighted");
  cy.elements().not(node).not(connected).not(connected.connectedNodes()).addClass("faded");
  node.removeClass("faded");
}

cy.on("tap", "node", e => showDetail(e.target.id()));
cy.on("tap", e => {
  if (e.target === cy) {
    cy.elements().removeClass("highlighted faded");
    document.getElementById("detail-empty").hidden = false;
    document.getElementById("detail-content").hidden = true;
    selectedId = null;
  }
});

// Search + filter
function applyFilters() {
  const q = document.getElementById("search").value.toLowerCase();
  const ft = typeSelect.value;
  const fc = catSelect.value;
  cy.nodes().forEach(n => {
    const d = n.data();
    const match =
      (!q || d.label.toLowerCase().includes(q) || d.kb_id.toLowerCase().includes(q) || (d.tags||[]).some(t => t.toLowerCase().includes(q))) &&
      (!ft || d.type === ft) &&
      (!fc || d.category === fc);
    n.style("opacity", match ? 1 : 0.15);
  });
}
document.getElementById("search").addEventListener("input", applyFilters);
typeSelect.addEventListener("change", applyFilters);
catSelect.addEventListener("change", applyFilters);
document.getElementById("layout").addEventListener("change", e => runLayout(e.target.value));
document.getElementById("reset").addEventListener("click", () => {
  cy.fit(undefined, 40);
  cy.elements().removeClass("highlighted faded").style("opacity", 1);
  document.getElementById("search").value = "";
  typeSelect.value = "";
  catSelect.value = "";
});
</script>
</body>
</html>
"""

html = (HTML
    .replace("{bundle_name}", BUNDLE_NAME)
    .replace("{bundle_name_json}", json.dumps(BUNDLE_NAME))
    .replace("{bundle_data_json}", json.dumps(graph))
)
OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
OUT_PATH.write_text(html, encoding="utf-8")

concept_count = len(concepts)
edge_count = len(edges)
byte_count = len(html.encode("utf-8"))
print(f"✓ viz.html generated: {concept_count} nodes, {edge_count} edges, {byte_count//1024}KB → {OUT_PATH}")
'

# --- Runner: prefer system python3+yaml, fallback to uv ---
if python3 -c "import yaml" 2>/dev/null; then
  python3 - "$KB_ROOT" "$OUT_PATH" "$BUNDLE_NAME" <<< "$PYTHON_SCRIPT"
elif command -v uv &>/dev/null; then
  uv run --quiet --with pyyaml python3 - "$KB_ROOT" "$OUT_PATH" "$BUNDLE_NAME" <<< "$PYTHON_SCRIPT"
else
  echo "ERROR: PyYAML not found and uv not available." >&2
  echo "Install with: sudo pacman -S python-yaml  OR  pip install pyyaml  OR  install uv" >&2
  exit 1
fi
