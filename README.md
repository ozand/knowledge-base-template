# knowledge-base-template

A portable, OKF-compatible knowledge base template for AI agents.

Clone this repo to create your own error knowledge base — with automatic
cross-linking, interactive visualization, and git sync.

## Features

- 📝 **OKF format** — Markdown lessons with YAML frontmatter (open, readable, diff-friendly)
- 🔗 **Auto cross-linking** — `kb-enrich` finds related lessons and adds live markdown links
- 📊 **Interactive graph** — `generate-viz.sh` builds a self-contained `viz.html` (Cytoscape.js)
- 🔄 **Git sync** — `kb-sync` pushes/pulls your KB to a private mono-repo
- 🤖 **Pi agent skills** — `kb-lookup`, `kb-capture`, `kb-enrich`, `kb-visualize`, `kb-sync`

## Quick start

```bash
# 1. Clone this template
git clone https://github.com/ozand/knowledge-base-template.git my-kb
cd my-kb

# 2. Create your KB from _template/
./bootstrap.sh --new my-project-kb

# 3. Edit kb.yaml — set local_path, pi_skills_path, and optionally remote

# 4. Install
./bootstrap.sh --kb my-project-kb
```

## Repository structure

```
knowledge-base-template/
├── README.md
├── bootstrap.sh              # install / create KBs
├── scripts/
│   ├── generate-viz.sh       # build viz.html from lessons/*.md
│   └── kb-sync.sh            # sync KB to remote mono-repo
└── _template/                # empty KB skeleton
    ├── kb.yaml               # manifest (name, paths, remote, scripts)
    ├── AGENTS.md             # agent instructions
    ├── PRINCIPLES.md         # KB design principles
    ├── SCHEMA.yaml           # lesson format spec + _template block
    ├── index.yaml            # machine-readable lesson index
    ├── index.md              # human-readable index (auto-generated)
    ├── log.md                # change journal (auto-generated)
    ├── lessons/
    │   └── KB-0000-example.md
    └── skills/
        ├── kb-lookup/SKILL.md
        ├── kb-capture/SKILL.md
        ├── kb-enrich/SKILL.md
        ├── kb-visualize/SKILL.md
        └── kb-sync/SKILL.md
```

## Lesson format

Lessons are `.md` files with YAML frontmatter:

```markdown
---
id: KB-0001
type: Error Lesson
title: "Short description of the error"
category: runtime
tags: [tool, keyword]
severity: high
status: active
created: 2026-06-22
updated: 2026-06-22
error_signatures:
  - "exact error substring"
  - "another pattern"
---

## Symptom
## Root Cause
## Why Not Obvious
## Detection
## Resolution
## Prevention
## Related
## Citations
```

## Requirements

- Bash 4+
- Python 3 + PyYAML (or [uv](https://github.com/astral-sh/uv) — auto-used as fallback)
- [gh CLI](https://cli.github.com/) — for git sync
- [Pi coding agent](https://github.com/earendil-works/pi) — for skills (optional)

## Pi agent integration

The skills in `_template/skills/` are Pi-compatible SKILL.md files.
After bootstrap, they are registered in `~/.pi/agent/settings.json` automatically.

Use in Pi agent:
- `/kb-lookup` — find a lesson for a current error
- `/kb-capture` — record a new lesson
- `/kb-enrich` — enrich cross-links + regenerate index
- `/kb-visualize` — rebuild viz.html
- `/kb-sync` — push/pull with remote repo

## License

MIT
