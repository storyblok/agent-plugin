# Working with assets

## 1. Write one manifest

Use unique keys. Omit file extensions from `name` and `path`; the script detects
the real MIME type and adds the correct extension.

```json
[
  {
    "key": "hero",
    "kind": "cms",
    "url": "https://www.figma.com/api/mcp/asset/...",
    "name": "hero",
    "alt": "Traveler with a suitcase"
  },
  {
    "key": "hero_decor",
    "kind": "code",
    "url": "https://www.figma.com/api/mcp/asset/...",
    "path": "public/decor/hero"
  }
]
```

- `cms`: upload content for a Storyblok `asset` or `multiasset` field.
- `code`: save fixed decoration or chrome in the project's asset directory.
- Whether an image is `cms` or `code` follows the schema, not the subject. Any
  image a block's `asset`/`multiasset` field points at is `cms`. `code` is for
  images no field references: chrome, and decoration a component draws
  unconditionally. Not every picture in the design is an upload.
- So decide the schema first, and decide it by where the image comes from. One
  the editor supplies — a per-item brand logo, a photo — earns an `asset` field,
  and its file is `cms`. A UI glyph never does. When it follows a variant or a
  label the component draws it unconditionally; when the editor should choose
  it, the field is an `option` naming icons the component already owns
  (`icon: bird | rocket | waveform`). Either way it is inline SVG inheriting
  `currentColor`, so it is neither a field the editor uploads to nor an entry in
  this manifest: an `asset` field there hands an editor something to swap that
  belongs to the token layer, and an `<img>` cannot carry the section's accent
  colour with it.
- An artwork subtree (a diagram, screenshot, or illustration flattened to one
  image) is a `cms` asset like any other. Its `url` is the node's
  `get_screenshot` URL when design context offers no asset URL for it.
- `get_screenshot` takes plain node ids only, never a component-instance
  sub-node id (`I1:2;3:4`). Export the nearest enclosing plain-id node instead
  of dropping the artwork.

## 2. Run once

```bash
cd "<project root>" && STORYBLOK_SPACE_ID="<space_id>" \
  "<skill-directory>/scripts/sync-assets.sh" \
  .figma-assets.json
```

The script:

- stages downloads in its own temporary directory and removes it on exit, so it
  writes nothing into the project except the `code` asset paths you asked for;
- downloads and MIME-checks every file;
- fixes misleading Figma extensions;
- prints the keys that succeeded even when others fail, and names the failures
  on stderr, so a partial run is never re-uploaded from scratch;
- processes at most six assets concurrently;
- uploads CMS assets with `STORYBLOK_TOKEN`;
- prints one JSON object.

Example result:

```json
{
  "hero": {
    "fieldtype": "asset",
    "id": 205821910222773,
    "filename": "https://a.storyblok.com/f/.../hero.png",
    "alt": "Traveler with a suitcase",
    "name": "",
    "title": "",
    "copyright": "",
    "focus": ""
  },
  "hero_decor": {
    "path": "public/decor/hero.svg"
  }
}
```

Each CMS value is a complete asset field value — write it into the story's
`asset` field as it stands, keeping every key. A `multiasset` field takes an
array of them. Reference each code asset by its returned path. Delete the
manifest after use.

## Single prepared file

Use `scripts/upload-asset.sh <path> [alt]` only when the file already exists
locally and no batch is needed. It prints one asset field value.
