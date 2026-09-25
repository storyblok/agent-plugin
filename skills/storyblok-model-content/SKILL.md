---
name: storyblok-model-content
description:
  Use when creating or modifying Storyblok components/blocks, content types, or
  fields, or modeling a content schema from multi-modal input. E.g. "model
  content for a blog", "add an image field to the teaser", "set up blocks for
  this landing page design".
---

# Model Storyblok content

Design a content model and set it up in a Storyblok space: components (nestable
blocks and content types), component groups, and datasources. This skill
**changes the space schema**. It never edits story content — with one narrow,
explicitly-approved exception: a component rename may pass
`update_content: true` so existing story references follow the new name (see the
rename notes below). It can also delete components, datasources, and datasource
entries — deletions are **destructive**: always called out in their own
clearly-marked section of the plan, always confirmed explicitly and separately
from the rest of the batch, and never run unattended.

## Inputs

**Requirements source** — one of: a written brief, a web page URL, or a design
sketch/screenshot the user provides.

## Tooling

**Load `storyblok-use-storyblok` first.** It covers whether the MCP server or
the CLI fits the job, and names the skill carrying that tool's payload shapes
and commands.

## Guardrails

- **Never write before the plan is approved.** Never run unattended against a
  production space.
- **`updateComponent` is read-modify-write** — full merged schema, always. A
  partial schema deletes every field you left out.
- **Deletes are gated, destructive operations** (`deleteComponent`,
  `deleteDatasource`, `deleteDatasourceEntry`, all via
  `mcp__storyblok__execute_destructive`). Only execute one that was named
  individually in an explicitly confirmed plan — never infer or add one
  mid-execution, never run one unattended. When the actual goal is a rename,
  prefer the real rename (`updateComponent` with `update_content: true`, step
  6.4) over delete-and-recreate — a delete has no reference-rewriting equivalent
  and breaks every story block pointing at the old component.
- **No component-group creation in space mode.** The MCP server exposes no
  operation to create a group — only to assign a component to an existing one.
  Never claim or attempt to create one; route new-group needs back to the user
  (UI creation) per step 4. Code mode has no such limit: `schema push` creates
  missing groups.

## Steps

### 1. Extract the requirements

Turn the source into one intermediate: a list of candidate components, each with
its fields.

- **Brief:** identify the entities (things with their own lifecycle: posts,
  authors, products) and the page sections (hero, teaser, testimonial…).
- **URL:** fetch the page. Identify the distinct, repeatable sections and the
  editable content inside each.
- **Sketch/screenshot:** read the image and do the same section-by-section
  extraction.
- **Chrome is out of scope, for every source:** do not model navigation,
  headers, footers, or cookie banners unless the user explicitly asks for them
  by name. "Rebuild this page" means its content sections — nav and footer
  belong to the site, not the page, and modeling them uninvited is
  over-modeling, not thoroughness. Announcement bars are not chrome: their copy
  is editorial and changes often, so model them as a content section.

### 2. Audit the space

In code mode the local schema files are the audit — read them, and let
`schema push --dry-run` in step 6b reconcile anything remote you did not see.
**Read `resources/schema-as-code.md` first, before any definition file.** It
carries the `define*` helpers and the three places the DSL departs from the API
— `allow`/`deny` in place of `component_whitelist`, folder refs, datasource
refs. Skip it and the DSL has to be reverse-engineered out of
`@storyblok/schema`'s type definitions, which is slow and still gets the wire
keys wrong.

Otherwise list what already exists with one read-only call:
`listManagementComponents` with `parameters: { space_id: <id> }` and a top-level
`fields` projection (a sibling of `operation`/`parameters`, not inside them):
`fields: ["components.id", "components.name", "components.display_name", "components.is_root", "components.is_nestable", "components.component_group_uuid", "component_groups.name", "component_groups.uuid"]`.
Never call it unprojected — the full response carries every component's `schema`
and can flood context or hit the MCP's ~25k-token output truncation on a mature
space. The response's `component_groups[]` array is the only source of existing
groups (there is no list-groups operation). On a very large space, narrow
server-side instead of listing everything: add `search: "<name>"` (matches
name/display_name) or `by_ids` to `parameters`, keeping the same projection.

Use the audit for two things: **reuse** (a needed section an existing component
already covers, exactly or nearly) and **conventions** (match the space's naming
style for anything new). Fetch a single component's full schema (`getComponent`,
`parameters: { space_id: <id>, id: <numeric id> }`, no projection) only when you
plan to extend it — always via the **numeric id from the audit**; by-name
lookups 404 on some operations, so never rely on them.

### 3. Decide the model

Apply these rules at each decision:

- **Content type vs nestable block:** it has its own URL or standalone lifecycle
  (post, author, product) → content type (`is_root: true`); it is a section
  composed into pages → nestable block (`is_nestable: true`).
