---
name: Shopify Bug Bounty
description: Active Shopify HackerOne bug bounty testing on personal dev stores; 5 scenarios planned
type: project
originSessionId: a3293c30-462f-43c1-8ff1-b8f8ad161e3c
---
User is actively doing **ethical bug bounty on Shopify's HackerOne program** using their own dev stores only.

**Stack:** Claude Code (orchestrator) + CAI bug_bounter_agent (WSL) + Ollama llama3.1:8b + Kali tools.

**Focus areas:** Broken Access Control, IDOR, tenant isolation, permission bypasses, business logic flaws.

**5 planned test scenarios (in priority order):**
1. Staff account permission bypass — restricted staff hitting API endpoints beyond their perms
2. Multi-store tenant isolation — Store A session accessing Store B data
3. GraphQL introspection + unauthorized field access — customer PII via other customer IDs
4. Checkout business logic — price manipulation, discount stacking, negative quantities
5. App proxy auth bypass — hitting app proxies without valid HMAC signature

**Start with:** Scenario 1 (staff permissions) — lowest risk, high bounty potential.

**Scope rules:**
- Only `*.myshopify.com` stores user created
- No automated scanning of Shopify infrastructure
- No DoS, brute force, social engineering
- No storing PII found accidentally

**Current status:** Actively working Scenario 1. User needs to:
1. Get store URL (their actual myshopify.com subdomain)
2. Login as staff-limited in Firefox → DevTools → copy Cookie header value
3. Paste both here → Claude builds ready-to-run curl commands

**Exact curls planned:**
- `GET /admin/api/2025-04/customers.json` — cookie only, no token header
- `GET /admin/api/2025-04/orders.json?status=any`
- `POST /api/2025-04/graphql.json` with customers query

**Next step:** User pastes store URL + cookie → Claude gives exact commands → user runs → brings back HTTP status codes + response bodies for analysis + H1 report drafting.

**CAI Ollama fix needed:** Ollama binds to 127.0.0.1 — WSL can't reach it. Fix: `$env:OLLAMA_HOST="0.0.0.0:11434"; ollama serve` in PowerShell before launching CAI.

**How to apply:** When user shares bug findings, act as AppSec mentor — rate CVSS, draft HackerOne report, suggest impact escalation.
