import fs from "node:fs";
import path from "node:path";
import http from "node:http";
import { spawnSync } from "node:child_process";
import { chromium } from "playwright";

export function ensureCleanDir(dir) {
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
}

export function runCommand(cmd, args, options = {}) {
  const result = spawnSync(cmd, args, {
    stdio: "inherit",
    env: { ...process.env, ...(options.env || {}) }
  });
  if (result.status !== 0) {
    throw new Error(`Command failed (${cmd} ${args.join(" ")})`);
  }
}

export function createStaticServer(root) {
  return http.createServer((req, res) => {
    const reqUrl = new URL(req.url, "http://127.0.0.1");
    let relPath = decodeURIComponent(reqUrl.pathname);
    if (relPath === "/") relPath = "/index.html";

    const fullPath = path.resolve(path.join(root, relPath));
    if (!fullPath.startsWith(path.resolve(root))) {
      res.writeHead(403);
      res.end("Forbidden");
      return;
    }

    if (!fs.existsSync(fullPath) || !fs.statSync(fullPath).isFile()) {
      res.writeHead(404);
      res.end("Not found");
      return;
    }

    const ext = path.extname(fullPath).toLowerCase();
    res.writeHead(200, { "Content-Type": mimeForExt(ext) });
    fs.createReadStream(fullPath).pipe(res);
  });
}

export async function launchChromiumWithFallback({
  rootDir,
  headless = true,
  debug = false
}) {
  const strategies = resolveLaunchStrategies(rootDir);
  const failures = [];

  for (const strategy of strategies) {
    const launchOptions = { headless, ...strategy.options };
    try {
      if (debug) {
        console.log(
          `[ui-tests] launching with ${strategy.name}: ${JSON.stringify(launchOptions)}`
        );
      }
      const browser = await chromium.launch(launchOptions);
      console.log(`[ui-tests] launched browser with ${strategy.name}`);
      return browser;
    } catch (error) {
      const firstLine = String(error && error.message ? error.message : error)
        .split("\n")[0];
      failures.push(`- ${strategy.name}: ${firstLine}`);
      if (debug) {
        console.warn(`[ui-tests] launch failed for ${strategy.name}`);
      }
    }
  }

  throw new Error(
    "Unable to launch Chromium for UI tests.\n" +
    failures.join("\n") +
    "\nTry setting ORTHOVIEWER_PW_EXECUTABLE to a local Chrome/Chromium binary " +
    "or ORTHOVIEWER_PW_CHANNEL=chrome."
  );
}

function mimeForExt(ext) {
  switch (ext) {
    case ".html":
      return "text/html; charset=utf-8";
    case ".js":
      return "application/javascript; charset=utf-8";
    case ".css":
      return "text/css; charset=utf-8";
    case ".json":
      return "application/json; charset=utf-8";
    case ".png":
      return "image/png";
    case ".svg":
      return "image/svg+xml";
    default:
      return "application/octet-stream";
  }
}

function resolveLaunchStrategies(rootDir) {
  const strategies = [];

  const envExecutable = process.env.ORTHOVIEWER_PW_EXECUTABLE;
  if (envExecutable) {
    if (fs.existsSync(envExecutable)) {
      pushStrategy(strategies, "env executable", {
        executablePath: envExecutable
      });
    } else {
      console.warn(
        `[ui-tests] ORTHOVIEWER_PW_EXECUTABLE not found: ${envExecutable}`
      );
    }
  }

  const envChannel = process.env.ORTHOVIEWER_PW_CHANNEL;
  if (envChannel) {
    pushStrategy(strategies, `channel ${envChannel}`, { channel: envChannel });
  }

  const bundledExecutables = resolveBundledChromiumExecutables(rootDir);
  for (const candidate of bundledExecutables) {
    pushStrategy(strategies, candidate.name, {
      executablePath: candidate.path
    });
  }

  const systemExecutables = resolveSystemChromeExecutables();
  for (const candidate of systemExecutables) {
    pushStrategy(strategies, candidate.name, {
      executablePath: candidate.path
    });
  }

  pushStrategy(strategies, "playwright default", {});
  pushStrategy(strategies, "channel chrome", { channel: "chrome" });

  return strategies;
}

