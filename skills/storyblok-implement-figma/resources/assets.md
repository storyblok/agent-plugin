# Working with assets

## 1. Write one manifest

Use unique keys. Each entry names its source as either `url` or `file`, a local
path for an image you prepared yourself (a crop, a converted export) — never
both. Omit file extensions from `name` and `path`; the script detects the real
MIME type and adds the correct extension. `file` is the opposite case: it is a
source the script reads, not a destination it names, so write it exactly as it
is on disk, extension included.

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
    "key": "case_study_tomtom",
    "kind": "cms",
    "file": ".design/prep/case-study-tomtom.png",
    "name": "case-study-tomtom",
    "alt": "TomTom dashboard"
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

## 2. Preview it

```bash
"<skill-directory>/scripts/preview-assets.sh" .figma-assets.json preview.png
```

One image holding every entry, labelled with its key and set on a checkerboard
so transparency reads apart from a baked-in backdrop. Fix the manifest before
running the sync, and delete the preview after.

`"<skill-directory>/scripts/inspect-image.sh" <path-or-url>...` reports the
dimensions, opaque share and dominant colours of every image in one call when
the preview leaves that in doubt.

## 3. Run once

```bash
cd "<project root>" && printf '%s' "$<TOKEN_VARIABLE>" |
  STORYBLOK_SPACE_ID="<space_id>" \
  "<skill-directory>/scripts/sync-assets.sh" \
  .figma-assets.json
```

`<TOKEN_VARIABLE>` is the variable the user named. For a secret-manager command,
pipe that command instead of `printf`. A manifest with only `code` entries needs
no token, so drop the pipe.

The script:

- stages downloads in its own temporary directory and removes it on exit, so it
  writes nothing into the project except the `code` asset paths you asked for;
- downloads and MIME-checks every file;
- fixes misleading Figma extensions;
- prints the keys that succeeded even when others fail, and names the failures
  on stderr, so a partial run is never re-uploaded from scratch;
- processes at most six assets concurrently;
- uploads CMS assets with the token it reads on stdin, never one from the
  environment;
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

Use `scripts/upload-asset.sh <path> [alt]`, with the token piped in the same
way, only when the file already exists locally and no batch is needed. It prints
one asset field value.
