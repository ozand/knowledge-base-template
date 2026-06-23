#!/usr/bin/env python3
# adapter-pi.py — Parse Pi sessions into QMD sources collection.
#
# Processes JSONL session logs:
#   - Extracts user/assistant messages (excludes raw tool outputs).
#   - Uses compaction summaries to resolve topics.
#   - Deduplicates sessions by Goal/Topic to avoid indexing duplicates.
#   - Outputs standard markdown files with frontmatter to ephemeral path.

import os
import sys
import json
import glob
import re
import hashlib
from datetime import datetime

KB_NAME = "pi-kb"
SOURCES_BASE = os.path.expanduser(f"~/.cache/{KB_NAME}/qmd-sources/pi")
PI_SESSIONS = os.path.expanduser("~/.pi/agent/sessions")

def get_text_content(content):
    if isinstance(content, str):
        return content
    elif isinstance(content, list):
        parts = []
        for block in content:
            if not isinstance(block, dict):
                continue
            btype = block.get("type")
            if btype == "text":
                parts.append(block.get("text", ""))
            elif btype == "thinking":
                parts.append(f"\n[Thinking]: {block.get('thinking', '')}\n")
        return "\n".join(parts)
    return ""

def clean_goal_title(summary):
    # Extracts the Goal from compaction summary
    m = re.search(r'## Goal\n(.+?)(?:\n##|\Z)', summary, re.DOTALL)
    if m:
        goal = m.group(1).strip().split('\n')[0]
        return goal[:100]
    return "Untitled Session"

def process_session(session_path):
    if not os.path.exists(session_path):
        return []

    session_id = os.path.basename(session_path).replace(".jsonl", "")
    messages = []
    current_topic = "General Conversation"
    goals_seen = set()

    with open(session_path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
                etype = event.get("type")
                
                # Extract topic from compaction summary
                if etype == "compaction":
                    summary = event.get("summary", "")
                    goal = clean_goal_title(summary)
                    current_topic = goal
                    # Deduplication track
                    goals_seen.add(goal)
                
                elif etype == "message":
                    msg = event.get("message", {})
                    role = msg.get("role")
                    if role not in ("user", "assistant"):
                        continue
                    
                    msg_id = event.get("id")
                    if not msg_id:
                        # Fallback id if missing
                        msg_id = hashlib.md5(f"{role}_{msg.get('timestamp')}".encode()).hexdigest()[:8]
                    
                    raw_ts = msg.get("timestamp", 0) / 1000.0
                    try:
                        ts_str = datetime.fromtimestamp(raw_ts).strftime("%Y-%m-%d %H:%M:%S")
                    except:
                        ts_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    
                    content_str = get_text_content(msg.get("content", ""))
                    if not content_str.strip():
                        continue

                    messages.append({
                        "id": msg_id,
                        "session_id": session_id,
                        "source": "pi",
                        "role": role,
                        "timestamp": ts_str,
                        "topic": current_topic,
                        "content": content_str
                    })
            except Exception as e:
                pass
                
    return messages, list(goals_seen)

def main():
    print("🔄 Parsing Pi sessions...")
    os.makedirs(SOURCES_BASE, exist_ok=True)
    
    session_files = glob.glob(os.path.join(PI_SESSIONS, "**/*.jsonl"), recursive=True)
    print(f"   Found {len(session_files)} session file(s).")

    processed_goals = {}
    all_extracted_messages = []

    # First pass: read all sessions, sort by date to process newest first (for goal deduplication)
    session_files.sort(key=os.path.getmtime, reverse=True)

    for sf in session_files:
        msgs, goals = process_session(sf)
        if not msgs:
            continue
        
        # Deduplication check: if the main goal was already processed in a newer session,
        # skip this historic session to avoid noise.
        skip_session = False
        for g in goals:
            if g in processed_goals:
                skip_session = True
                break
        
        if skip_session:
            continue
            
        for g in goals:
            processed_goals[g] = sf
            
        all_extracted_messages.extend(msgs)

    # Write output markdown files
    written_count = 0
    for m in all_extracted_messages:
        session_dir = os.path.join(SOURCES_BASE, m["session_id"])
        os.makedirs(session_dir, exist_ok=True)
        
        file_path = os.path.join(session_dir, f"{m['id']}.md")
        
        md_content = f"""---
id: {m['id']}
session_id: {m['session_id']}
source: pi
role: {m['role']}
timestamp: "{m['timestamp']}"
topic: "{m['topic'].replace('"', '\\"')}"
---

{m['content']}
"""
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(md_content)
        written_count += 1

    print(f"   Successfully wrote {written_count} session chunks to {SOURCES_BASE}")
    print(f"   Deduplicated: keeping {len(processed_goals)} unique session topics.")

if __name__ == "__main__":
    main()
