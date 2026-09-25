---
name: storyblok-build-frontend
description:
  Use when generating frontend components for Storyblok blocks — writing,
  registering and validating the framework code that renders a space's content.
  E.g. "generate components for my blocks", "build an Astro + Storyblok landing
  page".
---

# Build a Storyblok frontend

Write the frontend code that renders a Storyblok space's blocks: one component
per block, registered with the framework's Storyblok integration, styled with
the project's own mechanism, and validated against a build and a rendered page.

## Inputs to collect

**Which blocks to implement** — all of them, or a named subset.

**Load `storyblok-use-storyblok` before the first Storyblok call.** It covers
whether the MCP server or the CLI fits the job, names the skill carrying that
tool's mechanics, and resolves the space and region.

## Where to start

If the project is already detected, start at step 2 and use what is in hand —
verified block field names, a section inventory in design order, design values,
code-owned chrome, asset filenames, a story slug — re-deriving only what is
missing and never re-modeling an existing schema; otherwise start at step 1.

## Workflow

Do not finish with a step unaccounted for; if you skip one, say so and why.

```
- [ ] 1. Detect the project
- [ ] 2. Establish the schema
- [ ] 3. Load the setup and mechanics resources
- [ ] 4. Generate the components
- [ ] 5. Register the blocks
- [ ] 6. Validate
- [ ] 7. Report
```

### 1. Detect the project

Detect, do not assume. Inspect these in one pass:

- **Project state** — first, is there a project here at all? A `package.json` in
  the working directory or an obvious app root decides it. This is the one
  detection that changes what every later step does:

  | State           | Condition                               |
  | --------------- | --------------------------------------- |
  | **new project** | no project in the working directory     |
  | **upgrade**     | a project exists, no `@storyblok/*` SDK |
  | **extend**      | a project with the SDK already wired    |

  Say which state you found before you act on it. In the **new project** state
  the remaining bullets have nothing to read yet: take the framework from the
  request, skip to step 2, and let step 3's setup resource create the project.

- **Framework** — read `package.json` `dependencies`/`devDependencies`. The
  Storyblok SDK in there names the framework directly (`@storyblok/astro`,
  `@storyblok/nuxt`, `@storyblok/react`, `@storyblok/vue`, `@storyblok/svelte`,
  …). With no Storyblok SDK, take the framework from its own package (`astro`,
  `nuxt`, `next`, …) — that is the **upgrade** state, and step 3 loads the
  resource that wires the SDK in.
- **Where blocks live and how they are registered** — find the file that
  registers Storyblok components (grep the repo for the SDK package name; it is
  usually the framework config, a plugin/module file, or a single
  `components: { … }` map) and read the existing entries. Their values point at
  the folder new components belong in. If no registration exists yet, grep for
  the SDK's component-rendering symbol (e.g. `StoryblokComponent`) to find how
  blocks are resolved.
- **Existing blocks** — list the component files already in that folder. Any of
  them matching a block you are about to implement is a reuse candidate, not
  something to recreate.
- **Styling** — open two or three of those existing components and note how they
  style: scoped style blocks, utility classes, CSS modules, a shared stylesheet,
  design tokens as custom properties. Whatever they do is what you do. Never
  introduce a new styling mechanism.
- **Space** — the Storyblok integration's options in the framework config carry
  the space id.

Ask only for missing information. Prefer one combined repository search/read
over separate calls for each item.

This step is repository-only.

### 2. Establish the schema

Never write a component file against a field you have not seen in the schema.
Read what the space contains with one `listManagementComponents` call, then the
fields of each component you are implementing with `getComponent`. Both calls
and their projections are in `storyblok-use-mcp`'s components reference.

Two things are this skill's own: leave `components.schema` out of the list
projection — you implement a subset, and a mature space's full schema floods
context — and take each `getComponent` id from the list rather than the name,
since by-name lookups 404 on some operations.

Then, depending on what you find:

- **The blocks are already modeled and their field names verified** — carry
  those names as read from the schema. Confirm from the component list you just
  read that each block exists, and code against the names as they stand. Do not
  re-model, and do not re-propose a model already executed. A `getComponent` per
  block is worth its cost only when something looks stale — a block name missing
  from the list, or a field the design needs that the model never mentioned.
  Report any block that is missing rather than coding around it.
- **Blocks the work needs are missing** — load `storyblok-model-content` and
  apply its instructions to create or extend them, then re-read the components
  with the same call so you code against the schema that now exists.

### 3. Load the setup and mechanics resources

Load **exactly one** setup resource, per the project state from step 1, and
follow it:

- **new project** → `resources/setup-new-project.md`
- **upgrade**, Astro → `resources/astro/setup-upgrade.md`
- **upgrade**, any other framework → `resources/generic/setup-upgrade.md`
- **extend** → none; the project is already wired

