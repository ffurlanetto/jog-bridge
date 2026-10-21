---
name: adr
description: Create a numbered Architecture Decision Record in docs/adr/. Use before implementing any architectural decision — new dependency, data model, integration, or cross-cutting pattern.
argument-hint: [decision to document]
allowed-tools: Read, Glob, Write, Edit
---

Create an Architecture Decision Record for the following decision.

**Steps:**
1. Read `docs/adr/README.md` to determine the next sequential number (four digits)
2. Create `docs/adr/NNNN-short-kebab-case-title.md` from `docs/adr/template.md`
3. Fill every section with the provided context — in English, like the existing ADRs
4. Add the row to the table in `docs/adr/README.md`
5. Confirm the path and number of the created file

An ADR is written **before** implementation and is never rewritten afterwards —
it is superseded by a new ADR instead (status `Superseded by [NNNN](...)`).

Statuses: `Proposed` · `Accepted` · `Superseded by …` · `Abandoned`.

---

Decision to document: $ARGUMENTS
