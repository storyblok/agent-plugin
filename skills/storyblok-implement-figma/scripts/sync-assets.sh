#!/bin/sh

set -eu

usage() {
  echo "Usage: <token> | STORYBLOK_SPACE_ID=<id> sync-assets.sh <manifest.json>" >&2
  echo "The token is needed only when the manifest has cms entries." >&2
  exit 2
}

[ "$#" -eq 1 ] || usage

manifest=$1
[ -f "$manifest" ] || {
  echo "Manifest must point to a file: $manifest" >&2
  exit 2
}

command -v jq >/dev/null 2>&1 || {
  echo "jq is required" >&2
  exit 2
}

curl_bin=${CURL_BIN:-curl}
file_bin=${FILE_BIN:-file}
command -v "$curl_bin" >/dev/null 2>&1 || {
  echo "curl is required" >&2
  exit 2
}
command -v "$file_bin" >/dev/null 2>&1 || {
  echo "file is required" >&2
  exit 2
}

jq -e '
  type == "array" and length > 0 and
  all(.[];
    (.key | type == "string" and length > 0) and
    ((.url | type == "string" and length > 0) != (.file | type == "string" and length > 0)) and
    (
      (.kind == "cms" and (.name | type == "string" and test("^[A-Za-z0-9._-]+$"))) or
      (.kind == "code" and (.path | type == "string" and length > 0))
    )
  ) and
  ([.[].key] | length == (unique | length))
' "$manifest" >/dev/null || {
  echo "Invalid manifest: use unique keys, exactly one of url/file, and cms/name or code/path entries" >&2
  exit 2
}

# Read once here: the uploads run in background jobs, which get no stdin, so
# each one is handed the token in turn.
token=
if jq -e 'any(.[]; .kind == "cms")' "$manifest" >/dev/null; then
  [ -t 0 ] || token=$(cat)
  [ -n "$token" ] || {
    echo "cms entries need a Storyblok personal access token on stdin." >&2
    echo "Pipe in the one the user named, e.g.:" >&2
    echo "  printf '%s' \"\$<VARIABLE>\" | STORYBLOK_SPACE_ID=<id> sync-assets.sh <manifest.json>" >&2
    echo "If the user has not named a variable or secret-manager command for it," >&2
    echo "ask which one to use. Never ask for the token itself." >&2
    exit 2
  }
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
upload_script="$script_dir/upload-asset.sh"
# Downloads are staged in a private temp directory the script creates and owns —
# never a path relative to the working directory, which `rm -rf` on the way in and
# out would destroy if the script ran from the wrong place. Only `code` asset
# destinations are relative to the working directory, and those come from the
# manifest.
stage_dir=$(mktemp -d "${TMPDIR:-/tmp}/storyblok-figma-assets.XXXXXX")
results_dir=$(mktemp -d "${TMPDIR:-/tmp}/storyblok-assets.XXXXXX")

cleanup() {
  rm -rf "$stage_dir" "$results_dir"
}
trap cleanup EXIT HUP INT TERM

extension_for() {
  mime=$1
  path=$2
  case "$mime" in
    image/svg+xml) echo svg ;;
    image/png) echo png ;;
    image/jpeg) echo jpg ;;
    image/gif) echo gif ;;
    image/webp) echo webp ;;
    image/avif) echo avif ;;
    text/html)
      # file(1) reads an SVG whose first line is `<!DOCTYPE html>` as text/html.
      if head -c 4096 "$path" | grep -qi '<svg'; then
        echo svg
      else
        echo "Unsupported asset MIME type: $mime" >&2
        return 1
      fi
      ;;
    *)
      echo "Unsupported asset MIME type: $mime" >&2
      return 1
      ;;
  esac
}

process_record() {
  record=$1
  index=$2
  key=$(printf '%s' "$record" | jq -r '.key')
  source_file=$(printf '%s' "$record" | jq -r '.file // ""')
  kind=$(printf '%s' "$record" | jq -r '.kind')
  download="$stage_dir/$index.download"

  if [ -n "$source_file" ]; then
    # The manifest is written from design context, which is untrusted input, and
    # a `cms` entry ends up on a public asset URL. Keep the source inside the
    # working directory, and refuse symlinks, so no file outside the project can
    # be published by naming it here.
    case "/$source_file/" in
      *"/../"*|//*)
        echo "Asset file must be a clean relative path: $key -> $source_file" >&2
        return 1
        ;;
    esac
    if [ ! -f "$source_file" ] || [ -L "$source_file" ]; then
      echo "Asset file must be an existing regular file: $key -> $source_file" >&2
      return 1
    fi
    # Staged like a download so the MIME check, extension fix and upload path
    # stay identical.
    cp -- "$source_file" "$download"
  else
    url=$(printf '%s' "$record" | jq -r '.url')
    "$curl_bin" -sS --fail-with-body --retry 3 --retry-delay 1 \
      --retry-connrefused -o "$download" "$url"
  fi
  mime=$("$file_bin" --brief --mime-type "$download")
  extension=$(extension_for "$mime" "$download")

  if [ "$kind" = cms ]; then
    name=$(printf '%s' "$record" | jq -r '.name')
    alt=$(printf '%s' "$record" | jq -r '.alt // ""')
    prepared="$stage_dir/$name.$extension"
    mv "$download" "$prepared"
    value=$(printf '%s' "$token" | "$upload_script" "$prepared" "$alt")
  else
    relative_path=$(printf '%s' "$record" | jq -r '.path')
    case "/$relative_path/" in
      *"/../"*|//*)
        echo "Code asset path must be a clean relative path: $relative_path" >&2
        return 1
        ;;
    esac
    final_path="$relative_path.$extension"
    mkdir -p "$(dirname -- "$final_path")"
    mv "$download" "$final_path"
    value=$(jq -cn --arg path "$final_path" '{path: $path}')
  fi

  jq -cn --arg key "$key" --argjson value "$value" \
    '{key: $key, value: $value}' >"$results_dir/$index.json"
}

records_file="$results_dir/records.txt"
jq -rc '.[] | @base64' "$manifest" >"$records_file"

pids=
active=0
index=0

wait_wave() {
  for pid in $pids
  do
    wait "$pid" || true
  done
  pids=
  active=0
}

while IFS= read -r encoded
do
  index=$((index + 1))
  record=$(printf '%s' "$encoded" | jq -Rr '@base64d')
  # A record with no result at the end failed. Its key is recorded up front
  # because the failing subshell exits before it could leave a marker itself.
  printf '%s' "$record" | jq -r '.key' >"$results_dir/$index.key"
  process_record "$record" "$index" &
  pids="$pids $!"
  active=$((active + 1))
  if [ "$active" -eq 6 ]; then
    wait_wave
  fi
done <"$records_file"

[ "$active" -eq 0 ] || wait_wave

failed_keys=$(
  for key_file in "$results_dir"/*.key
  do
    [ -f "${key_file%.key}.json" ] || cat "$key_file"
  done
)

# Report what succeeded even when something failed: those uploads already
# happened, and a caller that sees only an error re-uploads or loses them.
set -- "$results_dir"/*.json
if [ -f "$1" ]; then
  jq -s 'from_entries' "$@"
else
  echo '{}'
fi

[ -z "$failed_keys" ] || {
  echo "Assets that failed — every other key is in the output above:" >&2
  printf '%s\n' "$failed_keys" >&2
  exit 1
}
