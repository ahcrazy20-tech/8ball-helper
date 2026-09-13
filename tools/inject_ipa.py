#!/usr/bin/env python3
"""
inject_ipa.py - inject a dylib into an IPA, in pure Python (stdlib only).

This replaces the old shell implementation that needed `unzip`, `zip`, `strip`,
`otool` and one of `optool` / `insert_dylib` (macOS-only, usually not installed,
and `optool` breaks arm64 binaries).  It runs anywhere Python 3.7+ runs: macOS,
Linux, Windows (Git Bash / cmd / PowerShell) and even on-device shells such as
a-Shell on iOS.

Usage:
    ./inject.sh <app.ipa> <dylib> [options]

What it does, in order:
    1. opens the IPA, finds Payload/*.app, reads Info.plist (bundle id, version,
       CFBundleExecutable - never guess the binary name from the folder name)
    2. refuses to patch a FairPlay-encrypted (App Store) binary unless forced
    3. checks the dylib and the app binary are compatible (arch + filetype),
       warns about detectable names/strings
    4. adds `@executable_path/<name>` as an LC_LOAD_DYLIB to every slice and
       drops the now-stale code signature (see tools/macho_inject.py)
    5. copies the dylib into the .app and repackages the IPA
    6. re-opens the produced IPA and verifies the load command really is there
"""

from __future__ import annotations

import argparse
import os
import plistlib
import posixpath
import shutil
import stat
import sys
import tempfile
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from macho_inject import (  # noqa: E402
    MachOError,
    images_for_file,
    inject_dylib,
    inspect_file,
    is_macho,
)

STEALTH_NAME = "libUnityGraphics.dylib"
SUSPICIOUS_NAME_BITS = ("poolhelper", "pool_helper", "8ball", "8_ball", "cheat",
                        "hack", "ghost", "aimbot", "modmenu", "esp")
SUSPICIOUS_STRING_BITS = (b"poolhelper", b"pool_helper", b"8ball", b"cheat",
                          b"hack", b"aimbot", b"modmenu")


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------


class IpaError(Exception):
    pass


def _app_dirs(names):
    return sorted({n.split("/")[1] for n in names
                   if n.startswith("Payload/") and n.count("/") >= 2
                   and n.split("/")[1].endswith(".app")})


def _pick_app(zf):
    apps = _app_dirs(zf.namelist())
    if not apps:
        raise IpaError("no Payload/*.app found - is this really an IPA?")
    if len(apps) > 1:
        print("[!] IPA contains several apps, using %s (others: %s)"
              % (apps[0], ", ".join(apps[1:])))
    return "Payload/" + apps[0]


def _read_info_plist(zf, app_dir):
    path = app_dir + "/Info.plist"
    try:
        raw = zf.read(path)
    except KeyError:
        raise IpaError("missing %s" % path)
    try:
        return plistlib.loads(raw)
    except Exception as exc:  # pragma: no cover - malformed plists
        raise IpaError("cannot parse %s: %s" % (path, exc))


def _find_executable(zf, app_dir, info):
    names = set(zf.namelist())
    exe = info.get("CFBundleExecutable")
    cand = posixpath.join(app_dir, exe) if exe else None
    if cand and cand in names:
        return cand

    # fall back: look for a real Mach-O file directly inside the .app
    for name in sorted(names):
        if name.count("/") != 2 or not name.startswith(app_dir + "/"):
            continue
        with zf.open(name) as fh:
            if is_macho(fh.read(4), 0):
                print("[!] CFBundleExecutable=%r not found in the zip; using %s"
                      % (exe, name))
                return name
    raise IpaError(
        "cannot find the app executable inside %s (CFBundleExecutable=%r)"
        % (app_dir, exe)
    )


def _check_dylib(path):
    if not os.path.isfile(path):
        raise IpaError("dylib not found: %s" % path)
    try:
        data, images, _kind = images_for_file(path)
    except MachOError as exc:
        raise IpaError("bad dylib: %s" % exc)

    kinds = {img.filetype_name for img in images}
    if "MH_DYLIB" not in kinds:
        print("[!] %s is %s, not MH_DYLIB - it will probably not load"
              % (os.path.basename(path), "/".join(sorted(kinds))))

    # leaky strings: informational only, never fatal
    lowered = bytes(data).lower()
    hits = [b.decode() for b in SUSPICIOUS_STRING_BITS if b in lowered]
    if hits:
        print("[!] the dylib contains obvious strings: %s" % ", ".join(hits))
        print("    rebuild with stealth flags if that matters to you")

    return images


