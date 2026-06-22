# kb-lookup — Pi Knowledge Base lookup skill

Look up a fix in the Pi error knowledge base when a command fails, a provider
errors, or behavior is unexpected.

## When to use

Use whenever an error or failure occurs **before retrying**. Matches the real
error text against `error_signatures` in `~/.pi/kb/index.yaml` and applies the
matched lesson's resolution and prevention.

## Procedure

### Step 1 — Load the index

Read `~/.pi/kb/index.yaml`. Extract the `lessons` list.

### Step 2 — Match error signatures

Take the exact error text. For each lesson in the index, check whether any
string in `error_signatures` appears as a substring in the error text
(case-insensitive). Collect all matching lessons.

### Step 3 — Load matched lessons

For each match, read the lesson file at path `~/.pi/kb/<file>` (file is relative
to KB root). Lessons are Markdown files with YAML frontmatter — read the full
file to get Symptom, Root Cause, Resolution, and Prevention sections.

### Step 4 — Apply resolution

Present the matched lesson(s) to the user:

```
📖 KB-XXXX — <title>
Severity: <severity>  Category: <category>

**Symptom:** ...
**Root Cause:** ...
**Resolution:**
  1. ...
  2. ...
**Prevention:** ...
**Related:** (links to related lessons if any)
```

If multiple lessons match, show all, most severe first.

### Step 5 — No match

If no `error_signatures` match, say:
> No matching KB lesson found. Consider running `/kb-capture` to record this error.

## Notes

- Lesson files are at `~/.pi/kb/lessons/KB-XXXX-<slug>.md`
- Format: Markdown with YAML frontmatter (`---` delimiters)
- `error_signatures` in `index.yaml` are the authoritative match source — do not parse frontmatter for matching, use the index
- After resolving, suggest `/kb-enrich` if the lesson's `## Related` section looks incomplete
