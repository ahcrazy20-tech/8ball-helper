# INJECT_FIX.md — why `inject.sh` said "failed to inject ... exited with code 1"

## 1. What actually failed

Reproduced locally with a dummy IPA:

```console
$ ./inject.sh 8BallPool.ipa libUnityGraphics.dylib
[*] Unzipping IPA...
[*] Found app: Payload/8 Ball Pool.app
[+] No obvious cheat strings - GOOD
[*] Strip failed, continuing
[*] Copying dylib to Payload/8 Ball Pool.app/
[!] optool/insert_dylib not found          <-- real cause
[*] Trying to install optool...
[!] Please install optool: brew install optool
[!] Or use Azula app on iPhone
$ echo $?
1
```

The script never patched the binary itself. It delegated that one step to
`optool` or `insert_dylib`, which are **macOS-only and not installed by
default**, and when `brew` was missing there was nothing left to do but `exit 1`.

Four more landmines were hiding behind that error:

| # | Problem | Consequence |
|---|---------|-------------|
| 1 | `optool` writes `0xdeadbeef` into the `LC_LOAD_DYLIB` timestamp field | dyld rejects the load command on arm64 → "injection worked but nothing loads" / crash. `insert_dylib` output is fine, but it is also not installed by default. |
| 2 | The embedded code signature was never handled | A patched binary keeps a signature that no longer matches → iOS refuses to launch the app ("Game crashes after injection" in the docs) |
| 3 | `$(basename $APP .app)` was used as the executable path | Breaks whenever `CFBundleExecutable` differs from the folder name |
| 4 | `rm -rf Payload` runs in the current directory, and `set -e`-less cleanup | Can delete an unrelated `Payload/` folder, and leaves the temp tree behind on error |

And the flow needed `unzip`, `zip`, `strip`, `optool`/`insert_dylib` and `brew` —
so it could not run on Windows, Linux, or on the phone itself.

## 2. What replaced it

Everything is now done by two pure-Python 3 (standard library only) tools.
No brew, no optool, no insert_dylib, no unzip/zip/strip/otool.

| File | Purpose |
|------|---------|
| `tools/macho_inject.py` | Mach-O editor. `verify <file>` = `otool -L` replacement (dylibs, rpaths, header padding, code signature, FairPlay encryption state). `inject <file> <dylib>` adds `LC_LOAD_DYLIB` **in the header padding**, using correct version fields (no `0xdeadbeef`), removes the stale `LC_CODE_SIGNATURE`, truncates the dead signature blob and fixes `__LINKEDIT` (and the fat header when a slice is shrunk). Refuses to guess: if there is no header padding it stops with a workable alternative. |
| `tools/inject_ipa.py` | IPA level. Reads `Info.plist` (bundle id, version, `CFBundleExecutable` — no name guessing), refuses a FairPlay-encrypted App Store binary, checks that the dylib has code for the app's slices, renames obvious dylib names in-bundle, repackages the IPA streaming every other entry untouched, then **re-opens the produced IPA and verifies the load command is really there**. |
| `inject.sh` | Thin wrapper: finds a Python 3.7+, prints help if called wrong, forwards the arguments. |
| `tests/` | 39 tests, run with `python3 -m unittest discover -s tests -t .` |

## 3. Usage

```bash
# same command as before
./inject.sh 8BallPool.ipa libUnityGraphics.dylib

# explicit output + all options
./inject.sh 8BallPool.ipa artifact/libUnityGraphics.dylib -o 8BallPool-patched.ipa
./inject.sh --help

# inspect any binary without otool
python3 tools/macho_inject.py verify "Payload/8 Ball Pool.app/8BallPool"
```

Then install the patched IPA with Sideloadly / ESign / TrollStore (they re-sign
it — required, because the old signature was invalidated by design).

## 4. Things it will now refuse, and why

| Message | Meaning | Fix |
|---------|---------|-----|
| `the app binary is still FairPlay-encrypted (cryptid=1)` | You are patching an untouched App Store IPA. It cannot run after patching. | Dump a decrypted copy (TrollStore → the app → AppDump), or inject on the device with TrollFools / Azula (`--allow-encrypted` overrides, for experiments only). |
| `no room for the new load command ... need N bytes of header padding` | That binary was linked with a fully packed load-command area. | Use TrollFools / Azula / Sideloadly (they grow the header), or `insert_dylib --inplace` on macOS. |
| `architecture mismatch: app has ['arm64'], dylib has ['x86_64']` | The dylib has no arm64 slice. | Rebuild the dylib for arm64 (the CI artifact already is). |
| `bad dylib: ... is not a Mach-O file` | You passed an `.ipa`, a `.zip` or a stub. | Pass the real `libUnityGraphics.dylib`. |
| `verification failed: @executable_path/... is not in the patched binary` | Should never happen — it means the IPA that was written is not the one that was patched. | Re-run; if it persists, open an issue with the log. |

## 5. How the injection itself works (short version)

1. The Mach-O header ends with `ncmds`/`sizeofcmds` and is followed by unused
   padding up to the first section's file offset.
2. A new `LC_LOAD_DYLIB` (`24 + len(name)+1`, 8-byte aligned) is written into
   that padding, `sizeofcmds`/`ncmds` are updated, the remaining padding is
   zeroed. Nothing else in the file moves — no relocation, no address fixups.
3. `LC_CODE_SIGNATURE` is removed (it is invalid the instant we write) and the
   signature blob is dropped from the end of `__LINKEDIT` when it is safe.
4. The bundle must be re-signed when it is installed. Sideloadly, ESign,
   TrollStore and `ldid` all do that.

## 6. Tests

```bash
python3 -m unittest discover -s tests -t .
```

* synthetic images from `tests/machofactory.py`: thin, packed header, fat
  (multi-slice), encrypted, chained fixups, big-endian, dylib and executable
* full IPA round-trips through `inject.sh` and `tools/inject_ipa.py`
* every file the injector writes is re-parsed by **LIEF** (an independent
  Mach-O parser) and checked for: the new library, the removed signature,
  unchanged load-command order, segments still inside the file
  (these checks skip themselves if `python3-lief` is not installed)
* cross-checked against 22 real arm64 binaries built by Apple's toolchain
  (macOS numpy wheel — including a 25 MB dylib and a single-arch fat wrapper):
  all patched, all still parse, all segments remain inside the file

## 7. Optional: run the suite in CI

Add this step to `.github/workflows/build.yml` (right before the Theos build
step) to make the build fail when an injector regression appears. GitHub only
accepts workflow edits from a token/app with the `workflows` permission, so
this one is left for you to apply:

```yaml
      - name: Run the IPA injector test suite
        run: |
          python3 -m unittest discover -s tests -t . -v
```