def _stealth_name(path):
    base = os.path.basename(path)
    low = base.lower()
    if any(bit in low for bit in SUSPICIOUS_NAME_BITS):
        print("[*] %s is an obvious name, will be installed as %s"
              % (base, STEALTH_NAME))
        return STEALTH_NAME
    return base


def _archsets(images):
    return {img.arch for img in images}


# --------------------------------------------------------------------------
# main flow
# --------------------------------------------------------------------------


def run(args):
    ipa = args.ipa
    dylib = args.dylib

    if not os.path.isfile(ipa):
        raise IpaError("IPA not found: %s" % ipa)
    dylib_images = _check_dylib(dylib)

    out = args.out or os.path.splitext(ipa)[0] + "-patched.ipa"
    if os.path.abspath(out) == os.path.abspath(ipa):
        raise IpaError("refusing to overwrite the input IPA; pass -o <output.ipa>")

    name = args.name or _stealth_name(dylib)
    install_name = args.install_name or "@executable_path/%s" % name

    workdir = tempfile.mkdtemp(prefix="inject-ipa-")
    try:
        with zipfile.ZipFile(ipa) as zf:
            app_dir = _pick_app(zf)
            info = _read_info_plist(zf, app_dir)
            exe_entry = _find_executable(zf, app_dir, info)

            print("[*] IPA      : %s" % ipa)
            print("[*] app      : %s" % app_dir)
            print("[*] bundle   : %s %s"
                  % (info.get("CFBundleIdentifier", "?"),
                     info.get("CFBundleShortVersionString", "")))
            print("[*] binary   : %s" % exe_entry)
            print("[*] dylib    : %s -> %s" % (os.path.basename(dylib), name))

            # extract the binary so the patcher can work on a real file
            exe_path = os.path.join(workdir, "app_binary")
            with zf.open(exe_entry) as src, open(exe_path, "wb") as dst:
                shutil.copyfileobj(src, dst)

            try:
                before = inspect_file(exe_path)
            except MachOError as exc:
                raise IpaError("cannot read the app binary: %s" % exc)

            exe_arches = set()
            encrypted = []
            for sl in before["slices"]:
                exe_arches.add(sl["arch"])
                enc = sl.get("encryption")
                if enc and enc["cryptid"]:
                    encrypted.append(sl["arch"])

            if encrypted and not args.allow_encrypted:
                raise IpaError(
                    "the app binary is still FairPlay-encrypted (cryptid=1 on %s).\n"
                    "    This is an untouched App Store IPA, so the patched copy will\n"
                    "    not run even though the injection itself succeeds.\n"
                    "    Fix: dump a decrypted copy first (TrollStore -> the game ->\n"
                    "    AppDump, if you have TrollStore), or inject on the device with\n"
                    "    TrollFools / Azula, which work on the installed app.\n"
                    "    Pass --allow-encrypted to patch anyway."
                    % ", ".join(sorted(encrypted))
                )
            if encrypted:
                print("[!] binary is encrypted (cryptid=1) - continuing because "
                      "--allow-encrypted was given")

            dylib_arches = _archsets(dylib_images)
            common = exe_arches & dylib_arches
            if not common:
                raise IpaError(
                    "architecture mismatch: app has %s, dylib has %s"
                    % (sorted(exe_arches), sorted(dylib_arches))
                )
            if exe_arches - dylib_arches:
                print("[!] app also has %s slices; the dylib has no code for them "
                      "(those slices will fail to load it)"
                      % sorted(exe_arches - dylib_arches))

            if args.dry_run:
                report = inject_dylib(exe_path, install_name, arch=args.arch,
                                      dry_run=True)
                for sl in report["slices"]:
                    print("[*] %s: padding %d bytes" % (sl["arch"], sl["header_padding"]))
                print("[*] dry run - no IPA written")
                return 0

            # ---- patch ----
            inject_dylib(
                exe_path,
                install_name,
                strip_codesig=not args.keep_codesig,
                arch=args.arch,
            )

            # ---- repackage ----
            tmp_out = out + ".part"
            with zipfile.ZipFile(ipa) as zin, zipfile.ZipFile(
                tmp_out, "w", zipfile.ZIP_DEFLATED
            ) as zout:
                dylib_entry = posixpath.join(app_dir, name)
                existing = {i.filename for i in zin.infolist()}

                def _copy_file(source, target_info):
                    with open(source, "rb") as fh, zout.open(target_info, "w") as dst:
                        shutil.copyfileobj(fh, dst)

                for item in zin.infolist():
                    if item.filename == exe_entry:
                        info_out = zipfile.ZipInfo(item.filename, item.date_time)
                        info_out.compress_type = zipfile.ZIP_DEFLATED
                        info_out.external_attr = item.external_attr
                        _copy_file(exe_path, info_out)
                    elif item.filename == dylib_entry:
                        print("[*] replacing the existing %s" % name)
                        info_out = zipfile.ZipInfo(item.filename, item.date_time)
                        info_out.compress_type = zipfile.ZIP_DEFLATED
                        info_out.external_attr = (stat.S_IFREG | 0o644) << 16
                        _copy_file(dylib, info_out)
                    elif item.is_dir():
                        zout.writestr(item, b"")
                    else:
                        # stream every other entry untouched (IPAs are big)
                        with zin.open(item) as src, zout.open(item, "w") as dst:
                            shutil.copyfileobj(src, dst)

                if dylib_entry not in existing:
                    info_out = zipfile.ZipInfo(dylib_entry, (2024, 1, 1, 0, 0, 0))
                    info_out.compress_type = zipfile.ZIP_DEFLATED
                    info_out.external_attr = (stat.S_IFREG | 0o644) << 16
                    _copy_file(dylib, info_out)

            os.replace(tmp_out, out)

        # ---- verify the produced IPA ----
        print("[*] verifying %s" % out)
        with zipfile.ZipFile(out) as zf:
            names = set(zf.namelist())
            if posixpath.join(app_dir, name) not in names:
                raise IpaError("verification failed: %s missing from the output IPA"
                               % posixpath.join(app_dir, name))
            verify_path = os.path.join(workdir, "verify_binary")
            with zf.open(exe_entry) as src, open(verify_path, "wb") as dst:
                shutil.copyfileobj(src, dst)

        after = inspect_file(verify_path)
        ok = False
        for sl in after["slices"]:
            if install_name in sl["dylibs"]:
                ok = True
            print("[*] %s: %d dylibs, code signature: %s"
                  % (sl["arch"], len(sl["dylibs"]),
                     "present" if sl["code_signature"] else "removed"))
        if not ok:
            raise IpaError("verification failed: %s is not in the patched binary"
                           % install_name)

        print("")
        print("[+] Done: %s" % out)
        print("[*] The app now loads %s" % install_name)
        print("[*] The old code signature is gone, so the bundle MUST be re-signed "
              "when you install it:")
        print("    - Sideloadly / ESign: automatic")
        print("    - TrollStore / TrollFools: automatic")
        print("    - ldid (jailbroken/macOS): ldid -S \"%s/**\" " % app_dir)
        return 0
    finally:
        if args.keep_workdir:
            print("[*] work directory kept: %s" % workdir)
        else:
            shutil.rmtree(workdir, ignore_errors=True)


