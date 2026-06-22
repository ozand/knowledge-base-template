# kb-sync — Pi Knowledge Base git sync skill

Manually synchronize the local KB with the remote `ozand/knowledge-bases` repo.
Pushes all pending (unpushed) commits and pulls any remote changes.

## When to use

- When `kb-capture` reported "N commits pending — run /kb-sync"
- After working offline and wanting to sync accumulated commits
- Before starting a new KB session on a different machine

## Procedure

### Step 1 — Check git setup

```bash
cd ~/.pi/kb
git remote get-url origin 2>/dev/null || echo "no remote"
```

If no remote is configured: report "No remote configured. Run bootstrap to set
up git sync." and stop.

### Step 2 — Check pending commits

```bash
git log --oneline @{u}..HEAD 2>/dev/null
```

Count the pending commits. Report: "N commits pending push."

### Step 3 — Pull (rebase)

```bash
git pull --rebase
```

On conflict: report the conflict files and stop — do NOT force push.
User must resolve conflicts manually (`git rebase --continue`).

### Step 4 — Push

```bash
git push
```

On success: report "✓ pushed N commit(s) to origin."
On failure: report the git error and count of still-pending commits.

### Step 5 — Report summary

```
✓ kb-sync complete
  Pulled: <N commits from remote / already up-to-date>
  Pushed: <N commits>
  Remote: git@github.com:ozand/knowledge-bases.git (pi-kb/)
```

## Notes

- Never force-push — always rebase
- `~/.pi/kb/` is the working copy; `ozand/knowledge-bases/pi-kb/` is the remote mirror
- If you see unexpected conflicts, check `git status` and `git log --oneline -10`
