---
name: storyblok-implement-figma
description:
  Use when turning a Figma design into frontend components backed by Storyblok
  blocks. E.g. "figma to storyblok", "build this Figma design".
---

# Implement a Figma design with Storyblok

## Inputs to collect

1. **Figma URL** (required) — or a `fileKey` + `nodeId` pair.
2. Whether a story should be created — see step 6. Do not ask up front; offer it
   once the blocks exist.

The asset scripts read `STORYBLOK_TOKEN` from the environment and explain how to
resolve a missing value.

## Workflow

Do not finish with a step unaccounted for; if you skip one, say so and why.

```
- [ ] 1. Load storyblok-build-frontend and detect the project
- [ ] 2. Read the design
- [ ] 3. Build the content inventory
- [ ] 4. Apply storyblok-model-content
- [ ] 5. Upload the design's images
- [ ] 6. Offer to create a story
- [ ] 7. Generate the frontend with storyblok-build-frontend
- [ ] 8. Report
```

Load `storyblok-use-storyblok` before the first Storyblok call of the run — it
covers whether the MCP server or the CLI fits the job — and
`storyblok-model-content` for step 4's modeling.

Upload the design's images with the bundled script in step 5 rather than the MCP
upload tools, and read `resources/error-recovery.md` when Figma itself fails.

### 1. Load `storyblok-build-frontend` and detect the project

Load `storyblok-build-frontend` for any work touching frontend code, and run its
**step 1** to detect the project. It gives you:

- the **framework** — needed for step 2's `clientFrameworks`;
- the **block folder and the registration point**;
- the **existing blocks**, which are reuse candidates for sections in the
  design;
- the **styling mechanism** the generated code has to use;
- the **space id**, which step 5 needs.

### 2. Read the design

Extract `fileKey` and `nodeId` from the URL — in
`figma.com/design/:fileKey/:fileName?node-id=:nodeId`. Pass the `node-id` value
through as it stands; the API takes hyphens and colons alike (`1-234` and
`1:234` both resolve). **Percent-decode it first** — a link that carries an
encoded `%3A` is rejected outright.

Start with `get_metadata` on that node. It returns the whole page as a compact
tree — ids, names, sizes, absolute coordinates — with each `<text>` node's copy
in its `name`, which is most of step 3's inventory for a fraction of a full-page
`get_design_context`; the coordinates it carries, never the order it lists nodes
in, are where step 3's design order comes from.

Then call `get_design_context` once per section frame, taking ids from that
tree:

```
fileKey: <extracted>
nodeId: <section frame id from that tree>
clientLanguages: "html,css,typescript"
clientFrameworks: "<framework detected in step 1>"
```

The reference code in the response is **React + Tailwind by default — adapt it
to this project**; it is written for neither this stack nor Storyblok.

Reusable components appear as childless `<instance>` elements — fetch code for
the section frame that contains them, never one call per instance inside it.
Every call also renders the node as an image, so cost scales with what you ask
for. Repeated cards differing only in their icon are still one call: take each
card's asset from the section result, and fetch a single instance only when that
result genuinely omits it.

Large results commonly spill to a file. When that happens:

- Do not re-fetch `get_design_context` on narrower nodes or ask the user for one
  — this does not forbid step 5's own per-node `get_screenshot` export.
- Get the line count, section locations, text nodes, and token locations in one
  search call.
- Read the whole file in the largest non-truncating chunks — start at 500–800
  lines, reduce only after truncation, and combine known ranges into one call.

The design's variables and styles (type scale, colours, spacing, radii,
breakpoints) are the values step 7 expresses using the project's own styling
mechanism.

### 3. Build the content inventory

Freeze the section inventory before modeling. Two passes: classify subtrees
first, then inventory what is left.

**Pass 1 — find the artwork.** Artwork is a self-contained graphic that becomes
one image: a diagram, a product screenshot, an annotated wireframe, an
illustration. The test is editorial ownership, never the presence of text:

> Would an editor ever want to change this text on its own, and would the result
> still make sense without redrawing the graphic? If no, the whole subtree is
> one image.

Precedence: any never-flatten condition below wins outright over any number of
flatten signals, and the flatten default (including "when undecided, flatten")
applies only when no never-flatten condition holds.

Two or more of these mean flatten: a photo or raster fill blended with vector
shapes; children absolutely positioned, overlapping or rotated, with no
auto-layout for the DOM to carry; it depicts another interface (product
screenshot, wireframe, editor panel, code filename), whose text is that
interface's chrome and not this page's copy; connectors, arrows, halos or
callout pins tying text to shapes; every text node inside is a short label or
badge; node names read as artwork (`Group 13998`, `Bitmap`) while the section's
real copy sits in siblings named `Heading`, `Frame 316`.

