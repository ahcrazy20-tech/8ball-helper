# Build Dylib WITHOUT Mac (on iPhone only)

If you don't have a Mac, you can still do it 100% on iPhone:

> **Update:** you no longer need `optool`/`insert_dylib`/`brew` to patch an IPA.
> `./inject.sh <ipa> <dylib>` does the Mach-O patching in pure Python
> (`tools/inject_ipa.py`), so it also works from Windows/Linux and from an
> on-device shell with Python 3 (e.g. a-Shell). See `INJECT_FIX.md`.

## Option 1: Azula (Easiest, no PC)
1. Install Azula.ipa from https://github.com/Paisseon/AzulaApp/releases
2. Download libPoolHelper.dylib from this repo (Releases section)
3. Download 8 Ball Pool IPA (decrypted) - use TrollStore's AppDump to dump your own App Store version
4. Open Azula -> Select IPA -> Inject Dylib -> Choose libPoolHelper.dylib -> Patch
5. Install patched IPA with TrollStore

This is the method mentioned in reddit guide for jailed injection: https://www.reddit.com/r/jailbreakdevelopers/comments/g8rssx/how_can_i_inject_dylib_into_ipa_so_it_runs_with/

## Option 2: ESign + TrollFools (No PC, keeps auto-update)
This is what iOSGods users want: dylib format using TrollFools

1. Install ESign from https://esign.yyyue.xyz
2. Install TrollStore (if iOS 14-17) from https://github.com/opa334/TrollStore
3. Install TrollFools from Havoc repo in Sileo
4. Build dylib on-device using Theos installed via Sileo (install Theos dependencies)
5. Or download prebuilt dylib from GitHub Releases
6. Open TrollFools -> Select 8 Ball Pool (installed from App Store) -> Inject -> Select dylib
7. Done! Game will show LIVE lines, and you can still update from App Store.

Advantage of TrollFools: You don't need to wait for IPA owner to update - you use normal game auto update and always use the already injected dylib file.

## Option 3: Use my Web Helper (No injection needed)
If you can't do dylib injection, use the web helper I built for you:

1. I can host it as a PWA
2. You take screenshot in 8 Ball Pool (Power + Volume Up)
3. Open helper in Safari, upload screenshot, it shows prediction lines
4. Go back to game and shoot

Not LIVE but 100% safe, no ban risk, works on any iOS version.

Which option do you want me to build for you?
