#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import AxeBuilder from "@axe-core/playwright";
import {
  ensureCleanDir,
  runCommand,
  createStaticServer,
  launchChromiumWithFallback
} from "./shared.mjs";

const args = new Set(process.argv.slice(2));
const headed = args.has("--headed");
const debugLaunch = args.has("--debug-launch");

const rootDir = process.cwd();
const uiDir = path.join(rootDir, "tests", "ui");
const fixtureDir = path.join(uiDir, ".tmp", "fixture");

ensureCleanDir(fixtureDir);
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

try {
  browser = await launchChromiumWithFallback({
    rootDir,
    headless: !headed,
    debug: debugLaunch
  });

  const page = await browser.newPage({
    viewport: { width: 1280, height: 900 }
  });

  await page.goto(baseUrl, { waitUntil: "networkidle" });
  await page.waitForSelector(".ortho-shell", { timeout: 15000 });
  await page.waitForSelector('[data-status="world"]', { timeout: 15000 });
  await page.waitForTimeout(400);

  await assertKeyboardNavigation(page);
  await assertRequiredA11yAttributes(page);
  const axeResults = await runAxeScan(page);

  if (axeResults.violations.length > 0) {
    printAxeViolations(axeResults.violations);
    process.exitCode = 1;
  } else {
    console.log("[ui-a11y] no axe violations in .ortho-shell");
  }

  await page.close();
} finally {
  if (browser) await browser.close();
  await new Promise((resolve) => server.close(resolve));
}

async function assertKeyboardNavigation(page) {
  const viewer = page.locator(".ortho-viewer-inner");
  await viewer.focus();

  const before = await page.evaluate(getCurrentCoord);
  if (!Array.isArray(before) || before.length < 3) {
    throw new Error("[ui-a11y] could not read initial crosshair coordinate");
  }

  await page.keyboard.press("ArrowRight");
  await page.waitForTimeout(120);
  const after = await page.evaluate(getCurrentCoord);
  if (!Array.isArray(after) || after.length < 3 || after[0] === before[0]) {
    throw new Error("[ui-a11y] keyboard navigation failed: ArrowRight did not move X");
  }

  console.log("[ui-a11y] keyboard navigation check passed");
}

async function assertRequiredA11yAttributes(page) {
  const status = await page.evaluate(() => {
    const shell = document.querySelector(".ortho-shell");
    const sidebar = document.querySelector(".ortho-sidebar");
    const viewerContainer = document.querySelector(".ortho-viewer-container");
    const viewerInner = document.querySelector(".ortho-viewer-inner");
    const statusBar = document.querySelector(".ortho-status-bar");
    return {
      shellPresent: !!shell,
      sidebarRole: sidebar ? sidebar.getAttribute("role") : null,
      viewerContainerRole: viewerContainer ? viewerContainer.getAttribute("role") : null,
      viewerInnerTabIndex: viewerInner ? viewerInner.tabIndex : null,
      statusRole: statusBar ? statusBar.getAttribute("role") : null,
      statusLive: statusBar ? statusBar.getAttribute("aria-live") : null
    };
  });

  if (!status.shellPresent) throw new Error("[ui-a11y] .ortho-shell not found");
  if (status.sidebarRole !== "complementary") throw new Error("[ui-a11y] sidebar role mismatch");
  if (status.viewerContainerRole !== "region") throw new Error("[ui-a11y] viewer container role mismatch");
  if (status.viewerInnerTabIndex !== 0) throw new Error("[ui-a11y] viewer is not keyboard focusable");
  if (status.statusRole !== "status") throw new Error("[ui-a11y] status bar role mismatch");
  if (status.statusLive !== "polite") throw new Error("[ui-a11y] status bar aria-live mismatch");

  console.log("[ui-a11y] semantic attribute checks passed");
}

async function runAxeScan(page) {
  return new AxeBuilder({ page })
    .include(".ortho-shell")
    .analyze();
}

function printAxeViolations(violations) {
  console.error(`[ui-a11y] found ${violations.length} axe violation(s)`);
  for (const violation of violations) {
    console.error(`- ${violation.id}: ${violation.help}`);
    console.error(`  impact: ${violation.impact || "unknown"}`);
    for (const node of violation.nodes) {
      const target = Array.isArray(node.target) ? node.target.join(", ") : String(node.target);
      console.error(`  target: ${target}`);
    }
  }
}

function getCurrentCoord() {
  for (const node of document.querySelectorAll("*")) {
    if (node && node.__ortho_state__ && node.__ortho_state__.state && node.__ortho_state__.state.viewer) {
      const coord = node.__ortho_state__.state.viewer.currentCoord;
      return coord ? coord.slice() : null;
    }
  }
  return null;
}
