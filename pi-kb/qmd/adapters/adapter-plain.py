#!/usr/bin/env python3
# adapter-plain.py — Parse plain text/markdown files into QMD sources.

import os
import sys
import hashlib
from datetime import datetime

KB_NAME = "pi-kb"
SOURCES_BASE = os.path.expanduser(f"~/.cache/{KB_NAME}/qmd-sources/plain")

def chunk_file(filepath):
    if not os.path.exists(filepath):
        return []
    
    filename = os.path.basename(filepath)
    file_id = hashlib.md5(filepath.encode()).hexdigest()[:8]
    ts = datetime.fromtimestamp(os.path.getmtime(filepath)).strftime("%Y-%m-%d %H:%M:%S")

    chunks = []
    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    # Split by double newline (paragraphs) or markdown headers
    raw_chunks = re_split_chunks(content)
    for idx, rc in enumerate(raw_chunks):
        if not rc.strip():
            continue
        chunk_id = f"{file_id}_{idx}"
        chunks.append({
            "id": chunk_id,
            "session_id": file_id,
            "role": "system",
            "timestamp": ts,
            "topic": f"Document: {filename}",
            "content": rc.strip()
        })
    return chunks

def re_split_chunks(text):
    # Splits by major headers or double newlines
    parts = []
    current = []
    for line in text.split("\n"):
        if line.startswith("## ") or line.startswith("# "):
            if current:
                parts.append("\n".join(current))
                current = []
        current.append(line)
    if current:
        parts.append("\n".join(current))
    return parts

def main():
    if len(sys.argv) < 2:
        print("Usage: adapter-plain.py <file-or-dir>")
        sys.exit(1)

    target = sys.argv[1]
    os.makedirs(SOURCES_BASE, exist_ok=True)

    files_to_process = []
    if os.path.isdir(target):
        for root, _, files in os.walk(target):
            for f in files:
                if f.endswith((".txt", ".md", ".log")):
                    files_to_process.append(os.path.join(root, f))
    elif os.path.isfile(target):
        files_to_process.append(target)

    written = 0
    for fpath in files_to_process:
        chunks = chunk_file(fpath)
        for c in chunks:
            out_dir = os.path.join(SOURCES_BASE, c["session_id"])
            os.makedirs(out_dir, exist_ok=True)
            out_path = os.path.join(out_dir, f"{c['id']}.md")
            
            md_content = f"""---
id: {c['id']}
session_id: {c['session_id']}
source: plain
role: {c['role']}
timestamp: "{c['timestamp']}"
topic: "{c['topic']}"
---

{c['content']}
"""
            with open(out_path, "w", encoding="utf-8") as f:
                f.write(md_content)
            written += 1

    print(f"   Processed {len(files_to_process)} plain files, wrote {written} chunks.")

if __name__ == "__main__":
    main()
