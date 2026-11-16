---
name: storyblok-build-plugin
description:
  Use when extending Storyblok with plugins to enhance what editors can do —
  custom field inputs, Visual Editor panels, pages inside a space, integrations
  with external systems — including choosing, building, or deploying one. E.g.
  "editors need a map location picker", "build a field plugin", "deploy our
  plugin".
---

# Extend Storyblok with a plugin

Decide what to use before building anything: a built-in field, an existing app,
or one of three plugin types. Build only what neither covers, with the official
tooling.

**Load `storyblok-use-storyblok` first, even when no Storyblok call is planned**
— its token rules decide the deploy hand-over in §4. Deciding what to use needs
no space; do not ask for one before the answer depends on it.

## 1. Don't build what already exists

Before building anything, check both, in this order:

1. **Built-in field features.** Fixed choices (single/multi-option, datasource),
   references, conditional fields (show, hide, or require a field based on
   another), maximum characters, regex validation, asset file-type limits.
   Reference: https://www.storyblok.com/docs/concepts/fields.md.
2. **Apps.** Run `curl -s https://www.storyblok.com/docs/apps.md` and read the
   whole output; it is short and grouped by category.

Before recommending an app, read its page
(`curl -s https://www.storyblok.com/docs/apps/<app>.md`) so setup details are
facts, not guesses. If an app comes close but falls short, say which and why.
When the user asked to build a specific plugin and something already covers it,
say so.

## 2. Pick the plugin type

Decide by where it runs and what it can reach:

| Type         | Runs                                            | Reaches                                                | Use for                                                        |
| ------------ | ----------------------------------------------- | ------------------------------------------------------ | -------------------------------------------------------------- |
| Field plugin | inside one field of a block, in the editor form | its own value and options; reads the open story        | custom inputs: pickers, external references, structured values |
| Tool plugin  | a panel in the Visual Editor, beside the story  | the story being edited, live; Management API via OAuth | per-story helpers while editing: analysis, checks, actions     |
| Space plugin | a full page in the space's sidebar              | the whole space via the Management API (OAuth)         | space-wide views: dashboards, reports, bulk work               |

- Stores a value on a block → field plugin. It can read the open story but
  writes only its own value, sees no other stories, and is the wrong place for a
  story-wide view.
- About the story open in the editor → tool plugin. Editor-only UI belongs in
  the editor, not in the site's frontend: a preview overlay is coupled to one
  frontend and exists only where that frontend runs.
- Across many stories, or beyond stories (datasources, assets) → space plugin,
  never a tool plugin: a tool plugin lives inside one open story.
- Two types fit (per story while editing vs. a space-wide overview): name the
  question that decides it and recommend one.

Field plugins: any user can build and deploy them; Storyblok hosts the bundle.
Tool and space plugins: self-hosted apps, registered by a user with Partner
Portal or Organization access, authenticated with OAuth via
`@storyblok/app-extension-auth`, and a premium feature. Docs:
https://www.storyblok.com/docs/plugins.md.

## 3. Build a field plugin

1. **Scaffold with the CLI, never by hand.** The template produces the single
   bundle Storyblok loads (`dist/index.js`), mounts into an element it creates
   (the editor's document is empty — there is no `index.html` in production),
   and wires the SDK. Run it non-interactively:

   ```
   npx @storyblok/field-plugin-cli@latest create --dir . --pluginName <name> \
     --template <vue3|react|js> --structure standalone --packageManager npm
   ```

   It creates `./<name>/`. Replace `src/components/FieldPluginExample/`
   (component, CSS, test) with your own and point `App` at it. Keep `main`,
   `vite.config`, `tsconfig*`, `index.html`, and `field-plugin.config.json`. The
   template's `main` ends by throwing an error on purpose (legacy API); leave
   it.

   For a modal that browses or searches an external catalog (e-commerce, DAM,
   PIM), start from
   https://github.com/storyblok/pluginsblok/tree/main/apps/field-plugins/picker-starter
   instead.

2. **Implement with the SDK**: `useFieldPlugin` (Vue 3, React) or
   `createFieldPlugin` (js). Render only when `type === 'loaded'`. Read the
   stored value from `data.content`, normalize it in `validateContent`, save
   with `actions.setContent(value)`. Options arrive as strings in
   `data.options`. `validateContent` never sees them, so derive any default that
   depends on an option (e.g. a preselected choice) from `data.options`, and a
   new, empty field must offer only what the options allow.

   What else the SDK offers, and when to use it:
   - Big UI (image grid, map, media browser — not a list of a few items): a
     compact summary inline, the full UI in the modal —
     `enablePortalModal: true`, `actions.setModalOpen(true)`, a visible close
     button while `data.isModalOpen`, Escape closes, a pick closes.
   - Assets: `actions.selectAsset()` opens Storyblok's asset picker; no URL
     input.
   - Sibling fields: `data.story` is the story as the editor loaded it, not the
     unsaved one. Read siblings with `actions.requestContext()` on load and
     again when the field regains focus (no event fires on change). It resolves
     to the unsaved story; find this field's block in it by `data.blockUid`.
     Every call gets its own reply: never skip or drop a read, or a click like
     Retry, because one is pending.
   - Story language: `data.storyLang`, `'default'` for the default language.
   - AI: `actions.promptAI` only when `data.isAIEnabled`.

3. **Declare every option** in `field-plugin.config.json`:
   `{ "options": [{ "name": "currencies", "value": "EUR,USD" }] }`. The sandbox
   and the deploy command read it.
4. **Look native to the editor**: follow "Style the field plugin" in
   https://www.storyblok.com/docs/plugins/field-plugins.md.

5. **Test and build**: `npm test && npm run build`; the build must produce
   `dist/index.js`. Write tests like the example spec, with `setupFieldPlugin`
   from `@storyblok/field-plugin/test`. Its container has no options and no
   stored value, so test option and content handling as plain functions.
6. **Rewrite the template README**: each option with its default, and the stored
   value as a JSON example.

SDK and CLI reference: https://www.storyblok.com/docs/plugins/field-plugins.md
and https://www.storyblok.com/docs/libraries/js/field-plugin-sdk.md.

## 4. Deploy is the user's call

Deploying publishes the plugin to an account — personal, partner portal, or
organization — not to a space. Never run it unasked.

Plugin names are unique across Storyblok: pick a personal prefix yourself
(`<prefix>-<name>`, e.g. `acme-price-field`), never the bare package name, and
state the deployed name.

- **Not asked to deploy:** hand over `npm run deploy` (runs
  `field-plugin-cli deploy`); it reads `STORYBLOK_PERSONAL_ACCESS_TOKEN` and
  asks for the scope and name.
- **Asked to deploy**, with a token the user named: test and build, then deploy.
  Never print the token or write it to a file.
- Afterwards, the block needs a plugin field: `type: "custom"`, `field_type` set
  to the deployed name, and `options` with their values. The deployed values
  serve development only: a field gets just the option keys, so each field needs
  its own values. Offer to add the field for them: it changes the schema, so
  confirm first, then follow `storyblok-model-content`.

## 5. Tool and space plugins

Start from the starters in https://github.com/storyblok/pluginsblok
(`apps/space-tool-plugins`), not from scratch. Keep the client id and secret in
environment variables, never in the repo. A tool plugin reads the open story
with `postMessage` (`getContext`). Both types call the Management API with the
OAuth token; App Bridge is an optional extra auth flow, not a data channel.
Docs: https://www.storyblok.com/docs/plugins/tool-plugins.md,
https://www.storyblok.com/docs/plugins/space-plugins.md,
https://www.storyblok.com/docs/plugins/app-bridge.md.
