---
name: Installed Security Tools
description: CAI and PentestAgent installed and configured for local Ollama use
type: project
---

Two AI-powered security/pentesting tools are installed on this machine:

**CAI (Cybersecurity AI)**
- Installed via: `pip install cai-framework`
- Config: `C:/Users/rrswa/.env` (CAI_MODEL=ollama/llama3.1:8b)
- Run with: `cai` or `C:/Users/rrswa/AppData/Local/Python/pythoncore-3.14-64/Scripts/cai.exe`

**PentestAgent**
- Installed at: `C:/Users/rrswa/pentestagent`
- Venv at: `C:/Users/rrswa/pentestagent/venv`
- Config: `C:/Users/rrswa/pentestagent/.env` (PENTESTAGENT_MODEL=ollama/llama3.1:8b)
- Run with: `cd pentestagent && venv/Scripts/python -m pentestagent`

**Why:** Both use local Ollama (llama3.1:8b) — no API key needed. qwen2.5-coder:7b is available as backup for technical tasks.
