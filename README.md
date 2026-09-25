# Storyblok Agent Skills

Agent skills for working with Storyblok via the Storyblok MCP server and CLI.

Generated distribution repo: its root is the plugin. Do not open pull requests
against the generated files — see AGENTS.md.

## Install

**Claude Code**

```
/plugin marketplace add storyblok/agent-plugin
/plugin install storyblok@storyblok
```

**Codex / Cursor**

```sh
codex plugin marketplace add storyblok/agent-plugin
```

**Kiro**

Powers panel → **Add Custom Power** → **Import power from GitHub**, then enter
`https://github.com/storyblok/agent-plugin`.

**Antigravity**

```sh
git clone https://github.com/storyblok/agent-plugin
agy plugin install ./agent-plugin
```

All of them register the [Storyblok MCP server](https://www.storyblok.com/docs/libraries/mcp-server)
over OAuth. No token is stored in this repo.

## Skills

| Skill | When it activates |
| --- | --- |
| `storyblok-build-frontend` | Use when generating frontend components for Storyblok blocks — writing, registering and validating the framework code that renders a space's content. E.g. "generate components for my blocks", "build an Astro + Storyblok landing page". |
| `storyblok-implement-figma` | Use when turning a Figma design into frontend components backed by Storyblok blocks. E.g. "figma to storyblok", "build this Figma design". |
| `storyblok-model-content` | Use when creating or modifying Storyblok components/blocks, content types, or fields, or modeling a content schema from multi-modal input. E.g. "model content for a blog", "add an image field to the teaser", "set up blocks for this landing page design". |
| `storyblok-use-cli` | Use when driving Storyblok through the Storyblok CLI — code-driven schema, content migrations, bulk pull/push of stories, components, assets or datasources, or scaffolding a project. |
| `storyblok-use-mcp` | Use when interacting with Storyblok through the MCP server — the tool model, operation names and payload shapes for stories, assets, components, datasources and every other resource. Load it before calling `mcp__storyblok__` tools, alongside the skill that owns the task. |
| `storyblok-use-storyblok` | Use when a request touches Storyblok at all. You MUST load it first — before any other Storyblok skill and before any `mcp__storyblok__` tool — to pick the right skill and the right tool for the job. E.g. "add an FAQ section to the pricing page", "model content for a blog", "set up Storyblok in this project". |

## Support and privacy

- Questions and bugs: [GitHub issues](https://github.com/storyblok/agent-plugin/issues).
- Security issues: report them privately to security@storyblok.com, not in a
  public issue.
- Privacy policy: [Storyblok Privacy Policy](https://www.storyblok.com/legal/privacy-policy).

## License

[MIT](./LICENSE)