Never flatten, however graphic-heavy: a heading + body pair, or any link or
button, is inside it; repeated siblings with one shape and differing copy (a
card grid, logo strip, testimonial row — that is a repeatable block); the text
is the section's own message (eyebrow, headline, subline, a stat with its
caption); a photo with a caption or credit beside it; the subtree is the whole
section — sections are never one image, so flatten the artwork inside them.
Proximity to a graphic does not make copy decorative.

When undecided, flatten: swapping an image is easy, unpicking a dozen junk
fields is not. State the split in your plan — which subtrees you are flattening,
which you are modeling as copy — and continue without waiting for an answer.

**Pass 2 — inventory the rest.** Record each section's role, editable
copy/images/links, repeated groups, reuse candidates, and design order.

- Derive design order from the frames' absolute coordinates in the design
  context you already fetched in step 2 — never from tree/child order and never
  from the order you happened to fetch or read nodes in. Ascending `y` gives the
  stacked order of page sections; ascending `x` (respecting reading direction)
  orders items within a row. Freeze that order in this inventory — order noted
  anywhere else does not reach step 4.
- Every text node outside the artwork is content. Text inside artwork is not
  inventoried and never gets a field.
- Links are content and their targets are fields. Underlined or accent-coloured
  text inside a paragraph is an inline link; a card or row that navigates has a
  destination. Record each with the text it wraps and where it points — a
  paragraph containing an inline link needs richtext rather than a textarea, and
  a navigating row needs its own link field.
- Site-wide header, navigation, footer, cookie-banner and similar chrome is
  code-owned rather than managed content — but it is still part of the design.
  Inventory its copy, links and logos as a separate code-owned list, which step
  7 renders. Keeping chrome out of the schema is correct; leaving it out of the
  implementation is not. Only an explicit request for managed chrome changes
  this.
- Do not choose field types or schema shapes; `storyblok-model-content` owns
  those decisions.

### 4. Apply `storyblok-model-content`

- Treat this as a design implementation: reuse or extend blocks that already
  cover a section.
- Follow the loaded skill for field types, reuse, whitelists, planning,
  confirmation, execution, and verification.
- Do not choose schema details before loading it.

### 5. Upload the design's images

Do not download, inspect, rename, upload, or clean each asset with separate tool
calls. Read `resources/assets.md`, write one manifest, and run
`scripts/sync-assets.sh` once.

Each artwork subtree from step 3 is one `cms` asset in that manifest, with `alt`
written from the labels inside the graphic so its meaning survives for screen
readers and search, or a plain description of what it depicts when it carries no
labels at all. Where design context gives no asset URL for the subtree — the
usual case, since it returns shapes and text — call `get_screenshot` with that
node's `fileKey` and node id, `contentsOnly: true`, and a `maxDimension` at or
above the node's longer dimension from step 2, then use the URL it returns.
`maxDimension` only caps: it downscales anything larger — the 1024 default
silently shrinks a wide node — and never renders above 1x, so there is no point
asking for more. Exporting a subtree this way is neither a substitute for
`get_design_context` nor a validation step; it is how artwork becomes an asset.
`contentsOnly` can exclude floating content parented to the page rather than the
subtree (e.g. a connector or callout drawn above a section). The response's
dimensions cannot show that: view every render before it goes in the manifest. A
piece missing means re-export without `contentsOnly`; the whole node coming back
as a solid block means an ancestor backdrop was baked in, so export the
graphic's own layer instead.

### 6. Offer to create a story

- Honour an existing choice. Otherwise offer once after the blocks exist.
- When a story should be created, read `resources/story.md` and follow it.

The story comes before the code: without one there is nothing for a frontend to
render.

### 7. Generate the frontend with `storyblok-build-frontend`

Continue in that skill from its **step 2**, carrying:

- the **blocks created in step 4**, each with the field names verified during
  modeling;
- the **section inventory from step 3**, in design order;
- the **design's values from step 2** — type scale, colours, spacing, radii,
  breakpoints;
- the **code-owned chrome list from step 3**;
- the **asset filenames uploaded in step 5**;
- the **story slug from step 6**, if a story was created.

### 8. Report

`storyblok-build-frontend`'s report step covers the code — files, registration
changes, colour tokens, and any check skipped. Add the design-side facts:

- the assets uploaded in step 5, and the artwork subtree each one came from;
- the story created in step 6, if any, with its slug;
- every place the implementation knowingly diverges from the design.

Report a divergence instead of quietly leaving it unmentioned.

## Resources

- `resources/assets.md` — load before processing Figma assets.
- `resources/story.md` — load only when a story should be created.
- `resources/error-recovery.md` — load only after an actual workflow error.

## Scripts

- `scripts/sync-assets.sh` — process one asset manifest.
- `scripts/upload-asset.sh` — upload one prepared file.
