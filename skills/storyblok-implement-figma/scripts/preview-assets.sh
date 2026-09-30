#!/bin/sh

set -eu

usage() {
  echo "Usage: preview-assets.sh <manifest.json> <output.png>" >&2
  exit 2
}

[ "$#" -eq 2 ] || usage

MANIFEST_PATH=$1
OUTPUT_PATH=$2
export MANIFEST_PATH OUTPUT_PATH

[ -f "$MANIFEST_PATH" ] || {
  echo "Manifest must point to a file: $MANIFEST_PATH" >&2
  exit 2
}

command -v node >/dev/null 2>&1 || {
  echo "node is required" >&2
  exit 2
}

preview='
const { lstat, readFile } = require("fs/promises");
const { chromium } = require("playwright");

const MIME_BY_EXTENSION = {
  avif: "image/avif",
  gif: "image/gif",
  jpeg: "image/jpeg",
  jpg: "image/jpeg",
  png: "image/png",
  svg: "image/svg+xml",
  webp: "image/webp",
};

// A page built with setContent has no origin, so it cannot load a local file,
// and inlining keeps a remote render from failing the preview halfway through
// the capture.
async function toDataUrl(source) {
  if (/^https?:/.test(source)) {
    const response = await fetch(source);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const received = (response.headers.get("content-type") || "")
      .split(";")[0].trim().toLowerCase();
    // A header value may legally carry quotes and angle brackets, and the data
    // URL reaches the markup unescaped: only a known type may be echoed back.
    const mime = Object.values(MIME_BY_EXTENSION).includes(received)
      ? received
      : "image/png";
    const body = Buffer.from(await response.arrayBuffer());
    return `data:${mime};base64,${body.toString("base64")}`;
  }
  // The manifest is written from design context, which is untrusted input, and
  // every source is inlined into one page the agent then looks at. The guard
  // matches sync-assets.sh: keep the source inside the working directory, and
  // refuse symlinks, so no file outside the project can be rendered.
  if (/(^\/)|(^|\/)\.\.(\/|$)/.test(source)) {
    throw new Error(`file must be a clean relative path: ${source}`);
  }
  if (!(await lstat(source)).isFile()) {
    throw new Error(`file must be an existing regular file: ${source}`);
  }
  const extension = source.split(".").pop().toLowerCase();
  const body = await readFile(source);
  const mime = MIME_BY_EXTENSION[extension]
    || (body.subarray(0, 512).includes("<svg") ? "image/svg+xml" : "image/png");
  return `data:${mime};base64,${body.toString("base64")}`;
}

const FETCH_CONCURRENCY = 6;

// Every entry is inlined as base64, so an unbounded fan-out would open one
// connection per manifest entry and hold the whole sheet in memory at once. The
// cap matches sync-assets.sh; results stay in manifest order either way.
async function mapWithLimit(items, limit, mapper) {
  const results = new Array(items.length);
  let cursor = 0;
  const worker = async () => {
    while (cursor < items.length) {
      const index = cursor++;
      results[index] = await mapper(items[index], index);
    }
  };
  await Promise.all(
    Array.from({ length: Math.min(limit, items.length) }, worker),
  );
  return results;
}

// Chromium refuses a screenshot taller than roughly 16384px, and a manifest
// large enough to hit that must still render in full: trade frame height for
// columns instead of dropping entries. Each column keeps its width, so a sheet
// that fits three columns is laid out exactly as before.
const SHEET_HEIGHT_LIMIT = 16384;
const COLUMN_WIDTH = 440;
const SHEET_PADDING = 32;
// Caption, borders and the gap a row adds on top of its frame, rounded up so the
// estimate errs towards a shorter sheet than the limit allows.
const ROW_CHROME = 96;
const LAYOUTS = [
  { columns: 3, frameHeight: 360 },
  { columns: 4, frameHeight: 260 },
  { columns: 6, frameHeight: 170 },
];

const sheetHeight = (count, { columns, frameHeight }) =>
  Math.ceil(count / columns) * (frameHeight + ROW_CHROME) + SHEET_PADDING;

function layoutFor(count) {
  const fitting = LAYOUTS.find(
    (layout) => sheetHeight(count, layout) <= SHEET_HEIGHT_LIMIT,
  );
  if (fitting) return fitting;
  const { columns } = LAYOUTS[LAYOUTS.length - 1];
  const rows = Math.ceil(count / columns);
  const available = Math.floor((SHEET_HEIGHT_LIMIT - SHEET_PADDING) / rows);
  return { columns, frameHeight: Math.max(48, available - ROW_CHROME) };
}

