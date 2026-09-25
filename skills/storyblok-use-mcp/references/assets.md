# Assets

Two objects share the name:

- **asset** library record: what `listAssets` and `getAsset` return, and what
  `fields` projects.
- **asset field value** is what a story field stores: a copy of a few of the
  asset's keys plus editor-only ones. They overlap; they are not the same set.

## Check the library first

An image the user refers to as "the shopfront photo" or "the logo we already
have" is in the space—find it. Only upload when the file comes from outside
Storyblok (a local path, a download).

```json
{
  "operation": "listAssets",
  "parameters": { "space_id": 12345, "search": "shopfront" },
  "fields": [
    "assets.id",
    "assets.filename",
    "assets.short_filename",
    "assets.alt",
    "assets.content_type"
  ]
}
```

Note: `assets.name` is a field-value key only, and the call fails on it. Need
more than the projection above? `describe` lists what the asset has.

## Upload a file

**1. Request the upload** — `mcp__storyblok__upload_asset`:

```json
{ "space_id": 12345, "filename": "shopfront.png" }
```

**2. POST the bytes to S3** with Bash. The returned `curl_command` repeats
`Content-Type` just before the `file` part — delete that duplicate!

**3. Finalize** — `mcp__storyblok__upload_asset_finish`:

```json
{ "space_id": 12345, "asset_id": 205821910222773 }
```

The response's `filename` is the public URL
(`https://a.storyblok.com/f/<space>/<hash>/shopfront.png`).

## Putting an asset into a story field

An `asset` field takes the **whole field value**.

```json
{
  "fieldtype": "asset",
  "id": 205821910222773,
  "filename": "https://a.storyblok.com/f/12345/16cac484c9/shopfront.png",
  "alt": "",
  "name": "",
  "title": "",
  "copyright": "",
  "focus": ""
}
```

- Keep all keys, even when they are empty.
- Reusing a library asset: copy `id` and `filename` from the `listAssets` hit.
- A `multiasset` field takes an array of these objects.
- Always write a meaningful `alt`. If not provided, open the file and describe
  it, following alt-text best practices and the context it appears in. A library
  asset lives at a remote URL — `curl` its `filename` to a local path and read
  that path; the URL itself is not readable.
