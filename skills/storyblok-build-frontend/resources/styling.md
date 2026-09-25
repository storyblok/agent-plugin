# Styling

Use the project's existing mechanism — scoped styles, utilities, CSS modules, a
shared stylesheet, or custom properties — decided by opening two or three
components already registered in the project; never introduce a second styling
system. Read the global stylesheet the project already loads, too: its broad
selectors — a bare `article`, a generic `.feature` — are what your component's
class names have to clear. Values (type scale, colours, spacing, radii,
breakpoints) come from the design when there is one, and otherwise from the
project's existing tokens.

## Colours: map to tokens before writing any component

Do this once, before the first component style block:

1. Inventory the design's colours — including translucent values, shadow
   colours, and every gradient stop.
2. Map each one to an existing project token whose value **and** semantic role
   match.
3. For each unmatched colour that is reused or meaningful, define one custom
   property in the project's existing token layer (the global stylesheet or
   `:root` block the project already has).
4. Reference the tokens from components.

Tokens come in two layers, and only the second is for components:

```css
/* Palette layer — hue names are correct here. */
--color-purple-500: #8d60ff;
/* Semantic layer — names the role, points at the palette. */
--color-accent-primary: var(--color-purple-500);
```

```css
/* In a component: only ever the semantic layer. */
background: var(--color-accent-primary);
```

A component that references a palette token directly, or inlines the hex the
palette token already holds, defeats a re-theme just as surely as a raw literal
does. Colour literals — hex, `rgb()`, `hsl()`, named colours — belong in the
palette layer only, never in a generated component's styles. The exception is a
value that is genuinely local and cannot be reused; say so in the final report
rather than leaving it unexplained.

## Verifying it

Scan every generated component file:

```bash
rg -n -i --pcre2 '#[0-9a-f]{3,8}\b|\b(?:rgba?|hsla?)\(|(?<![-\w])(?:white|black|red|blue|green|yellow|orange|teal|purple|gr[ae]y)(?![-\w])' <generated-component-paths>
```

The pattern uses look-behind, so it runs through Bash with `--pcre2`; the Grep
tool rejects it.

Alpha colours and named colours count. Ignore inline SVG markup, the token
definitions themselves, and colour words inside `var(--token-name)`. Every
remaining hit is either moved into the palette layer — and referenced from the
generated component through a semantic token, never the palette token directly —
or named in the final report; an unnamed hit is a failure, not a note.
