# Datasources

A datasource is a named list of key/value entries that option fields draw their
choices from. Reach for one when the choices are editor-maintained or shared by
more than one component; two or three static values in a single field can stay
inline as `options`.

## Check what exists

```json
{
  "operation": "listDatasources",
  "parameters": { "space_id": 12345 },
  "fields": ["datasources.id", "datasources.name", "datasources.slug"]
}
```

Entries of one datasource:

```json
{
  "operation": "listDatasourceEntries",
  "parameters": { "space_id": 12345, "datasource_id": 205821908987633 },
  "fields": [
    "datasource_entries.id",
    "datasource_entries.name",
    "datasource_entries.value"
  ]
}
```

## Create a datasource and its entries

`createDatasource` on `mcp__storyblok__execute_mutating`:

```json
{
  "operation": "createDatasource",
  "parameters": {
    "space_id": 12345,
    "datasource": { "name": "Brands", "slug": "brands" }
  }
}
```

The response carries the numeric `id`. Then **one call per entry** — there is no
bulk variant:

```json
{
  "operation": "createDatasourceEntry",
  "parameters": {
    "space_id": 12345,
    "datasource_entry": {
      "datasource_id": 205821908987633,
      "name": "Shimano",
      "value": "shimano",
      "position": 0
    }
  }
}
```

- `name` is what editors see; `value` is what gets stored in content. Slugified
  lowercase values are the convention.
- Pass an explicit `position` (0, 1, 2 …) to keep the order the user gave you.

## Wiring a field to it

An option field reads a datasource by **slug**, in the component's schema:

```json
"brand": {
  "type": "option",
  "source": "internal",
  "datasource_slug": "brands"
}
```

Use `"type": "options"` for multi-select. Changing a field's schema is a
full-schema `updateComponent` — see `components.md`.

## Storing a value in a story

The story's field holds the entry's **`value`** string, not its display name:

```json
{ "component": "page", "brand": "shimano" }
```

For a multi-select `options` field it is an array of value strings. When the
user names the label ("set it to Shimano"), map the label to its value before
writing.

Delete with `deleteDatasource` and `deleteDatasourceEntry`. Content already
storing a deleted entry's value keeps it; the field just no longer offers it.
