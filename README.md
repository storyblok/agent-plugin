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

Or from a shell, with a Git URL (HTTPS or SSH) or the path to a local clone:

```sh
claude plugin marketplace add https://github.com/storyblok/agent-plugin.git
claude plugin install storyblok@storyblok
```

**Codex**

```sh
codex plugin marketplace add storyblok/agent-plugin
codex plugin add storyblok@storyblok
```

`marketplace add` also takes a Git URL (HTTPS or SSH) or the path to a local
clone, e.g. `codex plugin marketplace add https://github.com/storyblok/agent-plugin.git`.

**Cursor**

```sh
git clone https://github.com/storyblok/agent-plugin ~/.cursor/plugins/local/storyblok
```

Then run **Developer: Reload Window**. Local plugins need **Allow Local Plugin
Imports** enabled. Teams can instead add the repo under Dashboard → Plugins &
MCPs → **Add Marketplace** → **Import from Repo**.

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
| `storyblok-build-frontend` | Generating frontend components for Storyblok blocks — writing, registering and validating the framework code that renders a space's content. E.g. "generate components for my blocks", "build an Astro + Storyblok landing page". |
| `storyblok-implement-figma` | Turning a Figma design into frontend components backed by Storyblok blocks. E.g. "figma to storyblok", "build this Figma design". |
| `storyblok-model-content` | Creating or modifying Storyblok components/blocks, content types, or fields, or modeling a content schema from multi-modal input. E.g. "model content for a blog", "add an image field to the teaser", "set up blocks for this landing page design". |
| `storyblok-use-cli` | Driving Storyblok through the Storyblok CLI — code-driven schema, content migrations, bulk pull/push of stories, components, assets or datasources, or scaffolding a project. |
| `storyblok-use-mcp` | Interacting with Storyblok through the MCP server — the tool model, operation names and payload shapes for stories, assets, components, datasources and every other resource. Load it before calling `mcp__storyblok__` tools, alongside the skill that owns the task. |
| `storyblok-use-storyblok` | A request touches Storyblok at all. You MUST load it first — before any other Storyblok skill and before any `mcp__storyblok__` tool — to pick the right skill and the right tool for the job. E.g. "add an FAQ section to the pricing page", "model content for a blog", "set up Storyblok in this project". |

## What the skills run, fetch and send

The skills are instructions for the agent. Besides the MCP server, they run
these on the user's machine, only while doing the job the skill describes:

- **Asset upload** (`storyblok-implement-figma`: `sync-assets.sh`,
  `upload-asset.sh`) downloads each image listed in the asset manifest from its
  URL (usually a Figma export), then uploads it to the user's Storyblok space:
  the Storyblok Management API for the space's region (e.g.
  `mapi.storyblok.com`) and the signed upload URL that API returns. It
  authenticates with the personal access token the user names (an environment
  variable or a secret-manager command), which the agent pipes in on stdin; a
  token that is merely set in the environment is never used. The token reaches
  curl through a private temporary file, never the command line, and is not
  written to the project or sent anywhere else.
- **Page screenshots and image checks** (`storyblok-build-frontend`:
  `screenshot-page.sh`; `storyblok-implement-figma`: `preview-assets.sh`,
  `inspect-image.sh`) open the given page or images in headless Chromium and
  write the result to a local file. They use the project's own Playwright when
  it has one. Otherwise they run Playwright 1.63.0 from npm through `npx`, and
  Playwright downloads Chromium if none is installed.
- **Storyblok CLI**: the skills may run the
  [Storyblok CLI](https://www.storyblok.com/docs/libraries/storyblok-cli) from
  npm, which uses its own login.
- **Storyblok Management API**: when neither the MCP server nor the CLI has an
  operation, the skills may call the Management API directly with the personal
  access token the user names. Without one, the agent asks which to use.

## Support and privacy

- Questions and bugs: [GitHub issues](https://github.com/storyblok/agent-plugin/issues).
- Security issues: report them privately to security@storyblok.com, not in a
  public issue.
- Privacy policy: [Storyblok Privacy Policy](https://www.storyblok.com/legal/privacy-policy).

## License

[MIT](./LICENSE)
