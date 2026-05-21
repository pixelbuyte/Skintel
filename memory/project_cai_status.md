---
name: CAI Tool Status
description: CAI fully working in WSL Ubuntu-24.04; confirmed launched and reached CAI> prompt
type: project
originSessionId: a3293c30-462f-43c1-8ff1-b8f8ad161e3c
---
CAI (Cybersecurity AI framework) is **confirmed working** in WSL Ubuntu-24.04.

**Installation:** `~/cai-env/` (Python venv inside WSL).

**Correct launch command (from WSL terminal):**
```bash
CAI_MODEL=ollama/llama3.1:8b OPENAI_API_KEY=dummy OLLAMA_HOST=http://$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):11434 ~/cai-env/bin/cai
```

**IMPORTANT:** `OPENAI_API_KEY=dummy` required even with Ollama — CAI agents hardcode `AsyncOpenAI()` and crash without it. Value doesn't matter, just must be set.

**Note:** `cai-wsl.bat` does NOT work from inside WSL — only from Windows terminal. User is usually already in WSL so use direct command above.

**Ollama:** Must run `ollama serve` in Windows terminal first. Binds to `127.0.0.1:11434` — WSL reaches it via resolv.conf nameserver IP.

**Key agents inside CAI:**
- `/agent` command doesn't work — use `/agents` or check `/help` for correct syntax
- Agent selection commands unconfirmed — always run `/help` first to get exact command list
- `$ <cmd>` — direct shell passthrough confirmed syntax

**Claude vs CAI:** Claude = controlled, visible, user approves each step. CAI = autonomous, chains tools itself without supervision. User can use either or both.

**How to apply:** If user asks to run CAI, give them the full bash command above. Remind them Ollama must be serving first.
