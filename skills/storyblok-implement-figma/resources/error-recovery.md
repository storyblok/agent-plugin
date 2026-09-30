# Error recovery

MCP-side failures — a rejected operation, an unknown parameter,
`requiresRegion`, "No such tool available", an unauthenticated server — are
`storyblok-use-mcp`'s error recovery. Follow it. What follows is specific to
reading Figma and to the asset scripts.

- **Node ID rejected** — percent-decode the `node-id` from the URL. Hyphens and
  colons are both accepted; `%3A` and `%3B` are not.
- **No token on stdin** — ask the user which environment variable or
  secret-manager command holds their personal access token, then pipe it in.
  Never ask them to paste its value into chat.
- **Other asset authentication failure** — check `STORYBLOK_SPACE_ID` and
  optional `STORYBLOK_REGION`. Never print credentials.
- **Unsupported asset MIME** — export the source as SVG, PNG, JPEG, GIF, WebP,
  or AVIF.
- **Broken uploaded image** — re-run from the original Figma URL; do not reuse a
  file whose extension did not match its bytes.
- **Block name conflict** — reuse or extend the existing block by following
  `storyblok-model-content`; do not create a near-duplicate.