- **Reuse before create:** if an existing component covers most of the need,
  extend it with new optional fields. Match by role, not name: a design's
  top/cover/masthead section (image, headline, CTA) is usually the space's
  existing hero component even when the design doesn't call it that — extend it
  rather than re-modeling those fields inline. Never create a near-duplicate
  (`hero_v2`, `hero_new`).
- **But content that fits nothing needs a new component.** When a request
  describes content no existing component can hold, create the component and add
  it to the parent `bloks` field's `component_whitelist`. Judge fit by
  _meaning_, not by whether some component happens to have enough text fields to
  absorb the strings: putting a testimonial in a teaser because both hold a
  headline and body text is the worse outcome. A `component_whitelist` that
  lacks the block you need is a list to extend. This is the counterweight to
  reuse-before-create: reuse what means the same thing, create what doesn't.
- **Additive evolution on components stories already use:** prefer adding new
  optional fields over renaming or re-typing existing ones. Schema changes do
  not migrate story content — a rename or type change orphans whatever is
  already stored (see the "Schema changes ripple into existing stories" section
  below).
- **Reference vs nest:** content shared across stories (authors, categories,
  products) → its own content type, linked with a story-reference field; one-off
  section content → nest it inline as a block.
- **Anything that navigates gets a link field.** A button, a nav row, a card
  that reads as a link — each needs a `multilink` an editor can point somewhere,
  even when the source material shows no target: a button with nowhere to point
  is one the editor cannot use. A paragraph with a link inside it is `richtext`,
  not `textarea`.
- **Datasource vs inline options:** an option list used by 2+ components or
  maintained by editors → datasource; two or three static values in one place →
  inline `options`.
- **A `styled` class the frontend styles must be declared on the field.** A
  `richtext` value can carry `{"type": "styled", "attrs": {"class": "…"}}`
  marks, but the editor only offers classes the field declares:
  `style_options: [{ "name": "<label the editor picks>", "value": "<css class>" }]`.
  A non-empty `style_options` is all it takes to surface the picker;
  `customize_toolbar` and `toolbar` neither gate it nor have an entry for it,
  and a `toolbar` array hides every element it omits — so leave both alone.
- **Naming:** follow the space's existing convention first; otherwise snake_case
  field names, short descriptive component names, and always a human-readable
  `display_name`. One name per role across everything you create in a run — pick
  one of `intro`/`subcopy`/`description` for a section's supporting paragraph
  and use it in every block that has one.
- **Groups — assign existing only:** the Storyblok MCP server has no operation
  to create a component group; `component_group_uuid` only lets you assign a
  component to a group that already exists (from the audit's
  `component_groups[]`). If the model calls for a brand-new group, do not invent
  one — flag it as a group gap now (see step 4) rather than discovering it
  mid-execution.
- **No sibling for what a field already carries:** an `asset` field holds `alt`
  and `title` itself, and a story-reference field resolves the story's own
  fields. A parallel `image_alt` text field duplicates data that can then
  disagree with itself.
- **Always whitelist `bloks` fields** — an unrestricted body field is an
  anti-pattern; restrict to the components that belong there.
- **`required` sparingly** — only fields the frontend cannot render without.
  **`translatable` only** for fields holding language-specific copy.
- **Flat over deep:** avoid nesting beyond 2–3 levels; prefer more, smaller
  blocks.
- **Content, not presentation:** no fields carrying CSS values — `margin_top`,
  `font_size`, `shadow`, or colour options whose values are literal hues
  (`#f0bb1f`, `yellow`, `teal`). Semantic options the frontend maps to tokens
  are fine (`variant: primary | secondary`, `emphasis`, `featured`). Decoration
  that follows from position (every second row reversed) is derived in the
  frontend, not stored; a genuine editorial choice is a field named for its
  meaning (`featured`), never the treatment (`is_yellow`). **It is the values
  that decide it, not the field name.** A colour-carrying option is fine when
  its values name a role the frontend maps to a token
  (`variant: primary | secondary | tertiary`); it is wrong when they name the
  hue, however neutral the field name is (`theme: purple | blue`), which pins
  content to a palette and breaks on a re-theme. When a design gives each
  section its own accent, store the role and let the frontend own which hue that
  role resolves to. A UI glyph is not content either, and it is never an `asset`
  field. An icon that always follows a variant or label needs no field at all —
  the component draws it from the variant. When the editor genuinely chooses the
  icon, give them an `option` field whose values name icons the component
  already owns (`icon: bird | rocket | waveform`), and resolve the name to
  inline SVG in the component so it inherits `currentColor`. An `asset` field is
  for an image the editor supplies, never one they pick from a fixed set.
- **Never remove existing fields:** when extending a component, keep every field
  the request does not touch — removing one orphans story data. Offer schema
  cleanup only if the user asks, as a destructive deletion.
