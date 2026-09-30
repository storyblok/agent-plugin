---
name: storyblok-use-mcp
description:
  Use when interacting with Storyblok through the MCP server — the tool model,
  operation names and payload shapes for stories, assets, components,
  datasources and every other resource. Load it before calling
  `mcp__storyblok__` tools, alongside the skill that owns the task.
---

# Work with Storyblok through the MCP server

## Inputs

`space_id` (integer) is required on nearly every operation, and it is all you
need — the server derives the region from it.

`listSpaces` and the few other operations taking no `space_id` have nothing to
derive from: `describe` marks them `requiresRegion`, and they need `region`
passed explicitly even when it is `eu`.

## Tool model

Most of the API runs through **generic executors** taking an `operation` name
plus `parameters`:

| Tool                                  | For                                                  |
| ------------------------------------- | ---------------------------------------------------- |
| `mcp__storyblok__execute_readonly`    | reads (`listStories`, `getStoryById`, `listAssets`…) |
| `mcp__storyblok__execute_mutating`    | creates and updates                                  |
| `mcp__storyblok__execute_destructive` | deletes                                              |
| `mcp__storyblok__search` / `describe` | finding operations and their parameter schemas       |

`describe` returns an operation's executor as `executeWith`. Mind the argument
names: the executors take `operation`, `describe` takes `operationId`.

`mcp__storyblok__upload_asset` and `mcp__storyblok__upload_asset_finish` are
**standalone tools, not operations**. `describe` on them returns
`Operation "upload_asset" not found` — that means wrong tool family, not
unsupported.

If MCP tools are deferred in your session, load the executors you need with
`ToolSearch`, e.g.
`select:mcp__storyblok__execute_readonly,mcp__storyblok__execute_mutating`.

## Method

1. **Read the reference for a resource before your first call on it** — not only
   the resource the request names. A story edit that turns out to need a
   component or a datasource has reached a new one; read that reference then,
   before calling.
2. **Execute directly.** Do not open with `search`/`describe`. They are
   error-recovery tools.
3. **Error recovery:** when a call is rejected, _then_ `search` for the
   operation, `describe` it, fix the payload, and retry.

Operation names do not follow from the resource name — the component list is
`listManagementComponents`, and `listComponents` does not exist. Take them from
the reference:

| Reference                   | Covers                                            | Starts from                                                    |
| --------------------------- | ------------------------------------------------- | -------------------------------------------------------------- |
| `references/stories.md`     | stories, slugs, richtext, blocks, publishing      | `listStories`, `getStoryById`, `createStory`, `updateStory`    |
| `references/assets.md`      | uploads, library assets, asset field values       | `listAssets`, then the `upload_asset` tools                    |
| `references/components.md`  | component schemas, new blocks, whitelists         | `listManagementComponents`, `getComponent`, `createComponent`  |
| `references/datasources.md` | datasources, entries, the option fields they feed | `listDatasources`, `createDatasource`, `createDatasourceEntry` |

## Rules that hold everywhere

- **Writes replace, they do not merge.** `updateStory`'s `content` and
  `updateComponent`'s `schema` are full replacements — read the current object,
  merge your change into it client-side, send the whole thing back.
- **Content that fits no existing component is a schema gap, not a puzzle.**
  Create the block and whitelist it — see `references/components.md`, or the
  `storyblok-model-content` skill when the job is modeling rather than a single
  block.
- **Choices reused across fields or maintained by editors are a datasource**,
  not options hardcoded into each field. See `references/datasources.md`.
- **Do not invent editorial copy.** Headlines, body text, taglines: fill the
  fields the request gives you words for and leave the rest empty. If a required
  field forces your hand, name the wording as yours in the report. Descriptive
  metadata is the opposite case — write `alt` text for every image, from the
  file itself if you have it, and no disclosure needed.
- **Project your list calls.** Pass a top-level `fields` array (a sibling of
  `operation`/`parameters`) on list operations; unprojected responses flood
  context and can hit the MCP's output truncation. When content comes after the
  list, include `components.schema` — otherwise you pay a `getComponent` per
  component you write. A path names fields, never array elements:
  `story.content.body` is valid, `story.content.body.0` is rejected outright.
- **Field values have shapes** — an asset field does not take a URL, a richtext
  field does not take a string. The reference for the resource has them.

## Before and after a write

- **Mutating:** say what you are about to change _before the first write of the
  task_ — the stories, components, datasources and assets you will touch, in a
  few lines. This is not optional and it is not the closing summary:
  pre-approved and non-interactive runs skip the _confirmation_, never the
  statement. In an interactive session, stop there and get confirmation;
  otherwise say it and proceed.
- **Destructive** (deletes, unpublishing, bulk operations): confirm explicitly
  and separately, naming exactly what will be lost. Never run one unattended.
- **Report honestly.** List what was created, changed, and left alone. If you
  met the request differently than it was phrased (a new block type, a schema
  extension, a normalized value), say so.
