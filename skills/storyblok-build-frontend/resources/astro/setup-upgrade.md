# Upgrading an existing Astro project

The project already exists and has no `@storyblok/*` dependency. Add Storyblok
to it.

**The existing project is the constraint.** Its components, routes, styles and
config are the user's work. Read them, extend them, and leave every file you do
not have a specific reason to change exactly as it is. Section 3 is where the
reasons are decided — a page whose content now lives in Storyblok is upgraded in
place; everything else is added beside what is there.

## 1. Install

Follow the install step in the official guide:
https://www.storyblok.com/docs/guides/astro.md. Then read the installed version
out of `package.json`: from here on it is the authority, as `mechanics.md`
section 1 requires.

## 2. Register the integration

Add `storyblok()` to `integrations` in the project's existing Astro config,
keeping every integration already listed. The guide's own configuration snippet
is the shape to follow, including how it reads the token with vite's `loadEnv` —
`import.meta.env` alone does not carry `.env` values at config-evaluation time,
so reaching for `process.env` or `import.meta.env` here bakes an undefined token
into the build and every content request fails at runtime.

The token is a delivery token — space-scoped and read-only. Name the environment
variable in the final report so the user can set it — use the project's own
convention, or `STORYBLOK_DELIVERY_API_TOKEN` where it has none — and add the
key, with no value, to `.env.example` if the project has one.

Start `components` empty; it is filled in as blocks are implemented.

Any option beyond `accessToken` and `components` must be confirmed against the
installed package's exported types before you add it. Region, bridge and API
options have all changed shape across major versions, and a wrong option name
fails at runtime rather than at build.

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
must not change: the page's own look is the specification, and the diff should
read as "content now comes from Storyblok", nothing more.

**The story has no counterpart on the site** — additional content that happens
to live in the same space. Add a route for it and change nothing that already
works:

- one story → `src/pages/<slug>.astro`
- everything in the space → a catch-all `src/pages/[...slug].astro`

One rule holds in both cases:

- **Never lose functionality.** If a story covers only part of a page, keep the
  rest of that page and drive the covered part from Storyblok — a page mixing
  both sources is a far better outcome than a page that silently lost a section.
  Say so in the final report.

If a story genuinely could go either way, do the additive thing — a page added
by mistake is deleted in seconds, a page overwritten by mistake is gone — and
name the ambiguity in the final report.

Read the loader symbol from the installed package's exported types rather than
recalling it — the name and its return shape differ between major versions. The
route fetches the story, then renders `story.content` through the SDK's dynamic
block component — confirm that component's name and its props from the installed
package's exported types before writing the call. The blocks it resolves to are
the ones `mechanics.md` governs.

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

With the SDK installed and the integration registered, the project is in the
same state as a scaffolded one. Continue with `mechanics.md`, and write the
components.