const escapeHtml = (value) =>
  value.replace(/[&<>"]/g, (character) => `&#${character.charCodeAt(0)};`);

const PAGE_STYLES = `
  body { margin: 0; padding: 16px; background: #fff; font: 13px ui-monospace, monospace }
  ul { display: grid; grid-template-columns: var(--grid-columns); gap: 16px; margin: 0; padding: 0; list-style: none }
  li { border: 1px solid #d0d0d0; border-radius: 6px; overflow: hidden }
  figcaption { padding: 6px 8px; border-bottom: 1px solid #d0d0d0; background: #f4f4f4; word-break: break-all }
  .frame { display: grid; place-items: center; height: var(--frame-height); padding: 8px;
    /* Checkerboard, so a baked-in backdrop reads differently from transparency. */
    background-color: #fff;
    background-image: linear-gradient(45deg, #e8e8e8 25%, transparent 25%, transparent 75%, #e8e8e8 75%),
      linear-gradient(45deg, #e8e8e8 25%, transparent 25%, transparent 75%, #e8e8e8 75%);
    background-size: 16px 16px; background-position: 0 0, 8px 8px }
  img { max-width: 100%; max-height: 100%; object-fit: contain }
  .error { color: #b00020 }
`;

(async () => {
  const manifest = JSON.parse(await readFile(process.env.MANIFEST_PATH, "utf8"));
  if (!Array.isArray(manifest) || manifest.length === 0) {
    throw new Error("the manifest must be a non-empty array");
  }

  const failures = [];
  const cells = await mapWithLimit(
    manifest,
    FETCH_CONCURRENCY,
    async (entry, index) => {
      const name = String(entry.key ?? index + 1);
      const label = escapeHtml(name);
      try {
        // An entry names its source as either `url` or `file`.
        const dataUrl = await toDataUrl(entry.url || entry.file);
        return `<li><figure><figcaption>${label}</figcaption>
          <div class="frame"><img src="${dataUrl}" alt=""></div></figure></li>`;
      } catch (error) {
        failures.push(`${name}: ${error.message}`);
        return `<li><figure><figcaption>${label}</figcaption>
          <div class="frame error">${escapeHtml(error.message)}</div></figure></li>`;
      }
    },
  );

  const { columns, frameHeight } = layoutFor(manifest.length);
  const layoutStyles =
    `:root { --grid-columns: repeat(${columns}, 1fr); --frame-height: ${frameHeight}px }`;

  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({
      viewport: { width: columns * COLUMN_WIDTH, height: 900 },
    });
    await page.setContent(
      `<style>${PAGE_STYLES}${layoutStyles}</style><ul>${cells.join("")}</ul>`,
      { waitUntil: "load" },
    );
    await page.screenshot({ path: process.env.OUTPUT_PATH, fullPage: true });
  } finally {
    await browser.close();
  }
  console.log(process.env.OUTPUT_PATH);

  // A sheet of nothing but error boxes shows no asset, and a caller that checks
  // the exit status would take it for a preview worth looking at. A partial
  // failure still exits 0, so one bad entry does not discard the rendered rest.
  if (failures.length === manifest.length) {
    console.error("No asset could be previewed — the sheet repeats each error:");
    for (const failure of failures) console.error(`  ${failure}`);
    process.exitCode = 1;
  }
})();
'

# Prefer the copy the project already depends on; borrow a pinned one through
# npx only when it has none. NODE_PATH points at the node_modules npx stages —
# two directories above the `playwright` bin it puts on PATH.
if node -e 'require.resolve("playwright")' >/dev/null 2>&1; then
  run_preview() { node -e "$preview"; }
  install_browser() {
    node "$(dirname "$(node -p 'require.resolve("playwright/package.json")')")/cli.js" \
      install chromium
  }
else
  run_preview() {
    npx --yes -p playwright@1.63.0 sh -c \
      'NODE_PATH=$(dirname "$(dirname "$(command -v playwright)")") \
        exec node -e "$1"' sh "$preview"
  }
  install_browser() { npx --yes -p playwright@1.63.0 playwright install chromium; }
fi

errors="${TMPDIR:-/tmp}/preview-assets.$$.err"
cleanup() { rm -f "$errors"; }
trap cleanup EXIT HUP INT TERM

run_preview 2>"$errors" || {
  # The one failure worth retrying: Playwright is installed but its browser
  # binary is not. Every other failure is reported as it happened.
  if grep -q "playwright install" "$errors"; then
    install_browser >&2
    run_preview
  else
    cat "$errors" >&2
    exit 1
  fi
}
