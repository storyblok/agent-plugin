---
name: storyblok-use-cli
description:
  Use when driving Storyblok through the Storyblok CLI — code-driven schema,
  content migrations, bulk pull/push of stories, components, assets or
  datasources, or scaffolding a project.
---

# Work with Storyblok through the CLI

## Running it

Resolve the binary once: `node_modules/.bin/storyblok`, else the package
manager's exec (`pnpm exec`, `npx`), else a global `storyblok`. A one-off in a
project that does not depend on it can run through `pnpm dlx storyblok` or
`npx -y storyblok` — no install needed.

Most commands work against one space. Set it once in `storyblok.config.ts`
(`space`) and every command picks it up; otherwise pass `--space <id>` on each.
Offline commands — `schema validate` among them — take no space at all.

Space-to-space is the exception: `push` and `migrations run` read their local
files from `--from <id>` when it is given, and from `--space` otherwise.

Prefer flags over prompts: every unset option a command needs becomes an
interactive question you cannot answer. Add `--verbose` when a command fails.

## Region

Never ask for it. Every command runs against the region of the active session —
`STORYBLOK_REGION`, or `~/.storyblok/credentials.json`, falling back to `eu` —
and neither `--region` nor the config file can retarget it.

Check when a command answers `HTTP 404 ["This record could not be found"]`: a
wrong region says that, and so do a wrong space id and a deleted space, naming
no region either way. `storyblok user` ends with `… on <region> region`; compare
it with the region the space id encodes.

| Space id                  | Region                                                           |
| ------------------------- | ---------------------------------------------------------------- |
| ≥ 2⁴⁸ (`281474976710656`) | bits 48–52: `0`/`1` → eu, `2` → us, `3` → ca, `4` → ap, `6` → cn |
| < 1000000                 | eu (legacy `cn` shares this range)                               |
| < 2000000                 | us                                                               |
| < 3000000                 | ca                                                               |
| < 4000000                 | ap                                                               |

On a mismatch, stop and hand it to the user: `storyblok logout` then
`storyblok login` into that region, or `STORYBLOK_REGION=<region>` with a token
from it. Never attempt the login and never ask for a token.

`--region` only carries where there is no session to override it:
`storyblok create --token <token> --region <region>` writes the region into the
generated project.

## Auth

`storyblok user` reports the session. When it reports one, every command is
already authenticated and there is nothing for you to do.

With no session, ask the user to run `storyblok login` themselves; it is a chain
of interactive prompts ending in a password, an OTP or a pasted token, so you
cannot complete it. Re-check afterwards.

## Schema as code

The only way to manage a space's schema from the repo. Definitions come from
`@storyblok/schema`; `storyblok-model-content` owns how to write them.

| Command                                           | Does                                                                                                                              |
| ------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `schema init --space <id> --out-dir src/schema`   | One-time bootstrap of TypeScript definitions from a space. Refuses a non-empty directory.                                         |
| `schema validate <entry-file>`                    | Static check — offline, no login, no space. Run it before every push.                                                             |
| `schema push <entry-file> --space <id> --dry-run` | The diff. Always this before the real push.                                                                                       |
| `schema push <entry-file> --space <id>`           | Apply. Scaffolds migrations for breaking changes (`--no-migrations` to skip) and writes component JSON (`--no-write-components`). |
| `schema rollback [changeset-file] --space <id>`   | Undo a push from its changeset.                                                                                                   |

## Everything else

| Command                                 | For                                                                                                                           |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `stories pull/push`, `stories validate` | Bulk story content as local files                                                                                             |
| `components pull/push`                  | Component schemas as local JSON, including space-to-space                                                                     |
| `datasources pull/push/delete`          | Datasources and their entries                                                                                                 |
| `assets pull/push`, `assets transfer`   | Bulk assets; `transfer` moves them between spaces                                                                             |
| `migrations generate/run/rollback`      | Transform content in existing stories after a schema change                                                                   |
| `types generate`                        | TypeScript definitions from a space's components. Not in schema-as-code mode — types come from `Schema<typeof schema>` there. |
| `create [project-path]`                 | Scaffold a new project from an official template                                                                              |

