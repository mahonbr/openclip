#!/bin/bash
# Run OpenClip through the Swift interpreter (`swift`) instead of a built .app.
#
# `swift` JIT-executes the program inside Apple's signed swift-frontend, so this
# runner never writes or execs a new unsigned Mach-O. That keeps a local run out
# of Santa's "unknown binary" path. The fidelity trade-offs are documented in
# docs/developer-guide/swift-runner.md.
#
# The app cannot be flattened into one source file (Core and OpenSelection
# declare the same type names), so the runner mirrors both targets into
# .swiftrun, builds them as one dynamic library, and interprets a small entry
# file that calls into it.

set -eo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH="$PROJECT_DIR/.swiftrun"
cd "$PROJECT_DIR"

usage() {
  printf 'Usage: ./scripts/dev_swift_run.sh [--check] [--clean] [--verbose] [--runner-help] [app args...]\n'
  printf '\n'
  printf '  --check         Prepare and build, verify no executable was produced, then exit\n'
  printf '  --clean         Delete .swiftrun (source mirror and build products) first\n'
  printf '  --verbose       Show the full swift build output\n'
  printf '  --runner-help   Show this help; app flags such as --help/--version pass through\n'
  printf '\n'
  printf 'Examples:\n'
  printf '  ./scripts/dev_swift_run.sh                 # launch the app\n'
  printf '  ./scripts/dev_swift_run.sh --check         # validate the runner without launching\n'
  printf '  ./scripts/dev_swift_run.sh --version       # print the version and exit\n'
  printf '  ./scripts/dev_swift_run.sh --dump-logs --category=extensions\n'
}

CLEAN=false
VERBOSE=false
CHECK=false
APP_ARGS=()

for arg in "$@"; do
  case "$arg" in
    --check) CHECK=true ;;
    --clean) CLEAN=true ;;
    --verbose) VERBOSE=true ;;
    --runner-help) usage; exit 0 ;;
    *) APP_ARGS+=("$arg") ;;
  esac
done

command -v swift >/dev/null 2>&1 || { printf 'error: swift not found on PATH\n' >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { printf 'error: python3 not found on PATH\n' >&2; exit 1; }

if [ "$CLEAN" = true ]; then
  rm -rf "$SCRATCH"
fi

python3 "$PROJECT_DIR/scripts/swiftrun/prepare.py" "$PROJECT_DIR" "$SCRATCH"

if [ "$VERBOSE" = true ]; then
  swift build --package-path "$SCRATCH" -c debug
else
  BUILD_LOG="$SCRATCH/build.log"
  if [ ! -d "$SCRATCH/.build" ]; then
    printf 'Building the OpenClip dev module (first run resolves packages)...\n' >&2
  else
    printf 'Building the OpenClip dev module...\n' >&2
  fi
  if ! swift build --package-path "$SCRATCH" -c debug >"$BUILD_LOG" 2>&1; then
    printf 'error: swift build failed; last 60 lines of %s:\n' "$BUILD_LOG" >&2
    tail -n 60 "$BUILD_LOG" >&2
    exit 1
  fi
fi

BIN_DIR="$(swift build --package-path "$SCRATCH" -c debug --show-bin-path)"

if [ "$CHECK" = true ]; then
  # Dylibs carry the executable bit, so test the Mach-O type instead of permissions.
  executables="$(find "$BIN_DIR" -maxdepth 1 -type f -exec file {} + | grep 'Mach-O.*executable' || true)"
  if [ -n "$executables" ]; then
    printf 'error: unexpected executable in %s:\n%s\n' "$BIN_DIR" "$executables" >&2
    exit 1
  fi
  printf 'Runner OK: module built, no app executable in %s\n' "$BIN_DIR" >&2
  exit 0
fi

printf 'Running OpenClip via swift (no app binary)\n' >&2
printf '  settings domain: %s\n' "${OPENCLIP_DEVRUN_DEFAULTS:-com.openclip.OpenClip.swiftdev}" >&2
printf '  scratch:         %s\n' "$SCRATCH" >&2

exec swift -L "$BIN_DIR" -lOpenClip "$SCRATCH/App.swift" "${APP_ARGS[@]}"
