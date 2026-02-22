#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import pixelmatch from "pixelmatch";
import { PNG } from "pngjs";
import {
  ensureCleanDir,
  runCommand,
  createStaticServer,
  launchChromiumWithFallback
} from "./shared.mjs";

const args = new Set(process.argv.slice(2));
const updateBaseline = args.has("--update");
const headed = args.has("--headed");
const debugLaunch = args.has("--debug-launch");

const rootDir = process.cwd();
const uiDir = path.join(rootDir, "tests", "ui");
const fixtureDir = path.join(uiDir, ".tmp", "fixture");
const actualDir = path.join(uiDir, "actual");
const baselineDir = path.join(uiDir, "baseline");
const diffDir = path.join(uiDir, "diff");

const snapshotTargets = [
  { name: "desktop", width: 1280, height: 900 },
  { name: "mobile", width: 480, height: 900 }
];

const mismatchToleranceRatio = 0.003;

ensureCleanDir(actualDir);
ensureCleanDir(diffDir);
ensureCleanDir(fixtureDir);
fs.mkdirSync(baselineDir, { recursive: true });

runCommand("Rscript", ["tests/ui/generate_demo_widget.R", fixtureDir]);

const fixtureIndex = path.join(fixtureDir, "index.html");
if (!fs.existsSync(fixtureIndex)) {
  throw new Error(`Fixture page not found: ${fixtureIndex}`);
}

const server = createStaticServer(fixtureDir);
await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
const { port } = server.address();
const baseUrl = `http://127.0.0.1:${port}/index.html`;

let browser = null;
let failures = 0;

try {
  browser = await launchChromiumWithFallback({
    rootDir,
    headless: !headed,
    debug: debugLaunch
  });

  for (const target of snapshotTargets) {
    const page = await browser.newPage({
      viewport: { width: target.width, height: target.height }
    });

    await page.goto(`${baseUrl}?target=${target.name}`, {
      waitUntil: "networkidle"
    });
    await page.waitForSelector(".ortho-shell", { timeout: 15000 });
    await page.waitForSelector('[data-status="world"]', { timeout: 15000 });
    await page.waitForTimeout(400);

    const shotPath = path.join(actualDir, `${target.name}.png`);
    await page.locator(".ortho-shell").screenshot({ path: shotPath });
    await page.close();

    const baselinePath = path.join(baselineDir, `${target.name}.png`);
    if (updateBaseline || !fs.existsSync(baselinePath)) {
      fs.copyFileSync(shotPath, baselinePath);
      console.log(`[ui-snapshots] baseline ${target.name} updated`);
      continue;
    }

    const comparison = comparePng(baselinePath, shotPath);
    const diffPath = path.join(diffDir, `${target.name}.png`);
    fs.writeFileSync(diffPath, PNG.sync.write(comparison.diff));

    if (comparison.ratio > mismatchToleranceRatio) {
      failures += 1;
      console.error(
        `[ui-snapshots] ${target.name} mismatch: ${(comparison.ratio * 100).toFixed(3)}% ` +
        `(threshold ${(mismatchToleranceRatio * 100).toFixed(3)}%). ` +
        `See ${path.relative(rootDir, diffPath)}`
      );
    } else {
      console.log(
        `[ui-snapshots] ${target.name} ok: ${(comparison.ratio * 100).toFixed(3)}% mismatch`
      );
    }
  }
} finally {
  if (browser) await browser.close();
  await new Promise((resolve) => server.close(resolve));
}

if (failures > 0) {
  process.exitCode = 1;
}

function comparePng(expectedPath, actualPath) {
  const expectedPng = PNG.sync.read(fs.readFileSync(expectedPath));
  const actualPng = PNG.sync.read(fs.readFileSync(actualPath));

  if (expectedPng.width !== actualPng.width || expectedPng.height !== actualPng.height) {
    throw new Error(
      `Snapshot dimensions differ for ${path.basename(expectedPath)}: ` +
      `expected ${expectedPng.width}x${expectedPng.height}, ` +
      `got ${actualPng.width}x${actualPng.height}`
    );
  }

  const diff = new PNG({ width: expectedPng.width, height: expectedPng.height });
  const mismatchedPixels = pixelmatch(
    expectedPng.data,
    actualPng.data,
    diff.data,
    expectedPng.width,
    expectedPng.height,
    { threshold: 0.1, includeAA: false }
  );

  return {
    diff,
    mismatchedPixels,
    ratio: mismatchedPixels / (expectedPng.width * expectedPng.height)
  };
}
