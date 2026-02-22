# UI Snapshot Tests

This folder contains Playwright-based visual regression tests for the
`ortho_viewer` widget shell at two viewport sizes:

- `desktop` (`1280x900`)
- `mobile` (`480x900`)

## Commands

From the repository root:

```bash
npm install
npm run ui:snapshots:update   # create/update baselines
npm run ui:snapshots          # compare against baselines
npm run ui:a11y               # run accessibility checks (axe + keyboard)
npm run ui:check              # snapshots + accessibility
```

If Playwright cannot launch the bundled browser on your machine, set one of:

```bash
ORTHOVIEWER_PW_CHANNEL=chrome npm run ui:check
# or
ORTHOVIEWER_PW_EXECUTABLE="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" npm run ui:check
```

## Output folders

- `tests/ui/baseline/` committed baseline snapshots
- `tests/ui/actual/` current run snapshots (gitignored)
- `tests/ui/diff/` per-pixel diffs for failed comparisons (gitignored)
- `tests/ui/.tmp/` generated fixture widget page (gitignored)
