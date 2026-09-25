# Storyblok agent plugin

Distribution repo. The root **is** the plugin: `skills/` plus one manifest per
client (Claude Code, Codex, Cursor, Kiro, Antigravity).

- **IMPORTANT:** Every file here except `LICENSE`, `AGENTS.md`, `CLAUDE.md` and
  `.github/` is generated and overwritten on release. Edits to them are lost.
- Skills are authored upstream, not here. A fix to a `SKILL.md` belongs in the
  source repo.
- `version` is set upstream and must change for clients to notice a release.

## Layout

- `plugin.json`, `mcp.json` — Agent Plugins v1 (Codex, Cursor, Kiro). Its
  `keywords` decide when Kiro activates the power, and
  `extensions.com.openai` holds the OpenAI Plugins Directory listing.
- `.claude-plugin/`, `.mcp.json` — Claude Code.
- `.agents/plugins/marketplace.json` — Codex marketplace entry.
- `mcp_config.json` — Antigravity.
- `assets/` — listing images referenced from `plugin.json`.
- `README.md` — install instructions per client, plus the support and privacy
  links Kiro requires.
- `skills/<name>/SKILL.md` — the payload, shared by every format.
