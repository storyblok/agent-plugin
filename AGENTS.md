# Storyblok agent plugin

Distribution repo. The root **is** the plugin: `skills/` plus one manifest per
client (Claude Code, Agent Plugins v1, Gemini CLI).

- **IMPORTANT:** Every file here except `LICENSE`, `AGENTS.md` and `.github/`
  is generated and overwritten on release. Edits to them are lost.
- Skills are authored upstream, not here. A fix to a `SKILL.md` belongs in the
  source repo.
- `version` is set upstream and must change for clients to notice a release.

## Layout

- `plugin.json`, `mcp.json` — Agent Plugins v1 (Codex, Cursor).
- `.claude-plugin/`, `.mcp.json` — Claude Code.
- `.agents/plugins/marketplace.json` — Codex marketplace entry.
- `gemini-extension.json` — Gemini CLI.
- `skills/<name>/SKILL.md` — the payload, shared by all three formats.
