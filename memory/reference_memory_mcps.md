---
name: Memory MCP Stack
description: memory-kg + mem0 MCP servers wired for persistent semantic memory across sessions
type: reference
originSessionId: 9ac1e8e3-400f-46ec-97d8-ae0115e52adf
---
**Servers (in C:/Users/rrswa/.claude.json under project C:/Users/rrswa/skintel):**
- `memory-kg` — `cmd /c npx -y @modelcontextprotocol/server-memory` — knowledge graph (entities, relations, observations)
- `mem0` — `cmd /c npx -y mem0-mcp` — sqlite + Ollama embeddings, semantic search

**Activate:** restart Claude Code. Tools become available as `mcp__memory-kg__*` and `mcp__mem0__*`.

**Usage:**
- Long-term semantic recall → mem0 `search_memory("query")` + `add_memory(text)`
- Entity/relation graph → memory-kg `create_entities`, `read_graph`, `search_nodes`
- Short structured facts → existing file-based auto-memory (this directory)

**Layer for ultimate memory:** auto-memory (durable rules) + memory-kg (entities) + mem0 (semantic transcripts).

**Note on Windows MCP registration:** `claude mcp add` mangles `cmd /c` into `cmd C:/`. Patch `.claude.json` args directly to `["/c", "npx", "-y", "<pkg>"]`.