Then load **exactly one** mechanics resource, and follow it before writing any
component:

- Astro → `resources/astro/mechanics.md`
- every other framework → `resources/generic/mechanics.md`

Never load more than one framework folder. The mechanics resource is the entry
point for that framework's mechanics, including any documentation it tells you
to fetch — and it will tell you to read the installed SDK first. Do not
substitute your own recollection of a framework's Storyblok integration for it.

### 4. Generate the components

Follow the resources loaded in step 3.

- Create one component per block.
- Use an existing component as the first syntax source.
- If project code leaves a question, inspect the installed SDK before the loaded
  resource — the installed package outranks anything a resource asserts; ask
  only when all three fail.
- Never match, split, or branch on a field's copy. A component that regexes a
  heading to gradient one word or slip an icon in mid-sentence renders the
  design once and breaks on the editor's first rewrite. Word-level styling
  belongs to the editor: style a class the field's `style_options` declares —
  add it to the field when it is missing — and keep decoration in the
  component's own CSS, positioned relative to the element rather than inserted
  into the text.
- Plan children before parents, then write independent files in batches.
- Implement any code-owned chrome list in the layout or page shell, never as a
  Storyblok block. Placeholder chrome the project already ships — a bare
  `<footer>` carrying a copyright line, or no header at all — is not the
  design's chrome; replace it.

### 5. Register the blocks

Follow the loaded framework resource. Register every new parent and child block
exactly once under its exact Storyblok name. Skip existing entries.

### 6. Validate

Run each check once. Re-run one only after fixing what it reported. Report any
check you skip, with its reason.

- [ ] **Build** — the project's own build and type-check commands, both of them.
- [ ] **Fields** — every `blok.<field>` in generated code exists in the schema
      verified in step 2.
- [ ] **Chrome** — the header, navigation and footer render the design's chrome
      copy from code.
- [ ] **Colour tokens** — scan the generated component files with the command in
      `resources/styling.md` and resolve every hit as that resource requires. If
      no generated component authored any styles at all, this check did not run:
      report it as not applicable, never as passed.
- [ ] **Rendered page** — when a story exists for these blocks — created by you
      or already in the space — serve the project, screenshot that story's
      route, and compare it against the design; when no story exists, skip this
      check and say so in the report instead of screenshotting an unrelated or
      empty page.

Stage every file this step writes inside the project workspace. Never write
scratch work to `/tmp`: those paths are shared between runs, and adopting
another run's leftovers is how a working install turns into a corrupt one.

Start the server in the background, then read its own startup output for the URL
it actually bound to. Never assume a port: a sibling run, or a server the user
already has open, may already hold the framework's default, and polling a
hardcoded port can silently validate someone else's app instead of failing.

```bash
npm run dev > dev.log 2>&1 &
dev_pid=$!

url=""
for i in $(seq 1 40); do
  url=$(grep -oE 'https?://(localhost|127\.0\.0\.1)[^[:space:]]*' dev.log | head -1)
  [ -n "$url" ] && curl -sf "$url" >/dev/null 2>&1 && break
  sleep 1
done
```

If `url` is still empty once the loop ends, report that the dev server never
came up (include the tail of `dev.log`) and skip the rendered-page check. When a
story exists, append its slug to `url` before screenshotting.

For the screenshot, use a script or dependency the project already has, or a
browser MCP tool. With neither, take it with one command:

```bash
npx --yes playwright screenshot --full-page "$url" shot.png
```

If it reports the browser executable is missing, run
`npx --yes playwright install chromium` once and repeat the command. Its warning
banner about the project's dependencies is not an error. Add
`--wait-for-timeout=3000` once if images are still loading. If the screenshot
still fails, report the rendered-page comparison as skipped and continue.

Stop the server with the PID this step started (`kill "$dev_pid" 2>/dev/null`),
never by port, and delete `dev.log`, the screenshot, and any asset manifest.

### 7. Report

Report differences instead of quietly diverging. Then report: the blocks covered
and their fields; existing fields reused; files written; registration changes;
new colour tokens, and any colour literal deliberately left local; every check
skipped, with its reason.

## Resources

- `resources/setup-new-project.md` — load when no project exists yet;
  framework-agnostic.
- `resources/astro/mechanics.md` — load when the target project uses Astro.
- `resources/astro/setup-upgrade.md` — load to add Storyblok to an existing
  Astro project.
- `resources/generic/mechanics.md` — load for every non-Astro framework.
- `resources/generic/setup-upgrade.md` — load to add Storyblok to an existing
  non-Astro project.
- `resources/styling.md` — load before writing any component styles.
