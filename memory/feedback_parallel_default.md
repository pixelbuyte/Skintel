---
name: Parallel Default
description: User wants subagents, web, skills, tools all run in parallel by default
type: feedback
originSessionId: 9ac1e8e3-400f-46ec-97d8-ae0115e52adf
---
Run subagents, web fetches, skills, and tool calls in parallel whenever work is independent. Default behavior every session.

**Why:** User explicitly requested 2026-05-19 — wants max throughput, no sequential when parallel possible.

**How to apply:**
- Batch independent tool calls in single message (multiple tool_use blocks)
- Spawn multiple Agent subagents simultaneously for independent research/tasks
- Parallel WebFetch/WebSearch when multiple sources needed
- Parallel skill invocations when independent
- Only go sequential when later call depends on earlier result
