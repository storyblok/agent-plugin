# Stories

## Find a story

There is **no get-by-slug operation**. A slug becomes an ID first:

```json
{
  "operation": "listStories",
  "parameters": { "space_id": 12345, "by_slugs": "pricing", "per_page": 1 },
  "fields": ["stories.id", "stories.name", "stories.full_slug"]
}
```

- Strip a leading `/` from slugs; nested slugs are `blog/my-post`.
- `stories.content` is **not** a valid `listStories` field — lists carry
  metadata only.
- When the user names a page rather than a slug ("the Pricing page"), use
  `search: "pricing"` — it matches `name` and `slug`, case-insensitively, as a
  substring. Match on story content instead with `text_search`. Confirm the
  match before writing to it.

## Read a story

Full `content` comes only from `getStoryById`:

```json
{
  "operation": "getStoryById",
  "parameters": { "space_id": 12345, "id": 205821755252760 },
  "fields": [
    "story.id",
    "story.name",
    "story.full_slug",
    "story.published",
    "story.content"
  ]
}
```

**Story-reference fields come back as UUIDs and are never expanded.** If you
need them, resolve them in a single batched call:

```json
{
  "operation": "listStories",
  "parameters": { "space_id": 12345, "by_uuids": "<uuid1>,<uuid2>,<uuid3>" },
  "fields": ["stories.id", "stories.name", "stories.full_slug", "stories.uuid"]
}
```

## The content object

`content` is a tree: a root object with the content type's fields, blocks nested
in `bloks` fields. Every node has a `component` key naming its component, and
Storyblok stores a `_uid` on each. Component schemas are in
`references/components.md`.

```json
{
  "_uid": "3f2a1c4e-0000-4000-8000-000000000001",
  "component": "page",
  "headline": "Service and repairs",
  "intro": {
    "type": "doc",
    "content": [
      {
        "type": "paragraph",
        "content": [
          {
            "type": "text",
            "text": "The workshop has serviced bikes since 1998."
          }
        ]
      }
    ]
  },
  "body": [
    {
      "_uid": "3f2a1c4e-0000-4000-8000-000000000002",
      "component": "banner",
      "headline": "Book a service",
      "text": "Same-week slots available."
    }
  ]
}
```

Field-value shapes:

- **richtext** — a ProseMirror document, `{"type":"doc","content":[…]}`, with
  `paragraph` nodes wrapping `text` nodes. A plain string is not a richtext
  value. Headings are `{"type":"heading","attrs":{"level":2},…}`; lists are
  `bullet_list`/`ordered_list` with `list_item` children.
- **asset** — the full asset object (see `references/assets.md`).
- **option / options backed by a datasource** — the entry's `value` string, not
  its display name (see `references/datasources.md`).
- **bloks** — an array of block objects, each with `component` and its fields
  (see `references/components.md`).
- **`_uid`** — omit it on blocks you create; the server fills one in. On blocks
  that already exist, **carry the existing `_uid` through unchanged** so editor
  state and references survive.

## Create a story

```json
{
  "operation": "createStory",
  "parameters": {
    "space_id": 12345,
    "publish": true,
    "story": {
      "name": "Workshop",
      "slug": "workshop",
      "content": { "component": "page", "headline": "Service and repairs" }
    }
  }
}
```

- `content.component` must name a content type (a component with
  `is_root: true`) — see `references/components.md`.
- `publish: true` creates it published; omit it to leave a draft. Match what the
  user asked for, and say which you did.
- Always pass an explicit `slug` — slugify the name yourself (`Workshop` →
  `workshop`) unless the user named a different URL. The server derives none.
- Check the slug is free first: `listStories` with `by_slugs: "<slug>"` and the
  projection above. A hit means the page already exists — ask whether to update
  it rather than creating a second story.
- Nest a story under a parent by passing the parent's numeric id as
  `story.parent_id`.

## Update a story

**`story.content` is replaced in full!** So always read-modify-write:

1. `getStoryById` for the current story, including `content`.
2. Merge your change into that content object client-side, keeping every
   existing field, block, and `_uid`.
3. Send the complete merged object:

```json
{
  "operation": "updateStory",
  "parameters": {
    "space_id": 12345,
    "id": 205821755252760,
    "publish": true,
    "story": { "content": { "…": "the complete merged content object" } }
  }
}
```

- `publish: true` republishes in the same call. On an already-published story,
  leaving it out parks the change as an unpublished draft — pass it, or tell the
  user the change is not live.
- Editing richtext: change the text inside the existing document rather than
  replacing it with a fresh one, so marks and structure survive. Adding a
  sentence to a paragraph means editing that `text` node's string; adding a
  paragraph means appending a `paragraph` node to `doc.content`.
- Inserting a block "at the top" means position 0 of the `bloks` array; "after
  the existing content" means the end.

## Publishing and deleting

All three take `parameters: { space_id, id }` and nothing else:

| Operation        | Executor              |
| ---------------- | --------------------- |
| `publishStory`   | `execute_mutating`    |
| `unpublishStory` | `execute_mutating`    |
| `deleteStory`    | `execute_destructive` |

Prefer `publish: true` on `createStory`/`updateStory` when the content is
already final; `publishStory` is for publishing a draft later.

`unpublishStory` takes a live page off the site — treat it as destructive.

## Reporting a story back

Do not dump raw `content` JSON by default.

1. Header line: `name`, `full_slug`, `id`, published state.
2. The content as an indented block tree — one node per block, labelled by its
   `component`, readable field values beneath it. Render richtext as its text,
   not its node tree. Note i18n fields (`<field>__i18n__<locale>`) with their
   locale inline.
3. Offer the raw JSON; show it only if asked.
4. Report unresolved references as a count plus their UUIDs and offer to resolve
   them — don't resolve automatically.

Reads return the **draft** working copy by default. If the user needs what is
live, say so rather than assuming the two match.
