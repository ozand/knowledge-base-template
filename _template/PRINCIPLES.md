# KB Principles

The design principles behind this error knowledge base. They explain *why* the
structure is what it is, so the KB stays useful as it grows.

## 1. Signature-first retrieval

The primary way to find a lesson is to match the **text of a real error**
against `error_signatures` (substrings/regexes). This is robust because errors
are reproduced verbatim by tools. Keep signatures specific enough to avoid false
matches, but stable (avoid volatile parts like timestamps, temp paths, PIDs).

## 2. One lesson, one file

Each lesson is a single YAML file (`lessons/KB-XXXX-<slug>.yaml`). This keeps
diffs small, reviews easy, merges conflict-free, and lets lessons be moved or
referenced individually.

## 3. The index is metadata, not content

`index.yaml` carries only what is needed to *find* a lesson (id, title, file,
category, tags, `error_signatures`). Full detail lives in the lesson file. This
keeps lookup cheap (scan one small file) without duplicating content.

## 4. Cause and prevention, not just a patch

A lesson is not a snippet dump. It states the **root cause**, the **resolution**
steps, and a **prevention** rule. The goal is to stop the error class, not just
the single occurrence.

## 5. Capture honestly, including the meta-lesson

Record *why the cause was not obvious* (`why_not_obvious`). Often the real
lesson is about process — e.g. "don't retry the same failing command", "verify
artifacts, not just output". These meta-lessons prevent whole families of waste.

## 6. Deprecate, don't delete

Outdated lessons get `status: deprecated`, not removal. History is information:
a lesson that no longer applies still documents what was once true and why it
changed.

## 7. Specific over clever

Lessons should be concrete and actionable: real commands, real signatures, real
fixes. Avoid abstract advice. A good lesson lets the reader act without further
research.

## 8. Schema is the contract

`SCHEMA.yaml` defines the fields and is the source of truth for structure. If
you need a new field, update the schema first, then the lessons. Tooling and
agents rely on this contract.

## 9. English and UTF-8

All KB files, field keys, values, titles, and file names are in English with
UTF-8 encoding. This maximizes portability across projects, tools, and teams,
and keeps regex signatures predictable.

## 10. Low friction to add

Adding a lesson must be cheaper than re-debugging. Copy the template, fill a few
fields, register in the index. If capturing is hard, it won't happen — so keep
it a 2-minute task.

## 11. Pi-specific: provider and model errors belong here

Errors from LiteLLM, LM Studio, Anthropic, OpenAI, or any model provider are
first-class lessons. Include API error codes, HTTP status codes, and model-
specific quirks as `error_signatures` so the agent recognizes them immediately.
