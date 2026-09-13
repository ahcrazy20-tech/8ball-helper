#!/usr/bin/env bash
# inject.sh - inject the dylib into an 8 Ball Pool IPA (Sideloadly / ESign / TrollStore).
#
#   ./inject.sh <app.ipa> <libUnityGraphics.dylib> [-o patched.ipa] [options]
#
# Everything is done by tools/inject_ipa.py, a pure-Python 3 (stdlib only)
# Mach-O + IPA patcher.  That means:
#   * no optool / insert_dylib / brew needed (they are macOS-only and optool
#     produces broken arm64 binaries anyway - it writes 0xdeadbeef into the
#     dylib load command, which is exactly why injection used to "exit 1")
#   * no unzip / zip / strip / otool needed
#   * works on macOS, Linux, Windows (Git Bash / WSL) and on-device shells
#
# Run `./inject.sh --help` for the full option list.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

find_python() {
  local cand
  for cand in "${PYTHON:-}" python3 python; do
    [ -n "$cand" ] || continue
    if command -v "$cand" >/dev/null 2>&1 \
       && "$cand" -c 'import sys, zipfile, plistlib, struct; sys.exit(0 if sys.version_info >= (3, 7) else 1)' >/dev/null 2>&1; then
      printf '%s' "$cand"
      return 0
    fi
  done
  return 1
}

if ! PY="$(find_python)"; then
  cat >&2 <<'MSG'
[!] No Python 3.7+ found.

    This script patches the Mach-O binary itself, so optool / insert_dylib /
    brew / unzip are no longer required - but Python is:

      macOS / Linux : python3 is usually preinstalled (on macOS run
                      `xcode-select --install` once if it is missing)
      Windows       : install https://www.python.org/downloads/ and tick
                      "Add python.exe to PATH", then run this script from
                      Git Bash (https://git-scm.com/download/win)
      iPhone only   : skip this script and use TrollFools / Azula - they
                      inject on the device

    You can also point the script at a specific interpreter:  PYTHON=/path/to/python3 ./inject.sh ...
MSG
  exit 1
fi

TOOL="$HERE/tools/inject_ipa.py"
if [ ! -f "$TOOL" ]; then
  cat >&2 <<MSG
[!] Cannot find $TOOL

    inject.sh is only a wrapper - it needs tools/inject_ipa.py and
    tools/macho_inject.py from this repository next to it.
    Keep the folder layout intact (git clone the repo) and run it from there.
MSG
  exit 1
fi

case "${1:-}" in
  -h|--help|help)
    exec "$PY" "$TOOL" --help
    ;;
esac

if [ "$#" -lt 2 ]; then
  cat <<'MSG'
8 Ball Pool helper - IPA injector

Usage: ./inject.sh <app.ipa> <dylib> [options]

Examples:
  ./inject.sh 8BallPool.ipa libUnityGraphics.dylib
  ./inject.sh 8BallPool.ipa artifact/libUnityGraphics.dylib -o 8BallPool-patched.ipa
  ./inject.sh --help            show every option (arch, names, dry-run, ...)

Before you start:
  * Use a DECRYPTED ipa (TrollStore -> the game -> AppDump).  An untouched
    App Store ipa is still FairPlay-encrypted and the patched copy will not
    launch - the script refuses it for that reason.
  * The embedded code signature is removed on purpose: a modified binary
    cannot keep a valid one.  Sideloadly / ESign / TrollStore / ldid add a
    fresh signature when you install.
MSG
  exit 1
fi

exec "$PY" "$TOOL" "$@"