function pushStrategy(strategies, name, options) {
  const key = JSON.stringify(options);
  if (strategies.some((item) => JSON.stringify(item.options) === key)) return;
  strategies.push({ name, options });
}

function resolveBundledChromiumExecutables(rootDir) {
  const browsersRoot = path.join(rootDir, ".playwright-browsers");
  if (!fs.existsSync(browsersRoot)) return [];

  const candidates = [];
  const preferredArch = process.arch === "arm64" ? ["arm64", "x64"] : ["x64", "arm64"];

  const chromiumDirs = fs.readdirSync(browsersRoot)
    .filter((name) => name.startsWith("chromium-"))
    .sort()
    .reverse();

  for (const dirName of chromiumDirs) {
    const dirPath = path.join(browsersRoot, dirName);
    for (const arch of preferredArch) {
      for (const executable of chromiumBundleExecutableCandidates(dirPath, arch)) {
        if (fs.existsSync(executable)) {
          candidates.push({
            name: `bundled chromium ${arch} (${dirName})`,
            path: executable
          });
        }
      }
    }
  }

  const shellDirs = fs.readdirSync(browsersRoot)
    .filter((name) => name.startsWith("chromium_headless_shell-"))
    .sort()
    .reverse();

  for (const dirName of shellDirs) {
    const dirPath = path.join(browsersRoot, dirName);
    for (const arch of preferredArch) {
      for (const executable of headlessShellExecutableCandidates(dirPath, arch)) {
        if (fs.existsSync(executable)) {
          candidates.push({
            name: `bundled headless shell ${arch} (${dirName})`,
            path: executable
          });
        }
      }
    }
  }

  return candidates;
}

function chromiumBundleExecutableCandidates(baseDir, arch) {
  if (process.platform === "darwin") {
    return [
      path.join(baseDir, `chrome-mac-${arch}`, "Chromium.app", "Contents", "MacOS", "Chromium"),
      path.join(baseDir, `chrome-mac-${arch}`, "Chromium")
    ];
  }
  if (process.platform === "linux") {
    return [path.join(baseDir, "chrome-linux", "chrome")];
  }
  if (process.platform === "win32") {
    return [path.join(baseDir, "chrome-win", "chrome.exe")];
  }
  return [];
}

function headlessShellExecutableCandidates(baseDir, arch) {
  if (process.platform === "darwin") {
    return [path.join(baseDir, `chrome-headless-shell-mac-${arch}`, "chrome-headless-shell")];
  }
  if (process.platform === "linux") {
    return [path.join(baseDir, "chrome-headless-shell-linux64", "chrome-headless-shell")];
  }
  if (process.platform === "win32") {
    return [path.join(baseDir, "chrome-headless-shell-win64", "chrome-headless-shell.exe")];
  }
  return [];
}

function resolveSystemChromeExecutables() {
  if (process.platform === "darwin") {
    const pathCandidates = [
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
      "/Applications/Chromium.app/Contents/MacOS/Chromium",
      "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
      "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"
    ];
    return pathCandidates
      .filter((candidate) => fs.existsSync(candidate))
      .map((candidate) => ({
        name: `system browser (${path.basename(candidate)})`,
        path: candidate
      }));
  }

  if (process.platform === "linux") {
    const pathCandidates = [
      "/usr/bin/google-chrome",
      "/usr/bin/chromium",
      "/usr/bin/chromium-browser"
    ];
    return pathCandidates
      .filter((candidate) => fs.existsSync(candidate))
      .map((candidate) => ({
        name: `system browser (${path.basename(candidate)})`,
        path: candidate
      }));
  }

  return [];
}
