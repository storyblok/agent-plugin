# Create a story

`storyblok-use-mcp` owns story mechanics: resolving a slug, `createStory` and
its parameters, publishing, and reading a story back. Load it and follow its
stories reference. Only what is specific to implementing a design is here.

- The story's copy is the design's copy. Use the exact block and field names
  verified during modeling — not names read off the design.
- Send only `name`, `slug`, and `content`. Omit `is_startpage`, and omit
  `parent_id` unless the user named a parent.
- A slug that already exists is not yours to reuse. Never overwrite a match
  without direction from the user — a design implementation must not silently
  replace a page.
- Use the asset field values assembled in step 5 for `asset` and `multiasset`
  fields.
- Repeated items go in the design order frozen in step 3, not the order the
  design context happened to list them in.
- Assemble the whole `content` object first and send it in one `createStory`
  call. A story created section by section costs a read-modify-write per section
  and leaves a half-built page behind if the run stops.
- Leave the story unpublished. Offer publishing separately — a design
  implementation is not a decision to go live.
