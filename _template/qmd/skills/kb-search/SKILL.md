# kb-search — Hybrid semantic search across Knowledge Base

Search all collections (lessons, session logs, external docs) using QMD's local semantic + BM25 + reranking pipeline.

## When to use
Use when you need to search for error resolutions, conceptual knowledge, design decisions, or historical discussions and exact keywords are not known.

## Procedure

### Step 1 — Load Config & Check Reranker
Read `qmd/qmd.yaml` relative to KB root. Check if `disable_reranker` is set to `true`.
- If disabled, prepare `--no-rerank` query flag.

### Step 2 — Construct Structured Query
Synthesize the query from context. For best results, construct a structured query combining:
- `intent:` target of the search and what to avoid.
- `lex:` exact keywords, aliases, error codes, rare terms.
- `vec:` natural language query.
- `hyde:` a hypothetical paragraph of the answer.

Example formatted command:
```bash
qmd query $'intent: find connection timeouts for postgresql\\nlex: postgresql connection timeout 5701\\nvec: database connection times out under load\\nhyde: Postgresql connection pool was exhausted causing connection timeouts'
```

### Step 3 — Search Across All Collections
Run the query specifying all three collections:
```bash
qmd query --format json \
  -c pi-kb-lessons \
  -c pi-kb-sources \
  -c pi-kb-docs \
  "<structured-query>"
```
Include `--no-rerank` if the reranker was disabled.

### Step 4 — Present Results
Group results by collection:
1. **Lessons** (High confidence curated lessons)
2. **Sources** (Session logs and chat transcripts)
3. **Docs** (External API documentation)

Show relevance scores, titles, and paths. Offer to fetch full documents using `qmd get "#docid"`.
