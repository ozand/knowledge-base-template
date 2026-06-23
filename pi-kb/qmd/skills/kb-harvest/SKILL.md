# kb-harvest — Ingest external documentation

Convert and load external files (HTML, PDF, JSON, TXT) into the KB semantic docs index.

## When to use
Use when you need to load official documentation, reference manuals, or articles into the KB so that they are searchable via `/kb-search`.

## Procedure

### Step 1 — Locate Files
Find the target documentation files or directories.
If the source contains non-markdown files (like HTML or PDF), utilize local conversion tools:
- For HTML: `pandoc -f html -t markdown input.html -o output.md`
- For PDF: `pdftotext input.pdf output.txt` (then parse with adapter-plain)

### Step 2 — Materialize to Docs Cache
Copy the processed `.md` or `.txt` files to the docs cache:
`~/.cache/pi-kb/qmd-docs/`

### Step 3 — Register & Embed in QMD
Run QMD commands to index and generate vector embeddings:
```bash
qmd update -c pi-kb-docs
qmd embed -c pi-kb-docs
```

Verify that the files appear in the database by listing collection contents:
```bash
qmd ls pi-kb-docs
```
