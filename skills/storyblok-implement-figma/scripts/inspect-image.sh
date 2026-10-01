#!/bin/sh

set -eu

usage() {
  echo "Usage: inspect-image.sh <path-or-url> [<path-or-url>...]" >&2
  exit 2
}

[ "$#" -ge 1 ] || usage

IMAGE_SOURCES=$(printf '%s\n' "$@")
export IMAGE_SOURCES

command -v node >/dev/null 2>&1 || {
  echo "node is required" >&2
  exit 2
}

inspect='
const { readFile } = require("fs/promises");
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

// The canvas has to read the pixels back, and a cross-origin image would taint
// it. Everything is inlined as a data URL so the sample always succeeds.
async function toDataUrl(source) {
  if (/^https?:/.test(source)) {
    const response = await fetch(source);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const mime = (response.headers.get("content-type") || "").split(";")[0];
    const body = Buffer.from(await response.arrayBuffer());
    return `data:${mime || "image/png"};base64,${body.toString("base64")}`;
  }
  const extension = source.split(".").pop().toLowerCase();
  const body = await readFile(source);
  const mime = MIME_BY_EXTENSION[extension]
    || (body.subarray(0, 512).includes("<svg") ? "image/svg+xml" : "image/png");
  return `data:${mime};base64,${body.toString("base64")}`;
}

const sample = (dataUrl) =>
  new Promise((resolve, reject) => {
    const image = new Image();
    image.onerror = () => reject(new Error("the browser could not decode it"));
    image.onload = () => {
      const width = image.naturalWidth;
      const height = image.naturalHeight;
      const scale = Math.min(1, 200 / Math.max(width, height));
      const canvas = document.createElement("canvas");
      canvas.width = Math.max(1, Math.round(width * scale));
      canvas.height = Math.max(1, Math.round(height * scale));
      const context = canvas.getContext("2d", { willReadFrequently: true });
      context.drawImage(image, 0, 0, canvas.width, canvas.height);
      const { data } = context.getImageData(0, 0, canvas.width, canvas.height);

      const counts = new Map();
      let opaque = 0;
      for (let i = 0; i < data.length; i += 4) {
        if (data[i + 3] < 128) continue;
        opaque += 1;
        // Quantised so antialiasing collapses into the colour it fringes.
        const key = [data[i], data[i + 1], data[i + 2]]
          .map((channel) => Math.round(channel / 16) * 16)
          .map((channel) => Math.min(255, channel).toString(16).padStart(2, "0"))
          .join("");
        counts.set(key, (counts.get(key) || 0) + 1);
      }

      resolve({
        width,
        height,
        opaqueShare: Number((opaque / (canvas.width * canvas.height)).toFixed(3)),
        colors: [...counts.entries()]
          .sort((a, b) => b[1] - a[1])
          .slice(0, 8)
          .map(([hex, count]) => ({
            hex: `#${hex}`,
            share: Number((count / opaque).toFixed(3)),
          })),
      });
    };
    image.src = dataUrl;
  });

(async () => {
  const sources = process.env.IMAGE_SOURCES.split("\n").filter(Boolean);
  const browser = await chromium.launch({ headless: true });
  const report = [];
  try {
    const page = await browser.newPage();
    await page.goto("about:blank");
    for (const source of sources) {
      try {
        const dataUrl = await toDataUrl(source);
        report.push({ source, ...(await page.evaluate(sample, dataUrl)) });
      } catch (error) {
        report.push({ source, error: error.message });
      }
    }
  } finally {
    await browser.close();
  }
  console.log(JSON.stringify(report, null, 2));

  // A report in which every entry failed carries no measurement at all, and a
  // caller that checks the exit status would take it for a clean inspection.
  // A partial failure still exits 0, so one bad source cannot hide the rest.
  if (report.every((entry) => entry.error)) {
    console.error("No image could be inspected:");
    for (const entry of report) {
      console.error(`  ${entry.source}: ${entry.error}`);
    }
    process.exitCode = 1;
  }
})();
'

# Prefer the copy the project already depends on; borrow a pinned one through
# npx only when it has none. NODE_PATH points at the node_modules npx stages —
# two directories above the `playwright` bin it puts on PATH.
if node -e 'require.resolve("playwright")' >/dev/null 2>&1; then
  run_inspect() { node -e "$inspect"; }
  install_browser() {
    node "$(dirname "$(node -p 'require.resolve("playwright/package.json")')")/cli.js" \
      install chromium
  }
else
  run_inspect() {
    npx --yes -p playwright@1.63.0 sh -c \
      'NODE_PATH=$(dirname "$(dirname "$(command -v playwright)")") \
        exec node -e "$1"' sh "$inspect"
  }
  install_browser() { npx --yes -p playwright@1.63.0 playwright install chromium; }
fi

errors="${TMPDIR:-/tmp}/inspect-image.$$.err"
cleanup() { rm -f "$errors"; }
trap cleanup EXIT HUP INT TERM

run_inspect 2>"$errors" || {
  # The one failure worth retrying: Playwright is installed but its browser
  # binary is not. Every other failure is reported as it happened.
  if grep -q "playwright install" "$errors"; then
    install_browser >&2
    run_inspect
  else
    cat "$errors" >&2
    exit 1
  fi
}
