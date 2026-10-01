# The Management API directly

The rung below both tools: what to do when neither the MCP server nor the CLI
has the operation the job needs.

`https://<host>/v1/spaces/<space_id>/…` — one resource per call, the same API
both tools drive.

The host is regional, and the space id says which region it is. An id ≥ 2⁴⁸
(`281474976710656`) carries the region in bits 48–52; a smaller one is legacy
and falls in a range:

| Region | Host                    | Bits 48–52 | Legacy id range  |
| ------ | ----------------------- | ---------- | ---------------- |
| eu     | `mapi.storyblok.com`    | `0`, `1`   | < 1000000        |
| us     | `api-us.storyblok.com`  | `2`        | < 2000000        |
| ca     | `api-ca.storyblok.com`  | `3`        | < 3000000        |
| ap     | `api-ap.storyblok.com`  | `4`        | < 4000000        |
| cn     | `app.storyblokchina.cn` | `6`        | shares < 1000000 |

The wrong host answers `404 ["This record could not be found"]` — the same as a
wrong space id, so check the host before doubting the id.

Authenticate with the personal access token the user named: an environment
variable or a secret-manager command — the raw token, no `Bearer`. When they
have named none, ask which to use and wait; never pick one up only because it is
set. Never expand it: an echoed token is a token in the transcript — check that
a named variable is set with `[ -n "$STORYBLOK_TOKEN" ] && echo set`, never with
`env | grep -i storyblok`.

Pipe the header in as a curl config rather than passing `-H` — here with
`STORYBLOK_TOKEN` as the variable the user named:

```bash
printf 'header = "Authorization: %s"\n' "$STORYBLOK_TOKEN" |
  curl -sS --fail-with-body --config - \
    "https://mapi.storyblok.com/v1/spaces/$space_id/stories"
```

That takes stdin, so a request body travels as `--data @<file>`, never `@-`.

curl exits 0 on an HTTP error, so pass `--fail-with-body` and read the status.
What the tool skills say about writes still holds: state the change before the
first one, and read back what you changed.

A delete waits for the user's explicit go-ahead, even when they named what to
delete: name exactly what goes, say that a deleted story or asset moves to the
trash and can be restored in the Storyblok UI, and stop. Only a pre-approved run
skips the wait.
