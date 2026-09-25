# Upgrading an existing non-Astro project

The project already exists and has no `@storyblok/*` dependency. Add Storyblok
to it.

**The existing project is the constraint.** Its components, routes, styles and
config are the user's work. Read them, extend them, and leave every file you do
not have a specific reason to change exactly as it is. Section 3 is where the
reasons are decided — a page whose content now lives in Storyblok is upgraded in
place; everything else is added beside what is there.

## 1. Install the framework's SDK

| Framework          | Package             | Where it registers                      |
| ------------------ | ------------------- | --------------------------------------- |
| Nuxt               | `@storyblok/nuxt`   | `modules` in the Nuxt config            |
| Next.js / React    | `@storyblok/react`  | an app-level init in the root component |
| Vue                | `@storyblok/vue`    | a plugin registered on the app instance |
| Svelte / SvelteKit | `@storyblok/svelte` | an app-level init in the root layout    |

Follow the install step in that framework's official guide, linked from
`mechanics.md`. Then read the installed version out of `package.json`: from here
on it is the authority, as `mechanics.md` section 1 requires.

The "where it registers" column is where to look, not what to write. Confirm the
init function's name, its options and its call site against the installed
package's exported types and README before writing the call — these have all
changed shape across major versions, and a wrong name fails at runtime rather
than at build.

If the framework is not in the table, do not guess a package name.
`@storyblok/js` is the framework-agnostic SDK and is what the framework packages
themselves build on; confirm its exports from the installed package before
writing any call.

## 2. Configure the token from the environment

Every SDK takes a delivery token — space-scoped and read-only. Read it from the
environment using the project's own convention for that, or
`STORYBLOK_DELIVERY_API_TOKEN` where the project has none, and name the variable
in the final report so the user can set it. If the project has a `.env.example`,
add the key there with no value.

## 3. Reconcile the space against the site, story by story

If the request states, or lets you infer, whether the space's stories become new
pages or drive the pages already there, follow that. Otherwise decide per story,
not once for the project, before writing any route.

List the space's stories, read the pages the project already has, and compare
the actual content:

**The story is what an existing page already renders** — same copy, same
purpose, because the text now lives in Storyblok. Upgrade that page in place.
Keep its route, its layout, its markup structure and its styles, and replace
only the hardcoded content with the story's fields. Its URL and its appearance
must not change: the page's own look is the specification.

**The story has no counterpart on the site** — additional content that happens
to live in the same space. Add a route for it and change nothing that already
works: a single route for one story, or the framework's
catch-all/dynamic-segment form for everything in the space. Follow how the
project's existing routes are written; the framework's own convention governs
the file name.

One rule holds in both cases:

- **Never lose functionality.** If a story covers only part of a page, keep the
  rest of that page and drive the covered part from Storyblok — a page mixing
  both sources is a far better outcome than a page that silently lost a section.
  Say so in the final report.

If a story genuinely could go either way, do the additive thing — a page added
by mistake is deleted in seconds, a page overwritten by mistake is gone — and
name the ambiguity in the final report.

The route fetches the story, then renders `story.content` through the SDK's
dynamic block component — confirm that component's name and its props from the
installed package's exported types before writing the call. The blocks it
resolves to are the ones `mechanics.md` governs.

## 4. The existing pages define the look

Match them, asked or not. A Storyblok-driven page that looks like it came from a
different site is a defect even when every field renders. The pages already
there are the design — their spacing scale, their type scale, their colour
usage, their layout components.

So read them before writing any style, and reuse what they use: the project's
layout, its existing components where they fit, and its token layer. The project
probably already defines colour custom properties — map onto those before
defining a single new one, per `../styling.md`, which you should read and
follow. Never introduce a second styling system alongside the project's, and
never restyle an existing page to match a new one — the influence runs the other
way.

## 5. Then generate

With the SDK installed and registered, continue with `mechanics.md`, and write
the components.
