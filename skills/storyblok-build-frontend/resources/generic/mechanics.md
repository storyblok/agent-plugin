# Non-Astro frameworks

The official guide for the detected framework is
`https://www.storyblok.com/docs/guides/<slug>.md`:

| Framework          | Guide slug |
| ------------------ | ---------- |
| Nuxt               | `nuxt`     |
| Next.js            | `nextjs`   |
| React              | `react`    |
| Vue                | `vue`      |
| Svelte / SvelteKit | `svelte`   |

## 1. The installed SDK is the authority

Coverage across those guides is uneven and their versions lag: one may pin an
older SDK major than the project runs, and one may show an editable helper where
another shows none. Where a guide, your recollection and the installed package
disagree, the installed package wins.

## 2. Take these from the project and the installed SDK

For whichever of these the project does not already answer, take it from an
existing block component first, then the installed SDK's README and exported
types, and only ask when both fail:

- the **editable helper or directive**, on every block component's root element
  — never guess the symbol or syntax;
- **nested bloks** — every `bloks` array renders through the SDK's dynamic block
  component; never hardcode child selection in the parent;
- **field resolution** — asset URL from `.filename` and alt from `.alt`;
  external links from `.url`, internal Storyblok links from `.cached_url`;
- **registration** — every new parent and child exactly once, keyed by the exact
  Storyblok block name, following existing entries and paths; skip names already
  registered; treat an empty map as the registration point.

## 3. When there is no installed SDK to read

Only then fall back to the official guide. Build its URL from the table above
and dispatch one subagent (cheap model) with a prompt that asks for verbatim
snippets rather than prose: the registration point and its convention, a block
component showing how the `blok` prop arrives, how a nested `bloks` array is
rendered, the editable helper or directive **if the guide shows one**, and the
SDK version the guide states it was tested against.

If the framework is not in the table there is no guide to fetch: take everything
from section 2 instead. Either way, the moment an install exists it supersedes
whatever the guide said.

## 4. Adapting reference code

Adapt the reference code to the project's framework:

- replace React-only syntax with native template syntax;
- replace reference props with verified Storyblok fields;
- remove event handlers that do not belong in static rendering;
- preserve the design structure and tokens.

## 5. Styling

Read `../styling.md` and follow it.
