---
name: Skills Mass Install May 2026
description: 945 Claude skills installed from 5 GitHub repos via npx skills add --yes
type: project
originSessionId: 1984bc57-1dbb-4831-99cd-ad917099e6a3
---
Cloned 5 skill repos and batch-installed all 945 skills to `~/.agents/skills/` (symlinked to `~/.claude/skills/`).

**Why:** User wanted all available skills active in Claude Code CLI and Desktop app.

**Repos cloned to `C:\Users\rrswa\.claude\skills\`:**
- `anthropics-skills/` — github.com/anthropics/skills (16 skills: claude-api, mcp-builder, skill-creator, pptx, xlsx, pdf, etc.)
- `awesome-claude-skills/` — github.com/ComposioHQ/awesome-claude-skills (150+ automation skills)
- `superpowers/` — github.com/obra/superpowers (12 skills: systematic-debugging, TDD, parallel agents, etc.)
- `superpowers-lab/` — github.com/obra/superpowers-lab (experimental: mcp-cli, windows-vm, video, slack-messaging)
- `marketingskills/` — github.com/coreyhaines31/marketingskills (37 skills: SEO, CRO, copywriting, paid ads)

**Install method:** `npx skills add "<path>" --yes` run in parallel via xargs -P 10

**Install locations:**
- Primary: `C:\Users\rrswa\.agents\skills\` (867 dirs)
- Symlinked: `C:\Users\rrswa\.claude\skills\` (Claude Code reads here)
- Flat copies for Desktop upload: `C:\Users\rrswa\.claude\skills\_upload_ready\` (248 .md files)

**Total:** 943 individual skills (awesome-claude-skills ~780, marketingskills 37, anthropics-skills 16, superpowers 12, superpowers-lab ~10)

**Claude Desktop setup:** Each repo has root SKILL.md (all skills concatenated). Connect 5 folders in Desktop → New Project → Connect Folder for each repo path.

**How to apply:** When user wants more skills, clone to `~/.claude/skills/` and run `npx skills add "<path>" --yes`. Desktop: connect folder with root SKILL.md, not individual file upload.
