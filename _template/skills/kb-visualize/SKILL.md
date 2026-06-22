# kb-visualize — Pi Knowledge Base visualization skill

Generate or refresh the interactive graph visualization (`viz.html`) for the KB.

## When to use

- After adding multiple lessons manually (outside of `kb-capture`)
- To refresh `viz.html` after editing existing lessons
- To verify the graph looks correct after format changes

Note: `kb-capture` runs this automatically — you only need this skill for
manual refreshes.

## Procedure

### Step 1 — Run the generator script

```bash
kb-generate-viz ~/.pi/kb
```

If `kb-generate-viz` is not found in PATH:
```bash
~/.pi/kb/scripts/generate-viz.sh ~/.pi/kb
```

### Step 2 — Report results

The script prints:
```
✓ viz.html generated: N nodes, M edges, XKB → /home/.../.pi/kb/viz.html
```

Report those counts to the user.

### Step 3 — Open (optional)

If the user wants to open it:
```bash
xdg-open ~/.pi/kb/viz.html
```

## Notes

- `viz.html` is a self-contained single-file HTML — no server needed, open directly in browser
- Requires Python 3 + PyYAML, or `uv` (auto-used as fallback)
- Nodes are colored by category, sized by lesson body length
- Edges are drawn from cross-links in `## Related` sections
- Search, filter by type/category, and multiple layout options are available in the viewer
