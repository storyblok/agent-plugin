#!/bin/sh

set -eu

usage() {
  echo "Usage: <token> | STORYBLOK_SPACE_ID=<id> upload-asset.sh <image-path> [alt-text]" >&2
  exit 2
}

[ "$#" -ge 1 ] && [ "$#" -le 2 ] || usage

asset_path=$1
alt_text=${2:-}
space_id=${STORYBLOK_SPACE_ID:-}
region=${STORYBLOK_REGION:-}

[ -n "$space_id" ] || {
  echo "STORYBLOK_SPACE_ID is required" >&2
  exit 2
}
case "$space_id" in
  '' | *[!0-9]*)
    echo "STORYBLOK_SPACE_ID must be numeric: $space_id" >&2
    exit 2
    ;;
esac

# A space id encodes its own region, so the region never has to be supplied.
# Ids of 49 bits and up carry it in bits 48-52; smaller legacy ids fall in a
# per-region range. Mirrors @storyblok/region-helper's getRegion.
if [ -z "$region" ]; then
  if [ "$space_id" -ge 281474976710656 ]; then
    case $(( (space_id >> 48) & 31 )) in
      0 | 1) region=eu ;;
      2) region=us ;;
      3) region=ca ;;
      4) region=ap ;;
      6) region=cn ;;
    esac
  elif [ "$space_id" -lt 1000000 ]; then
    region=eu # Shared with cn; set STORYBLOK_REGION=cn for a legacy Chinese space.
  elif [ "$space_id" -lt 2000000 ]; then
    region=us
  elif [ "$space_id" -lt 3000000 ]; then
    region=ca
  elif [ "$space_id" -lt 4000000 ]; then
    region=ap
  fi
fi

[ -n "$region" ] || {
  echo "Could not determine the region for space $space_id." >&2
  echo "Set STORYBLOK_REGION to one of: eu, us, cn, ca, ap" >&2
  exit 2
}
# The token arrives on stdin, never from the environment: a credential that
# merely exists there is not one the user handed over.
token=
[ -t 0 ] || token=$(cat)
[ -n "$token" ] || {
  echo "A Storyblok personal access token is required on stdin." >&2
  echo "Pipe in the one the user named, e.g.:" >&2
  echo "  printf '%s' \"\$<VARIABLE>\" | STORYBLOK_SPACE_ID=<id> upload-asset.sh <image-path>" >&2
  echo "If the user has not named a variable or secret-manager command for it," >&2
  echo "ask which one to use. Never ask for the token itself." >&2
  exit 2
}
[ -f "$asset_path" ] || {
  echo "Asset path must point to a file: $asset_path" >&2
  exit 2
}
command -v jq >/dev/null 2>&1 || {
  echo "jq is required" >&2
  exit 2
}
curl_bin=${CURL_BIN:-curl}
command -v "$curl_bin" >/dev/null 2>&1 || {
  echo "curl is required" >&2
  exit 2
}

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/storyblok-asset-upload.XXXXXX")
trap 'rm -rf "$work_dir"' EXIT HUP INT TERM

case "$region" in
  eu) mapi_host=mapi.storyblok.com ;;
  us) mapi_host=api-us.storyblok.com ;;
  cn) mapi_host=app.storyblokchina.cn ;;
  ca) mapi_host=api-ca.storyblok.com ;;
  ap) mapi_host=api-ap.storyblok.com ;;
  *)
    echo "Unsupported STORYBLOK_REGION: $region" >&2
    exit 2
    ;;
esac

mapi_base="https://$mapi_host/v1/spaces/$space_id"
filename=$(basename -- "$asset_path")
signed_path="$work_dir/signed.json"
finish_path="$work_dir/finished.json"
fields_path="$work_dir/fields.tsv"

# The token goes to curl through a config file, not `-H "Authorization: $token"`.
# Command-line arguments are world-readable in the process list, so an `-H` form
# exposes the token to every other user on the machine for the duration of each
# request. mktemp -d gives a 0700 directory and the EXIT trap removes it.
auth_config="$work_dir/auth.conf"
printf 'header = "Authorization: %s"\n' "$token" >"$auth_config"

"$curl_bin" -sS --fail-with-body --retry 3 --retry-delay 1 \
  --retry-connrefused -X POST -G \
  "$mapi_base/assets" \
  --config "$auth_config" \
  --data-urlencode "filename=$filename" \
  --data-urlencode "alt=$alt_text" \
  -o "$signed_path"

asset_id=$(jq -er '.id' "$signed_path")
post_url=$(jq -er '.post_url' "$signed_path")
jq -er '.fields | to_entries[] | [.key, .value] | @tsv' \
  "$signed_path" >"$fields_path"

set --
tab=$(printf '\t')
while IFS="$tab" read -r field_name field_value
do
  set -- "$@" -F "$field_name=$field_value"
done <"$fields_path"
set -- "$@" -F "file=@$asset_path"

"$curl_bin" -sS --fail-with-body --retry 3 --retry-delay 1 \
  --retry-connrefused -X POST \
  "$post_url" \
  "$@" \
  -o /dev/null

"$curl_bin" -sS --fail-with-body --retry 3 --retry-delay 1 \
  --retry-connrefused \
  "$mapi_base/assets/$asset_id/finish_upload" \
  --config "$auth_config" \
  -o "$finish_path"

uploaded_filename=$(jq -er '.filename' "$finish_path") || {
  echo "Storyblok finished the upload without returning a filename" >&2
  exit 1
}
# A complete asset field value, not just the URL: an `asset` field stores the
# whole object and keeps its keys even when they are empty.
jq -cn --arg filename "$uploaded_filename" --arg alt "$alt_text" \
  --argjson id "$asset_id" \
  '{fieldtype: "asset", id: $id, filename: $filename, alt: $alt,
    name: "", title: "", copyright: "", focus: ""}'
