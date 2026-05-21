---
name: Parallel Work Preference
description: User prefers parallel agent/tool execution when work is independent
type: feedback
originSessionId: fb993435-e40b-49fd-ba96-8a1738e2f22c
---
When tasks are independent, run them in parallel — multiple agents, parallel tool calls in single message, background tasks. User explicitly asks "work in parallel" / "in parrell".

**Why:** Faster completion, user values throughput over sequential clarity.

**How to apply:** Default to parallel Agent spawns and batched tool calls for independent work. Only go sequential when outputs feed each other.
