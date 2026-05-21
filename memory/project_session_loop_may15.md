---
name: Session Loop May 15 2026
description: User set up recurring 10-min session-save loop via /loop skill
type: project
originSessionId: 501fca4f-9066-4abc-86f8-2987451fc5c7
---
Set up recurring cron job (ID: 5cc2703f) to save session every 10 minutes.

**Why:** User wants session context preserved periodically throughout conversations.

**How to apply:** When "save session" fires, snapshot notable work, decisions, and file changes from current conversation into memory files. If session is idle/minimal, skip writing to avoid noise.
