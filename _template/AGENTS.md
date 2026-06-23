# AGENTS.md — Pi Error Knowledge Base (KB)

Guidance for the Pi AI agent working with this `kb/` folder.
This AGENTS.md applies whenever the agent operates on files inside `~/.pi/kb/`.
Explicit user instructions in chat take precedence.

## What this folder is

An error-lessons knowledge base for the **Pi coding agent** environment.
Each lesson describes one error: its symptom, root cause, and a proven solution,
plus how to prevent it.

## Goals

1. **Resolve recurring errors fast** — match a real error to a ready lesson and
   apply its solution instead of re-investigating.
2. **Accumulate experience** — capture new lessons so they get reused.
3. **Reduce repeats** — via the `prevention` field of each lesson.

## Folder structure

```
~/.pi/kb/
├── AGENTS.md            # this file — operating rules
├── PRINCIPLES.md        # design principles behind the KB
├── SCHEMA.yaml          # lesson structure contract + template + adding rules
├── index.yaml           # index of all lessons (for fast lookup)
├── lessons/
│   └── KB-XXXX-<slug>.md    # one lesson = one markdown file with frontmatter
└── skills/
    ├── kb-lookup/SKILL.md
    ├── kb-capture/SKILL.md
    ├── kb-enrich/SKILL.md
    ├── kb-visualize/SKILL.md
    └── kb-sync/SKILL.md
└── qmd/                      # Optional: QMD semantic search & mining module
    ├── qmd.yaml              # config for QMD collections
    ├── setup.sh              # setup CLI, collections and model caches
    ├── adapters/             # session parsers (Pi, Claude Code stubs, etc.)
    └── skills/               # optional semantic skills (/kb-search, /kb-mine, /kb-harvest)
```

## How to find a fix for an error (primary workflow)

1. **Exact Match (Default)**: Open `~/.pi/kb/index.yaml` and match the real error text against each entry's `error_signatures` (substring match). Open the matched file and follow the resolution.
2. **Semantic Match (Optional)**: If the exact match fails and QMD is installed, run `/kb-search "<error text>"` to perform a hybrid semantic search across lessons, session logs, and external docs.
3. Apply `prevention` to avoid repeating the error.
4. Confirm success by real artifacts / exit codes.

## How to add a new lesson

1. Copy the `_template` block from `SCHEMA.yaml` into a new file
   `lessons/KB-XXXX-<slug>.md`.
2. Assign the next free `id` (scan `index.yaml` for the highest id).
3. Fill in the fields per `SCHEMA.yaml`. `error_signatures` is **mandatory** —
   it is how the lesson is matched automatically; keep signatures specific.
4. Add an entry to `index.yaml` (`id`, `title`, `file`, `category`, `severity`,
   `tags`, `error_signatures`).
5. Update `count` and `updated` in `index.yaml`.
6. Run `/kb-enrich` to generate backlinks (`## Cited by`), cross-links, and update indices.
7. Run `kb-sync` to sync with remote repo.

## When to update or deprecate

- A better solution is found → extend `resolution`, bump `updated`.
- A lesson becomes obsolete → set `status: deprecated` (keep history).
- A related error is found → add mutual links in `related`.

## Conventions

- **All files and their contents are in English**; encoding is **UTF-8**.
- `id` — `KB-XXXX` (4 zero-padded digits), monotonically increasing.
- `category` — one of: `shell`, `git`, `vcs-hosting`, `environment`, `tooling`,
  `build`, `runtime`, `agent-orchestration`, `pi-provider`, `pi-extension`,
  `pi-skill`, `pi-model`, `pi-session`, `pi-auth`
  (extend as needed and keep `categories` list in `index.yaml` in sync).
- `severity` — `low` | `medium` | `high`.
- `status` — `active` | `deprecated`.

## What not to do

- Do not duplicate full lesson content in `index.yaml` — only search metadata.
- Do not delete lessons without reason — prefer `status: deprecated`.
- Do not leave `error_signatures` empty — the lesson would never be found.
- Do not break `SCHEMA.yaml` compliance: if fields change, update the schema first.

## Related documents

- `PRINCIPLES.md` — why the KB is shaped this way.
- `SCHEMA.yaml` — the exact lesson structure contract.
- `index.yaml` — the entry point for lookup.
