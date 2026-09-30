#!/bin/sh

set -eu

usage() {
  echo "Usage: screenshot-page.sh <url> <output.png> [viewport-width]" \
    "[--slices] [--slice-height <px>]" >&2
  exit 2
}

[ "$#" -ge 2 ] || usage

PAGE_URL=$1
OUTPUT_PATH=$2
shift 2

VIEWPORT_WIDTH=1440
# 0 means do not slice; -1 means slice at the height the capture picks itself.
SLICE_HEIGHT=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --slices)
      [ "$SLICE_HEIGHT" -eq 0 ] && SLICE_HEIGHT=-1
      shift ;;
    --slice-height)
      [ "$#" -ge 2 ] || usage
      SLICE_HEIGHT=$2
      case "$SLICE_HEIGHT" in
        ''|*[!0-9]*|0) usage ;;
      esac
      shift 2 ;;
    *)
      VIEWPORT_WIDTH=$1
      shift ;;
  esac
done
export PAGE_URL OUTPUT_PATH VIEWPORT_WIDTH SLICE_HEIGHT

case "$VIEWPORT_WIDTH" in
  ''|*[!0-9]*) usage ;;
esac

command -v node >/dev/null 2>&1 || {
  echo "node is required" >&2
  exit 2
}

capture='
const { chromium } = require("playwright");

const IMAGE_SETTLE_TIMEOUT = 15000;
const SCROLL_SETTLE_MS = 100;
const MAX_SCROLL_STEPS = 300;
const NAVIGATION_ATTEMPTS = 3;
const NAVIGATION_RETRY_MS = 2000;
// Chromium refuses a screenshot taller than roughly 16384px.
const SLICE_HEIGHT_LIMIT = 16384;

const sleep = (ms) => new Promise((resume) => setTimeout(resume, ms));

// A dev server is rarely serving the moment it prints its URL: the first
// request can arrive while dependencies are still being optimised, and some
// servers restart themselves on finishing that. Retrying costs a moment and
// saves the whole capture.
async function openPage(page, url) {
  for (let attempt = 1; ; attempt += 1) {
    try {
      await page.goto(url, { waitUntil: "domcontentloaded" });
      return;
    } catch (error) {
      if (attempt >= NAVIGATION_ATTEMPTS) throw error;
      await sleep(NAVIGATION_RETRY_MS);
    }
  }
}

// A full-page capture of a long page is too tall to read in one piece, and
// downscaling it to fit throws away the detail a comparison is looking for.
// Each slice is cut at full resolution instead.
//
// Whoever reads the slice back scales it so its long edge fits, so legibility
// follows the height of a slice and not how many there are. A tile about as
// tall as it is wide survives that scaling close to unchanged, which is why
// the default is the viewport width rather than a number to be guessed.
async function writeSlices(page, outputPath, requestedHeight) {
  const { width, height } = await page.evaluate(() => ({
    width: document.documentElement.scrollWidth,
    height: document.documentElement.scrollHeight,
  }));
  const sliceHeight = Math.min(
    requestedHeight > 0 ? requestedHeight : width,
    SLICE_HEIGHT_LIMIT,
  );
  const stem = outputPath.replace(/\.png$/i, "");
  const paths = [];
  for (let top = 0, index = 1; top < height; top += sliceHeight, index += 1) {
    const path = `${stem}-${String(index).padStart(2, "0")}.png`;
    await page.screenshot({
      path,
      fullPage: true,
      clip: {
        x: 0,
        y: top,
        width,
        height: Math.min(sliceHeight, height - top),
      },
    });
    paths.push(path);
  }
  return paths;
}

(async () => {
  const width = Number(process.env.VIEWPORT_WIDTH);
  const browser = await chromium.launch({ headless: true });
  try {
    const page = await browser.newPage({ viewport: { width, height: 900 } });
    // Gated on the document, not load: a page whose images come from a slow
    // CDN never fires load, and the navigation would then fail outright rather
    // than yield a partial render. The bounded waits below cover the images.
    await openPage(page, process.env.PAGE_URL);

    // A full-page screenshot does not scroll the document, so browser-native
    // lazy images below the fold never start loading and capture as blanks.
    // Jumping straight to the bottom only requests what lies near the bottom:
    // everything the viewport skipped over stays unrequested, and its complete
    // stays false forever. Walk the page a viewport at a time so every image
    // intersects on the way.
    await page.evaluate(
      async ({ settleMs, maxSteps }) => {
        const sleep = (ms) => new Promise((resume) => setTimeout(resume, ms));
        for (let step = 0; step < maxSteps; step += 1) {
          const bottom =
            document.documentElement.scrollHeight - window.innerHeight;
          const target = Math.min(step * window.innerHeight, bottom);
          scrollTo(0, target);
          await sleep(settleMs);
          if (target >= bottom) break;
        }
      },
      { settleMs: SCROLL_SETTLE_MS, maxSteps: MAX_SCROLL_STEPS },
    );
    // Both waits are best-effort: a page holding a long-lived connection never
    // reaches network idle, and a hanging request never completes. On expiry we
    // capture what is there rather than failing. A broken image is no obstacle
    // either way, since complete is true once a request has failed.
    await Promise.all([
      page
        .waitForLoadState("networkidle", { timeout: IMAGE_SETTLE_TIMEOUT })
        .catch(() => {}),
      page
        .waitForFunction(
          () => Array.from(document.images).every((image) => image.complete),
          null,
          { timeout: IMAGE_SETTLE_TIMEOUT },
        )
        .catch(() => {}),
    ]);
    await page.evaluate(() => scrollTo(0, 0));
    await page.waitForTimeout(250);

    await page.screenshot({ path: process.env.OUTPUT_PATH, fullPage: true });
    console.log(process.env.OUTPUT_PATH);

    const sliceHeight = Number(process.env.SLICE_HEIGHT);
    if (sliceHeight !== 0) {
      const paths = await writeSlices(
        page,
        process.env.OUTPUT_PATH,
        sliceHeight,
      );
      for (const path of paths) console.log(path);
    }
  } finally {
    await browser.close();
  }
})();
'

# Prefer the copy the project already depends on; borrow a pinned one through
# npx only when it has none. NODE_PATH points at the node_modules npx stages —
# two directories above the `playwright` bin it puts on PATH.
if node -e 'require.resolve("playwright")' >/dev/null 2>&1; then
  run_capture() { node -e "$capture"; }
  install_browser() {
    node "$(dirname "$(node -p 'require.resolve("playwright/package.json")')")/cli.js" \
      install chromium
  }
else
  run_capture() {
    npx --yes -p playwright@1.63.0 sh -c \
      'NODE_PATH=$(dirname "$(dirname "$(command -v playwright)")") \
        exec node -e "$1"' sh "$capture"
  }
  install_browser() { npx --yes -p playwright@1.63.0 playwright install chromium; }
fi

run_capture 2>"${TMPDIR:-/tmp}/screenshot-page.$$.err" || {
  # The one failure worth retrying: Playwright is installed but its browser
  # binary is not. Every other failure is reported as it happened.
  if grep -q "playwright install" "${TMPDIR:-/tmp}/screenshot-page.$$.err"; then
    install_browser >&2
    rm -f "${TMPDIR:-/tmp}/screenshot-page.$$.err"
    run_capture
  else
    cat "${TMPDIR:-/tmp}/screenshot-page.$$.err" >&2
    rm -f "${TMPDIR:-/tmp}/screenshot-page.$$.err"
    exit 1
  fi
}

rm -f "${TMPDIR:-/tmp}/screenshot-page.$$.err"
