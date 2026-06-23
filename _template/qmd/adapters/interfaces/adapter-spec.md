# QMD Source Adapter Specification

This specification defines the standard structure and metadata requirements for converting agent session logs, chats, and console outputs into QMD-compatible markdown chunks.

## Output Target Directory
Each adapter must output `.md` files to the designated ephemeral sources path:
`~/.cache/<kb-name>/qmd-sources/<agent-type>/<session-id>/<message-id>.md`

## Metadata Schema (YAML Frontmatter)
Every materialized markdown file must start with standard frontmatter variables wrapped in triple-hyphens `---`:

```yaml
---
id: <msg-id>
session_id: <session-id>
source: <agent-type> # Enum: pi | claude | open-code | hermes | plain
role: <user | assistant | system>
timestamp: <YYYY-MM-DD HH:MM:SS>
topic: <goal-or-title>
---
```

## Body Format
The body of the file should contain the raw text content of the message or chunk.
- No terminal codes, color escapes, or raw shell output traces unless critical to the message content.
- Code blocks must use standard backtick markers.
- Inline references and JSON payloads must be formatted for readable markdown structure.

## Adapter Execution Protocol
1. **Deduplication**: Adapters must filter or combine repetitive events (like periodic health checks or loop summaries) to avoid bloating the index.
2. **Cleanup**: Stale sessions should be pruned if the source agent deleted them.
3. **Speed**: Processing must finish within seconds; use incremental parsing (comparing timestamps or file hashes) when possible.
