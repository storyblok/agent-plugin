# Astro

The official guide is https://www.storyblok.com/docs/guides/astro.md.

## 1. The installed SDK is the authority

The guide may pin an older `@storyblok/astro` than the project runs, and not
every symbol it documents survives into the installed major. Where guide, memory
and installed package disagree, the installed package wins.

## 2. Where components go

Read the `components` map in `astro.config.mjs`:

- Existing entries: put new files beside the files they reference. Following the
  placement the project already uses matters; the particular folder does not.
- Empty map and no existing block files: `src/storyblok/` is a sensible default.
- Map values are paths relative to `src/`, without `.astro`.
- Example: `hero: 'storyblok/Hero'` resolves to `src/storyblok/Hero.astro`.
- Whatever you choose, the map entry and the file on disk must agree exactly,
  including casing — a case-insensitive filesystem will resolve a mismatch
  locally and then fail wherever the project is actually deployed.
- Match the project's file-name casing.

## 3. Every block root needs to be editable

Import from `@storyblok/astro` and spread `storyblokEditable(blok)` onto the
component's root element. Without it the Visual Editor cannot select the block.

## 4. Field resolution

Link and image fields, as a fenced `astro` block:

```astro
---
// Link fields
const href =
  blok.link?.linktype === 'url'
    ? blok.link.url
    : blok.link?.cached_url
      ? `/${blok.link.cached_url}`
      : '#';

// Image fields
const imageUrl = blok.image?.filename;   // alt text: blok.image?.alt
---
```

## 5. Passing parent context to a child block

`StoryblokComponent.astro` forwards any extra prop — its `Props` interface
declares `[prop: string]: unknown`, it destructures
`const { blok, ...props } = Astro.props`, and it renders
`<Component blok={blok} {...props} />` (verified in `@storyblok/astro` 9.0.0).

```astro
{blok.steps?.map((step, index) => (
  <StoryblokComponent blok={step} index={index} />
))}
```

The child reads it alongside its blok:
`const { blok, index = 0 } = Astro.props`.

Keep template expressions plain JavaScript. Astro documents the frontmatter as
JavaScript or TypeScript, but the template as JSX-like JavaScript expressions —
so a type annotation there (`(nestedBlok: any) =>`) is outside what the docs
guarantee. `astro check` (§10) requires the array hoisted into a typed
frontmatter const:

```astro
---
const panels: any[] = blok.panels ?? [];
---
{panels.map((panel) => <StoryblokComponent blok={panel} />)}
```

## 6. Conventions

- Render a `richtext` field with `renderRichText` from `@storyblok/astro`, then
  `set:html`. Do not reach for `richTextToHTML`.
- Import `StoryblokComponent` only when rendering a `bloks` field.
- Use exact field names verified during modeling.
- Adapt reference code: `className` → `class`, props → `blok`, JSX control flow
  → Astro template expressions, and remove unneeded event handlers.

## 7. When there is no installed SDK to read

Only in that case — a project that does not exist yet, or one whose install has
not run — fall back to the official guide. Dispatch one subagent (cheap model)
with a prompt that asks for verbatim snippets rather than prose:

> Read https://www.storyblok.com/docs/guides/astro.md and return, as verbatim
> code snippets with no commentary: (a) the `components` map in
> `astro.config.mjs` and its key/value convention, (b) a block component showing
> how `blok` reaches the component, (c) how a nested `bloks` array is rendered,
> (d) the `@storyblok/astro` version the guide states it was tested against.

Treat what comes back as shape, not as literal code. The moment an install
exists, its `package.json` and its `node_modules` supersede everything the guide
said.

## 8. Styling

Read `../styling.md` and follow it.

## 9. Registration

Every block must be listed in the `components` map of the `storyblok()`
integration in `astro.config.mjs`, or Storyblok cannot resolve it at render
time:

```js
components: {
  // ...existing entries...
  component_name: 'storyblok/ComponentName',
},
```

The **key** is the Storyblok block name (snake_case, exactly as created), the
**value** is the component's path relative to `src/`, without the extension.
Register child blocks too, not just the parent. If an entry already exists for
that name, leave it alone.

## 10. Type-checking

`astro build` does not type-check templates, so it cannot catch a `blok.<field>`
that the schema has no field for. `astro check` does, but on a project without
`@astrojs/check` it stops at a yes/no prompt and waits. Install the two packages
yourself and the prompt never appears:

```bash
npm install --save-dev @astrojs/check typescript
npx astro check
```

It reports on the whole project, so it also flags files the project already
shipped. Fix those too and say so in the report.
