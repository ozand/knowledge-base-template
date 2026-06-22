# kb-capture — Pi Knowledge Base lesson capture skill

Record a new lesson in the Pi error knowledge base after resolving a recurring
or non-obvious error. Creates a `lessons/KB-XXXX-<slug>.md` from the schema
template and registers it in `~/.pi/kb/index.yaml`.

## When to use

Use **after fixing an error** that was not already in the KB and is likely to
recur. Do not capture errors already covered by an existing lesson.

## Procedure

### Step 1 — Determine next id

Read `~/.pi/kb/index.yaml`, get `count`, next id = `KB-` + zero-padded
`count + 1` (e.g. count=2 → `KB-0003`).

### Step 2 — Choose a slug

Create a 3–5 word kebab-case slug from the error topic.
Example: `extension-load-timeout`.

### Step 3 — Write the lesson file

Create `~/.pi/kb/lessons/<id>-<slug>.md` using the template from
`~/.pi/kb/SCHEMA.yaml` (`_template` block). Fill in all fields:

**Frontmatter (required):**
- `id` — the next KB id
- `type` — `Error Lesson` (or appropriate type from SCHEMA.yaml enum)
- `title` — one sentence, max ~100 chars
- `category` — pick from SCHEMA.yaml categories list
- `tags` — relevant tool/concept names
- `severity` — `low` / `medium` / `high` / `critical`
- `status` — `active`
- `created` / `updated` — today's date `YYYY-MM-DD`
- `error_signatures` — 2–6 substrings from the real error text (MANDATORY)

**Body sections (in order):**
`## Symptom` → `## Root Cause` → `## Why Not Obvious` → `## Detection` →
`## Resolution` → `## Prevention` → `## Related` → `## Citations`

Cross-links in `## Related` must use live markdown links:
```markdown
- [KB-0001 — Title](KB-0001-slug.md)
```

### Step 4 — Update index.yaml

Append to `lessons:` list, increment `count`, update `updated` date:
```yaml
  - id: KB-XXXX
    title: "..."
    file: lessons/KB-XXXX-<slug>.md
    category: <category>
    severity: <severity>
    tags: [...]
    error_signatures:
      - "..."
```

### Step 5 — Run kb-enrich

Invoke the `kb-enrich` skill to:
- Add cross-links to `## Related` for lessons with overlapping tags/category
- Add citations from known documentation sources
- Regenerate `~/.pi/kb/index.md`
- Append to `~/.pi/kb/log.md`

### Step 6 — Regenerate visualization

Run the visualization script:
```bash
~/.local/bin/kb-generate-viz ~/.pi/kb
```
This rebuilds `~/.pi/kb/viz.html`. If the script is not installed, skip and
note: "Run `/kb-visualize` or bootstrap to install generate-viz."

### Step 7 — Git commit

```bash
cd ~/.pi/kb
git add -A
git commit -m "kb: add <id> <slug>"
```

### Step 8 — Push (best-effort)

Check for all pending (unpushed) commits:
```bash
git log --oneline @{u}..HEAD 2>/dev/null
```

If there is a remote configured, attempt:
```bash
git pull --rebase && git push
```

On success: report "✓ pushed N commit(s) to remote."
On failure or no remote: report "⚠ N commit(s) pending — run `/kb-sync` to push."
Never fail the capture itself due to push errors — the lesson is always saved
locally first.

## Notes

- Lesson files are Markdown with YAML frontmatter (`---` delimiters)
- `error_signatures` in `index.yaml` must stay in sync with frontmatter values
- Do not edit `index.md`, `viz.html`, or `log.md` manually — they are generated
