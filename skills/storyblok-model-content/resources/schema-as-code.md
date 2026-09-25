# Schema as code

## Layout

The schema is project source, so it belongs in the project's source root —
`src/schema/` by default, `app/schema/` or whatever the project already uses
instead.

```
src/schema/
  blocks/<folder segments>/<block-name>.ts   one block per file
  fields.ts                                  fields shared across blocks
  datasources.ts
  folders.ts                                 only if the space groups components
  schema.ts                                  the entry file
```

Bootstrapping from an existing space targets the same place:
`storyblok schema init --space <id> --out-dir src/schema`.

Wire the commands into `package.json` so the entry path is written once:

```json
"schema:push": "storyblok schema push src/schema/schema.ts --space <id>",
"schema:validate": "storyblok schema validate src/schema/schema.ts"
```

Drop `--space` from the push script only if `storyblok.config.ts` declares
`space`; without it the command exits asking for the flag. `validate` is offline
and never takes one.

## Blocks

`defineBlock` and `defineField` are typed identity functions returning the DSL,
not the wire format the API takes — the CLI converts on push (field order
becomes `pos`, and so on), so never hand-write wire keys. Fields are an
**ordered array**.

```ts
import { defineBlock, defineField } from '@storyblok/schema'

export const heroBlock = defineBlock({
  name: 'hero',
  is_nestable: true,
  display_name: 'Hero',
  fields: [
    defineField('headline', { type: 'text', max_length: 120, required: true }),
    defineField('image', { type: 'asset', filetypes: ['images'] }),
    defineField('cta_link', { type: 'multilink' }),
  ],
})
```

A content type is `is_root: true`.

A field used by more than one block is defined once in `fields.ts` and imported
— that is how the one-name-per-role rule is enforced here:

```ts
// fields.ts
export const headlineField = defineField('headline', {
  type: 'text',
  max_length: 120,
})
```

### Where the DSL differs from the API

Every key in the skill body's field-types table passes through verbatim, with
four exceptions:

| DSL                            | Wire                                                                                                                    |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| `allow: [heroBlock, 'teaser']` | `component_whitelist` + `restrict_components: true`. Refs or bare names; do not write the wire keys.                    |
| `allow: [marketingFolder]`     | `component_group_whitelist` + `restrict_type: 'groups'`. Folders and blocks cannot be mixed in one `allow` — it throws. |
| `deny: [legacyBlock]`          | `component_denylist` + `restrict_components: true`. Folder refs map to `component_group_denylist`.                      |
| `datasource: colorsDatasource` | `datasource_slug`. The `source: 'internal'` selector is still written explicitly.                                       |

`deny` is the alternative to `allow`, not an addition to it: the editor reads
the denylist only while the allow list is empty, so a field carrying both is
rejected. It governs the block picker rather than the stored content — a denied
block can still be pasted in from the clipboard — so where a block must never
appear, reach for `allow`.

Group membership is a `folder:` ref on the block, not `component_group_uuid`.

## Datasources and folders

```ts
import { defineDatasource, defineFolder } from '@storyblok/schema'

export const colorsDatasource = defineDatasource({
  name: 'Colors',
  slug: 'colors',
})
export const marketingFolder = defineFolder({ name: 'Marketing' })
export const herosFolder = defineFolder({
  name: 'Heros',
  parent: marketingFolder,
})
```

Folder identity is its name path, and `schema push` **creates missing groups**
parent-first. Unlike the MCP path, a needed-but-missing component group is not a
gap to hand back to the user here.

## The entry file

```ts
import { defineSchema } from '@storyblok/schema'
import type {
  BlockContent,
  Schema as InferSchema,
  Story as InferStory,
} from '@storyblok/schema'
import { pageBlock } from './blocks/page'
import { heroBlock } from './blocks/hero'
import { colorsDatasource } from './datasources'

export const schema = defineSchema({
  blocks: { pageBlock, heroBlock },
  datasources: { colorsDatasource },
})

export type Schema = InferSchema<typeof schema>
export type Blocks = Schema['blocks']
export type FieldPlugins = Schema['fieldPlugins']
export type Story = InferStory<Blocks, FieldPlugins>

/** A block component's props, by block name: `Block<'hero'>`. */
export type Block<TName extends Blocks['name']> = BlockContent<
  Extract<Blocks, { name: TName }>,
  Blocks,
  FieldPlugins
>
```

Those inferred types are the project's Storyblok types, and `Block<'hero'>` is
how the frontend components type their props. Never run
`storyblok types generate` in this mode.

Field plugins backing `custom` fields register on the schema too
(`fieldPlugins: { … }`) so their values are typed and validated.

## Pushing

Mechanics and the destructive gates are in `storyblok-use-cli`. The order:

1. `storyblok schema validate src/schema/schema.ts` — offline, catches malformed
   definitions before any network call.
2. `storyblok schema push src/schema/schema.ts --space <id> --dry-run` — show
   the user the diff.
3. Push for real once confirmed. It scaffolds migration files for breaking
   changes; those rewrite story content, so running them needs its own
   confirmation.

Never pass `--delete` unless the confirmed plan named each removal. Without it
the push leaves unknown remote entities alone.

## What code mode does not change

Moving the source of truth into the repo does not change how a schema edit
ripples into existing stories: a rename in code orphans stored data exactly as a
rename through the API does. `schema push` diffs the schema; it does not migrate
content.

## Beyond this page

API reference: <https://www.storyblok.com/docs/libraries/js/schema.md>. Go there
for a field type's exact options, `defineFieldPlugin`, or the validators — none
of which are covered above. One page, one API subsection per helper
(`defineBlock`, `defineField`, `defineFolder`, `defineDatasource`,
`defineFieldPlugin`, `defineSchema`, `Schema`): jump to the helper you need
rather than reading it end to end.
