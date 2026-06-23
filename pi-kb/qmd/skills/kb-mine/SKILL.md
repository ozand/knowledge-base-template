# kb-mine — Mine agent logs for recurring errors

Analyze active session context, search historic agent session histories, and suggest lesson capture for recurring patterns.

## When to use
Use during debugging or after resolving an issue to check if similar errors occurred in the past, or to extract resolution steps from raw session logs.

## Procedure

### Step 1 — Parse Current Session Context
Identify active errors, commands, or topics in the current discussion. Formulate a semantic search target.

### Step 2 — Refresh Ephemeral Sources
To ensure the index is fresh, run the Pi sessions adapter:
```bash
python3 qmd/adapters/adapter-pi.py
```
And trigger QMD update:
```bash
qmd update -c pi-kb-sources
```

### Step 3 — Query Session Logs
Query the `<kb-name>-sources` collection using the target query. Use structured format (intent, lex, vec, hyde).
```bash
qmd query -c pi-kb-sources "<structured-query>"
```

### Step 4 — Surface Findings
Present the matching chat histories, showing timestamps, roles, and relevance scores.
Retrieve full contexts using `qmd get "#docid"` if needed.

### Step 5 — Suggest Capture
If the mined logs reveal that the same error occurred in 3 or more historic sessions, propose creating a permanent lesson:
> 💡 This error has occurred in 3 past sessions. Consider running `/kb-capture` to record a permanent lesson.
