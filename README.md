# Pi Agent — Error Knowledge Base (KB)

A file-based knowledge base of **error lessons** for the Pi coding agent
environment. When something fails, look up a matching lesson and apply its fix;
new recurring errors are captured back as lessons so they are never solved twice.

## Why it exists

- Stop re-debugging the same Pi/LLM/provider/extension errors.
- Turn one-off fixes into reusable, searchable knowledge.
- Give the Pi agent a predictable place to look before retrying blindly.

## Structure

```
~/.pi/kb/
├── README.md        # this file
├── AGENTS.md        # rules for the Pi agent (read this if you are an agent)
├── PRINCIPLES.md    # design principles behind the KB
├── SCHEMA.yaml      # what a lesson looks like + a copy-paste template
├── index.yaml       # searchable index of all lessons
├── lessons/         # one markdown file per lesson (KB-XXXX-<slug>.md)
└── skills/
    ├── kb-lookup/SKILL.md   # Pi skill: find and apply a lesson on error
    ├── kb-capture/SKILL.md  # Pi skill: record a new lesson
    ├── kb-enrich/SKILL.md   # Pi skill: build cross-links, backlinks, regenerate indexes
    ├── kb-visualize/SKILL.md # Pi skill: rebuild interactive viz.html graph
    └── kb-sync/SKILL.md     # Pi skill: sync KB with remote mono-repo
└── qmd/                 # Optional: QMD semantic search & session mining module
    ├── qmd.yaml         # config for QMD collections and performance
    ├── setup.sh         # setup script (detects CPU speed, global QMD installation)
    ├── adapters/        # parsers for agent session formats (Pi JSONL, plain text)
    └── skills/          # semantic search (/kb-search), mining (/kb-mine), harvest (/kb-harvest)
```

## Quickstart: look up a fix

1. **Exact match**: Open `index.yaml`. Find the entry whose `error_signatures` match your real error text. Open the file from its `file:` field.
2. **Semantic match**: If exact search misses, run `/kb-search "<error>"` (requires optional QMD module) to query lessons, chats, and docs.
3. Apply the steps in `resolution`, then the `prevention` advice.

## Quickstart: add a lesson

1. Copy the `_template` block from `SCHEMA.yaml` into
   `lessons/KB-XXXX-<slug>.md` (use the next free id).
2. Fill in the fields. **`error_signatures` is required** — these are the
   strings future lookups will match against, so make them specific.
3. Add a matching entry to `index.yaml`, then bump `count` and `updated`.
4. Run `/kb-enrich` to generate backlinks (`## Cited by`) and rebuild `index.md`/`log.md`.

## Use with the Pi agent

The skills are installed in `~/.pi/kb/skills/` (and `qmd/skills/` if installed) and discovered automatically by Pi. The agent will:
- consult this KB on errors before retrying, and
- offer to capture a new lesson when it resolves a new recurring error.

You can also drive it explicitly:

> `/kb-lookup` — find a fix for the current error
> `/kb-capture` — record a new lesson after resolving an error
> `/kb-search` — semantic search across all collections (curated, sessions, docs)
> `/kb-mine` — scan agent logs for recurring errors and suggest capture
> `/kb-harvest` — ingest external reference documentation
> `/kb-sync` — manual git sync with the remote repository


## Pi-specific categories

In addition to general categories, this KB covers:
- `pi-provider` — LiteLLM, LM Studio, model API errors
- `pi-extension` — Pi extension loading/runtime errors
- `pi-skill` — skill discovery, loading, execution errors
- `pi-model` — model selection, context, token limit errors
- `pi-session` — session management, compaction, fork errors
- `pi-auth` — API keys, auth.json, token errors

## Conventions

- All files and their names are in **English**; encoding is **UTF-8**.
- Lesson ids: `KB-XXXX` (zero-padded), one lesson per file.
- Prefer `status: deprecated` over deleting outdated lessons.

See `PRINCIPLES.md` for the reasoning and `AGENTS.md` for the full agent rules.