def main(argv=None):
    parser = argparse.ArgumentParser(
        prog="inject_ipa.py",
        description="Inject a dylib into an IPA (pure Python, no optool needed).",
    )
    parser.add_argument("ipa", help="the .ipa to patch")
    parser.add_argument("dylib", help="the .dylib to inject")
    parser.add_argument("-o", "--out", default=None,
                        help="output IPA (default: <input>-patched.ipa)")
    parser.add_argument("--name", default=None,
                        help="filename to use inside the .app (default: dylib name)")
    parser.add_argument("--install-name", default=None,
                        help="load command path (default @executable_path/<name>)")
    parser.add_argument("--arch", default=None, help="only patch this slice")
    parser.add_argument("--keep-codesig", action="store_true",
                        help="leave LC_CODE_SIGNATURE alone (it will be invalid)")
    parser.add_argument("--allow-encrypted", action="store_true",
                        help="patch even if the binary is FairPlay-encrypted")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--keep-workdir", action="store_true")
    args = parser.parse_args(argv)

    try:
        return run(args)
    except IpaError as exc:
        print("[!] %s" % exc, file=sys.stderr)
        return 1
    except MachOError as exc:
        print("[!] %s" % exc, file=sys.stderr)
        return 1
    except KeyboardInterrupt:  # pragma: no cover
        return 130


if __name__ == "__main__":
    sys.exit(main())
