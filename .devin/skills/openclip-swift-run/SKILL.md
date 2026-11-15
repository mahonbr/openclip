---
name: openclip-swift-run
description: Run or repair OpenClip's Santa-safe Swift interpreter runner
argument-hint: "[--check] [app args...]"
allowed-tools:
  - read
  - grep
  - glob
  - exec
triggers:
  - user
  - model
---

Run or repair the interpreter runner for OpenClip. Use this when the user wants to launch the app
locally without producing an executable (Santa/EDR constraints), or when `scripts/dev_swift_run.sh`
fails.

Read `docs/developer-guide/swift-runner.md` before changing the runner. Never patch the repository
sources: dev patches live in `scripts/swiftrun/patches.json` and apply only to the `.swiftrun/` mirror.
Never replace the runner with `swiftc` — that links a new unsigned executable and defeats the purpose.

## Run

```bash
./scripts/dev_swift_run.sh                 # launch the app
./scripts/dev_swift_run.sh --check         # prepare + build, no launch (use after app changes)
./scripts/dev_swift_run.sh --version       # smoke test
```

App flags pass through (`--dump-logs`, `--dump-settings`, `--category=…`). `--clean` rebuilds the
mirror from zero; `--verbose` shows the full build log. Warm runs take ~2s.

## Repair, by failure

| Symptom | Fix |
| :--- | :--- |
| `error: patch anchor no longer exists in <file>` | App source moved. Update the exact `find` string in `scripts/swiftrun/patches.json` against the new source, keeping behavior identical. Delete the patch if the guard is no longer needed. Never relax the matcher. |
| `no such module 'X'` | A direct SPM dependency was added. Add its `(identity, url, product, package)` to `DIRECT_PACKAGES` in `scripts/swiftrun/prepare.py`. |
| Launch crash: `bundleProxyForCurrentProcess is nil` | A new eager bundle-only API. Add a guarded exact-string patch in `patches.json`, plus a row in the runner doc's patch table. |
| Any other build failure | Read `.swiftrun/build.log`, rerun with `--verbose`, try `--clean` for stale state. |

After editing `patches.json`, rerun; a successful run must print no patch errors. Keep the doc's patch
table in step with the JSON.

## Verify

1. `./scripts/dev_swift_run.sh --check` exits 0 and prints `Runner OK`.
2. `./scripts/dev_swift_run.sh --version` exits 0.
3. `file .swiftrun/.build/debug/* | grep 'Mach-O.*executable'` prints nothing (dylibs are shared
   libraries, and the directory is a symlink).
4. Optional UI smoke test: `timeout 8 ./scripts/dev_swift_run.sh`, then confirm startup with
   `./scripts/dev_swift_run.sh --dump-logs --category=extensions`.

Do not add a root `Package.swift`, commit `.swiftrun/`, or change app sources for the runner. The run
uses the `com.openclip.OpenClip.swiftdev` settings domain; reset it with
`defaults delete com.openclip.OpenClip.swiftdev`.