There is no `stories delete`, and no delete for components outside
`schema push --delete`. Where the CLI has no command for the job, take the next
best available approach.

## How a push maps ids

`stories push` treats the ids in local files as placeholders and maps them onto
the space, so hand-written files push as well as pulled ones. What has to be
right is how they refer to each other.

- Every file needs an `id` and a `uuid`. For a new story, invent both — any
  value unique within the push (`1001`, `author-maya`) does.
- A reference in the content of a story — a multilink's `id`, a richtext story
  link's or an `internal_stories` option's `uuid` — takes the **local** value
  when its target is in the same push and the remote one when it is not.
- **`parent_id` is the exception: it only ever resolves against the push
  itself.** A parent_id that names no file in this push — the folder's real id
  in the space included — is dropped, and the story is created at the root and
  reported as succeeded.
- So to add stories to a folder that already exists, `stories pull` it first:
  the folder's own file joins the push, is matched to the existing folder rather
  than duplicated, and its local `id` is what the children point at.
- Spell `full_slug` out as the full path (`authors/maya`) — it is what orders
  creation, so a parent is created before the stories that name it.
- Pull the components first: with no `.storyblok/components/<space>/`, the push
  aborts.
- `published: true` in a file publishes that story; `--publish` publishes
  everything in the push.
- A failed story does not fail the push. Read the totals rather than the exit
  code, and read the placement back from the space.

### Adding stories to a folder that already exists

1. `components pull`, then `stories pull`.
2. Leave in `.storyblok/stories/<space>/` only the folder's own file and the new
   files you write; move the rest aside. Every file in that directory is pushed,
   and a push rewrites each story from its local copy — so a file you did not
   mean to touch is a remote edit you did not mean to revert.
3. Name each new file `<slug>_<uuid>.json`, matching the uuid inside it. That is
   what a pull writes and what `--cleanup` unlinks; any other name makes the
   push report a failure for a story it created perfectly well.
4. Say what this will change (see **Before a write**), dry-run, then push with
   `--cleanup`. It deletes the local files the push contained — local files
   only, nothing in the space — so no invented id is left to collide with what a
   later pull writes under the real one.
5. Read back where the new stories landed — a story created at the root is
   reported as succeeded. `stories pull` shows it, but it refetches every story
   in the space; skip it when something cheaper has already answered the
   question.

Leave `.storyblok/stories/<space>/manifest.jsonl` alone. It records which story
each local id created, and that is what makes a second push of the same files an
update instead of a second copy. Keep it and invented ids stay safe to re-push;
delete it, or renumber the local ids, and the next push duplicates everything.

## Files

`.storyblok/` holds what the CLI pulls and pushes — `components/`, `stories/`,
`datasources/`, `migrations/`. `storyblok.config.ts` sets defaults through
`defineConfig` from `storyblok/config`. Code-driven schema definitions are
project source and live in the source root (`src/schema/`), not here.

## Before a write

State what will change before the first write of the task, and run `--dry-run`
wherever it exists — with the same flags as the real run, or the preview is of a
different command.

A dry run prints what a real run prints — the same per-story lines, the same
`succeeded` totals — behind a warning at the top saying nothing was written. For
`stories push` nothing reaches the API at all: the ids it echoes back are your
local ones, no parent is resolved against the space.

Destructive — each needs its own explicit confirmation naming what is lost, and
never runs unattended:

- `schema push --delete` — deletes remote components and datasources absent from
  the local schema.
- `migrations run` — rewrites content in existing stories. Dry-run and read the
  diff first.
- `stories push`, `components push` — overwrite remote entities with local
  files, so a stale local copy silently reverts remote edits.
- `datasources delete`.

Report what changed from the command's own output.

## Beyond this page

`storyblok <command> --help` outranks this file whenever they disagree, and the
full reference is <https://www.storyblok.com/docs/libraries/storyblok-cli.md>.
Go there for a command's complete flag list, or for anything above that turns
out not to answer the question.
