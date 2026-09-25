# Components (blocks)

Components are the space's schema: content types (`is_root: true`, can be a
story) and nestable blocks (`is_nestable: true`, can sit in a `bloks` field).
"Block" and "component" are the same thing.

Designing or reshaping a model (several components, a brief, a URL, a design) is
the `storyblok-model-content` skill's job: **load it if it is available**.

## Audit before you write content

Look at what the fields actually are — do not guess field names:

```json
{
  "operation": "listManagementComponents",
  "parameters": { "space_id": 12345 },
  "fields": [
    "components.id",
    "components.name",
    "components.display_name",
    "components.is_root",
    "components.is_nestable",
    "components.schema"
  ]
}
```

Include `components.schema` when you are about to write content. One component
on its own is `getComponent` with `parameters: { space_id, id }`. On a large
space, narrow server-side with `search: "<name>"` or `by_ids` rather than
listing everything with schemas.

A `bloks` field tells you what may go inside it:

```json
"body": { "type": "bloks", "restrict_components": true, "component_whitelist": ["article", "banner"] }
```

Judge fit by meaning, not by which component has enough text fields to absorb
the strings. Nothing fits → create the block below, whitelist it in the parent,
put the populated instance in the story, and say so in your report.

## Create a component

`createComponent` on `mcp__storyblok__execute_mutating`:

```json
{
  "operation": "createComponent",
  "parameters": {
    "space_id": 12345,
    "component": {
      "name": "job_posting",
      "display_name": "Job posting",
      "is_nestable": true,
      "is_root": false,
      "schema": {
        "title": { "type": "text", "pos": 0 },
        "location": { "type": "text", "pos": 1 },
        "description": { "type": "richtext", "pos": 2 }
      }
    }
  }
}
```

- `name` is the machine name used in story content
  (`"component": "job_posting"`) — snake_case, matching the space's convention.
- Field `type` values match the ones already in the space's schemas: `text`,
  `textarea`, `richtext`, `asset`, `option`, `bloks` and so on, each taking
  optional `pos`, `required`, `translatable`, `description`.
- Any `bloks` field you create gets `restrict_components: true` plus a
  `component_whitelist`.
- The response carries the new component's numeric `id`.

## Whitelist in parent

1. `getComponent` — `parameters: { space_id, id: <numeric id> }`, no projection.
2. Append your component's name to the target `bloks` field's
   `component_whitelist`, client-side, leaving the rest of the schema alone.
3. `updateComponent`:

```json
{
  "operation": "updateComponent",
  "parameters": {
    "space_id": 12345,
    "id": 205821908987600,
    "component": {
      "name": "page",
      "schema": { "…": "the complete merged schema" }
    }
  }
}
```

- Sending a partial schema deletes every field you left out.
- `id` must be **numeric**, not a component name.

## Changing existing components

Adding a field or widening a whitelist is safe. Everything else — renaming a
field or component, changing a field's type, removing a field, deleting a
component — strands the content already stored in stories: schema changes do not
migrate content. Those belong to `storyblok-model-content`, which carries the
per-change consequences and the migration path.