- **Model incrementally:** cover what the user asked for; do not speculatively
  add components or fields for imagined future needs.

### 4. Present the plan

Before any write, show the full proposed model in one readable block — tight and
scannable, with only the sections that apply:

- Each component: name, kind (content type / nestable), group, and its fields as
  `field_name (type, notable settings)` — marked **new**, **reused as-is**, or
  **extended** (with exactly which fields will be added or changed).
- On extended components, tag each change **safe** (add a field, widen a
  whitelist, add to a group) or **content-affecting** (rename a field or the
  component, change a field's type, tighten a whitelist), and give each
  content-affecting change its one-line consequence, e.g. "renaming
  `title`→`headline` orphans existing `title` data; stories keep serving the old
  key until migrated." Per-change annotations, not prose.
- Every `option`/`options` field's values written out, so one naming a hue or a
  CSS treatment is caught before the write.
- Any datasources (with entries) to be created.
- **Deletions get their own section, labeled destructive:** never folded in as
  just another change — each with its one-line consequence (see the ripple facts
  below), so the user is confirming a named, understood loss, not a vague
  "remove X".
- **Group gaps called out explicitly (space mode only):** the MCP cannot create
  component groups, so if the plan needs a group that doesn't exist yet, offer
  two options: proceed with the component ungrouped, or the user creates the
  group in the Storyblok UI and a follow-up run assigns it. Never silently drop
  the grouping or invent a group.

### 5. Confirm — once

Ask for explicit confirmation of the whole plan. Do not execute any mutating
operation before the user approves. One approval covers the whole batch; do not
re-ask per component. If the plan contains any deletions, name them explicitly
in the confirmation ask (e.g. "this will also delete component X and datasource
Y — proceed?") — a generic "proceed?" is not sufficient confirmation for
destructive steps. If the user pre-approved up front (e.g. a non-interactive
run), the plan presentation in step 4 is still mandatory — write the plan out,
then execute immediately. Pre-approval skips the wait, never the plan.

### 6. Execute the batch

Take the fork from the mode settled in the inputs: 6a writes through the space,
6b writes the repo's schema. The ripple facts below apply to both.

#### 6a. Space mode

Order matters — create things before anything that references them:

1. **Component groups** — cannot be created via this MCP server. Only assign
   components to **existing** groups, using the `uuid` values captured from the
   step 2 audit's `component_groups[]`. Pass that UUID as `component_group_uuid`
   when creating or updating a component in step 6.3 or 6.4. Do not attempt a
   create-group call — there is no such operation.
2. **Datasources + entries** — `createDatasource`, then one
   `createDatasourceEntry` **per entry** (there is no batch/plural variant),
   each carrying the `datasource_id` from the create response. The payloads, the
   `position` ordering, and how an `option` field is wired to the slug are in
   `storyblok-use-mcp`'s datasources reference; `describe` them if that skill is
   not available.
3. **New components, children before the parents that whitelist them** —
   `createComponent` with
   `parameters: { space_id: <id>, component: { name, display_name, is_root, is_nestable, component_group_uuid, schema } }`.
4. **Updates to existing components last** — `updateComponent` with
   `parameters: { space_id: <id>, id: <numeric id>, component: { ... } }`. The
   `id` must be **numeric** — unlike `getComponent`, passing the component
   _name_ here returns `404 Not Found` (verified live); take the numeric id from
   the step 2 audit (`components.id`) or the `getComponent` response.
   **Read-modify-write, always:** `component.schema` is a **full replace, not a
   merge** — confirmed against the live server. Fetch the current schema with
   `getComponent` first, merge your additions into it client-side, and send the
   **complete merged schema**. Sending a partial schema silently deletes every
   field you left out — this is the most damaging mistake this skill can make.
   When the approved plan renames the component itself, add
   `update_content: true` to the parameters so existing stories'
   `"component": "<old_name>"` references are rewritten to the new name —
   without it they keep pointing at the old name. This is the one call in this
   skill that modifies story content, so it runs only as part of an explicitly
   approved rename.
5. **Deletions last, only the ones named in the confirmed plan** — run through
   `mcp__storyblok__execute_destructive`, never before every prior step in the
   batch has succeeded. Each takes only `space_id` and `id`, no request body:
   - `deleteComponent`, `parameters: { space_id: <id>, id: <numeric id> }`.
   - `deleteDatasource`, `parameters: { space_id: <id>, id: <numeric id> }`.
   - `deleteDatasourceEntry`,
     `parameters: { space_id: <id>, id: <numeric entry id> }`. Removing a single
     schema _field_ is **not** a delete operation on this server — do it via
     `updateComponent`'s full-schema replace (substep 4), sending the schema
     with that field omitted; still list it as a deletion in the plan (step 4)
     since it destroys data the same way.

#### 6b. Code mode

Read `resources/schema-as-code.md` — it carries the `define*` helpers, the three
places the DSL differs from the API, and the file layout. In short:

1. Write the blocks, datasources and folders.
2. `schema validate`.
3. `schema push --dry-run` for the diff.
4. Push once confirmed. `--delete` only for removals the confirmed plan named
   individually.

#### Schema changes ripple into existing stories

Schema and story content are decoupled in Storyblok — editing a component's
schema does not transform data already stored in stories:

- **Renaming a field** leaves the old key's value in place under the old key;
  nothing copies it to the new key, and un-resaved stories keep serving the old
  key via the Delivery API.
- **Changing a field's type** does not reshape existing values — the old data
  survives under the new type and can break rendering/editing. Add a new field
  and migrate content into it; never flip `type` in place on a populated field.
- **Renaming a component** leaves existing blocks holding
  `"component": "<old_name>"` in their story JSON — unless the rename's
  `updateComponent` call passes `update_content: true`, which rewrites those
  references in existing stories (the only story-touching parameter this skill
  ever uses, and only for an approved rename). Field-level renames have **no**
  equivalent parameter.
- **Deleting a field** does not delete its data — the value lingers in the
  story's stored content indefinitely, invisible in the editor but still in the
  JSON, until explicitly cleaned up.
- **Deleting a component** leaves every existing story block with
  `"component": "<deleted_name>"` unable to resolve — those blocks stop
  rendering (broken, not silently skipped) wherever they're nested. Unlike a
  rename, there is no `update_content`-equivalent option on `deleteComponent` to
  rewrite or clean up the orphaned references first; the plan must call this
  consequence out explicitly before the user confirms.
- **Tightening a `bloks` whitelist** does not remove or unnest blocks already
  placed there that are no longer allowed — only new inserts are blocked.
- **Adding fields, or making a field required, is safe** — additive fields stay
  inert until a story is resaved, and `required` is validation-only at the next
  save.

**Mitigation for genuinely-needed renames or type changes:** the Storyblok CLI's
migrations (`storyblok migrations generate` / `migrations run`, both
`--space <id>`, with `--dry-run` to preview) transform existing story content to
match the new schema; the mechanics are in `storyblok-use-cli`. This skill still
never deletes anything. When a request is content-affecting: propose the
additive alternative first (new field alongside the old one); if the user
insists on the rename or type change anyway, execute it only after they
explicitly acknowledge the warning above, and point them at the CLI migration
path for moving the content over.

### 7. Verify and report

Confirm the writes landed — re-run `listManagementComponents` in space mode, or
read the push output in code mode. Report what now exists: every component
created or changed with its fields, plus groups (assigned, or flagged as pending
manual creation) and datasources — and the reuse decisions: which existing
components were reused, extended, or deliberately left alone, and why. Suggest
creating a sample story next to test the model in the editor. If anything
failed, say exactly what was and was not created — never claim a partial batch
fully succeeded.

## Field types reference

Common keys usable on any field: `pos` (order, integer), `required`,
`translatable`, `display_name`, `default_value`, `description`.

| Type         | Purpose / distinguishing keys                                                                                                                                           |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `text`       | single-line string; `max_length`                                                                                                                                        |
| `textarea`   | multi-line plain text                                                                                                                                                   |
| `richtext`   | structured rich text (doc tree)                                                                                                                                         |
| `markdown`   | markdown string; `rich_markdown` toggles the visual editor                                                                                                              |
| `number`     | numeric string; `min_value`, `max_value`                                                                                                                                |
| `datetime`   | ISO datetime; `disable_time` for date-only                                                                                                                              |
| `boolean`    | true/false toggle                                                                                                                                                       |
| `option`     | single choice; `source`: inline `options: [{name, value}]`, `internal` + `datasource_slug`, `internal_stories` + `filter_content_type` (story reference), or `external` |
| `options`    | multi choice; same `source` values as `option`; with `internal_stories` it is a multi-story reference                                                                   |
| `asset`      | single file; `filetypes: ["images"]` (or `videos`, `audios`, `texts`)                                                                                                   |
| `multiasset` | multiple files; `filetypes` as above                                                                                                                                    |
| `multilink`  | internal/external link; `restrict_content_types` + `component_whitelist` to limit link targets                                                                          |
| `bloks`      | nested blocks; `restrict_components: true` + `component_whitelist: ["name", …]` (or `restrict_type: "groups"` + `component_group_whitelist`)                            |
| `table`      | simple table editor                                                                                                                                                     |
| `section`    | visual grouping of fields in the editor form (`keys: [...]`)                                                                                                            |
| `custom`     | field plugin; `field_type` names the plugin                                                                                                                             |

Component-kind flags on the component itself: `is_root: true` → content type
(can be a story), `is_nestable: true` → block (can sit in a `bloks` field); both
true → usable as either.
