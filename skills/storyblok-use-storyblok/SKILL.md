---
name: storyblok-use-storyblok
description:
  Use when a request touches Storyblok at all. You MUST load it first — before
  any other Storyblok skill and before any `mcp__storyblok__` tool — to pick the
  right skill and the right tool for the job. E.g. "add an FAQ section to the
  pricing page", "model content for a blog", "set up Storyblok in this project".
---

# Start here for Storyblok

Take stock, pick the tool, pick the skill.

In that order. Load no other skill until §1 has run and §2 has picked the tool —
otherwise you are working through a tool you never chose.

## 1. Take stock — once, at the start

| Check       | How                                                                                                                                                             |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| MCP server  | `mcp__storyblok__*` tools present; load them with `ToolSearch` if deferred — nothing found means no server, so stop looking and do not load `storyblok-use-mcp` |
| CLI         | `node_modules/.bin/storyblok`, else the package manager's exec, else `command -v storyblok`                                                                     |
| CLI session | `storyblok user` — installed is not logged in                                                                                                                   |
| Schema mode | `@storyblok/schema` in `package.json`, or a file exporting `defineSchema` — usually `src/schema/`                                                               |
| `space_id`  | `storyblok.config.ts`, then the environment, then ask                                                                                                           |

Do this before §2, every time — routing on an assumption about which tools exist
is the one mistake that cannot be recovered later.

Probe for the CLI with `command -v`, never with a version flag. The flag is
`--vers`; `storyblok --version` is an unknown option that exits non-zero, so it
reports a working CLI as missing. Do not suppress a probe's stderr — the error
that explains itself is the part you need.

Run each `storyblok` probe as its own Bash call. Chained behind `;` or `&&` into
a wider command it gets held for approval, and the retry usually drops the probe
— leaving you to guess at the one thing §2 routes on.

Never accept a token through the chat, and never write one down — a variable
name, or a command that reads the token from the user's secret manager, is a
valid way to be handed one. The MCP server and the CLI each hold their own
credentials.

Two credentials, for two APIs. A **personal access token** (`STORYBLOK_TOKEN`,
or `STORYBLOK_PERSONAL_ACCESS_TOKEN`) grants account-wide Management API access:
the MCP server, the CLI and `curl` run on it. A **delivery token**
(`STORYBLOK_DELIVERY_API_TOKEN`) is space-scoped, read-only content access, and
the only one that may reach frontend code or a `.env`. A personal access token
never goes there.

## 2. Pick the tool

The MCP server and the CLI reach the same Management API; what differs is the
shape of the work.

- **MCP** — one operation per call, straight against the space. No local state,
  nothing to clean up, the result is immediate. Cost scales per item: fifty
  stories is fifty calls.
- **CLI** — file-oriented. `pull` writes local JSON, you edit it, `push` sends
  it back. That round trip is overhead for one item and leverage for fifty, and
  it leaves an artifact that can be reviewed, diffed and committed.

So, as a default:

| Task                                                                                | Tool                                          |
| ----------------------------------------------------------------------------------- | --------------------------------------------- |
| Look up or search stories, resolve a slug, read a component schema, explore a space | MCP                                           |
| Create or edit one story, block or component                                        | MCP                                           |
| Upload one asset; read datasource entries                                           | MCP                                           |
| Manage the schema from the repo                                                     | CLI `schema init/validate/push/rollback`      |
| Transform existing story content after a breaking schema change                     | CLI `migrations generate/run/rollback`        |
| Many stories, components, assets or datasources at once; space-to-space transfer    | CLI `<resource> pull/push`, `assets transfer` |
| Scaffold a new project                                                              | CLI `create`                                  |
| TypeScript types for a space                                                        | CLI `types generate` — but see §4             |

Only two rows are fixed: schema-as-code and migrations have no MCP equivalent.
The rest is a starting point — when the shape of the job argues the other way,
take the other tool and say why. A single story that should land in the repo as
a reviewable file is a fair use of the CLI; a two-item "bulk" change is a fair
use of MCP.

- **A tool that cannot do the job is not the tool for it.** Take the next rung
  down and keep going: MCP → CLI → the Management API with `curl`. Not installed
  and cannot do it count the same — the CLI has no `stories delete`, so a delete
  in a session without the MCP server is a curl. Say nothing about the rung you
  skipped or the reasoning behind it: the user asked for an outcome, not a
  tooling report. A logged-out CLI is waiting, not unavailable — §4 says what to
  do.
- **If §1 looked and found no `storyblok` binary, the CLI does not exist for the
  user.** Never name it, a `storyblok …` command, or an install line — not while
  working, not in the closing summary, and not as an optional next step ("to
  keep this in sync…", "next time you could…"). An offer is a suggestion, and so
  is an excuse: do not explain that you worked around a missing CLI, or that the
  project has none. Say what you did, not what you could not do. §4 is the sole
  exception.
- Decide once per task, not per step — and once §1 has answered whether a tool
  exists, do not go looking again.

The mechanics of that last rung — hosts, auth, the curl shape — are in
`references/management-api.md`. Read it before the first call.

Close with what you did and where the result landed. No tooling-based next
steps.

## 3. Pick the skill

| Request                                                    | Skill                       |
| ---------------------------------------------------------- | --------------------------- |
| Answer a question — a lookup that writes nothing           | none — the tool skill alone |
| Model or change blocks, content types, fields, datasources | `storyblok-model-content`   |
| Write the frontend components that render blocks           | `storyblok-build-frontend`  |
| Turn a Figma design into blocks and frontend               | `storyblok-implement-figma` |
| The mechanics of driving the MCP server                    | `storyblok-use-mcp`         |
| The mechanics of driving the CLI                           | `storyblok-use-cli`         |

Load the skill for the tool you picked in §2 — `storyblok-use-mcp` or
`storyblok-use-cli` — always, including when no task skill applies. Alongside
the task skill, never instead of it. §2 picks the tool; a row here never
overrides it.

Settle §4 before starting a request that changes the schema.

## 4. Space or code?

A schema lives either in the space or in the repo as `@storyblok/schema`
definitions pushed with the CLI. The fork is about where the source of truth
sits, not which tool may touch it — a space-mode schema can still travel by
`components pull/push` where that fits.

- Any schema-mode signal from §1 → code. Do not ask.
- No signal, and the task changes the schema → **stop and ask, before loading
  the task skill and before reading the space:** "This repo doesn't say where
  your blocks live — do you maintain them in the Storyblok UI, or as code in the
  repo?" Wait for the answer; carry it for the session. Auditing the space first
  is wasted work: in code mode the repo is the source of truth, not the space.
- **Code mode is the one time you install the CLI.** Say what you are about to
  do, add `storyblok` and `@storyblok/schema` as devDependencies with the repo's
  package manager, then run `storyblok user`. No session → ask the user to run
  `storyblok login` themselves and wait; the prompt is interactive and you
  cannot complete it. Re-check, then continue. Do not model it in the space
  meanwhile: the repo is the source of truth, and the next push overwrites what
  you added.
- In code mode, types come from the schema (`Schema<typeof schema>`), never from
  `storyblok types generate`.

## 5. Reading the docs

Append `.md` to any `storyblok.com/docs/...` URL before fetching it to return
Markdown (e.g., fetch https://www.storyblok.com/docs/concepts/blocks.md instead
of https://www.storyblok.com/docs/concepts/blocks).
