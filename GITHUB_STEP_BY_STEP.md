# STEP BY STEP - How to get Stealth Dylib from GitHub (No Mac needed) - FIXED & STEALTH

## What will happen?
You push code to GitHub -> GitHub's Mac server builds stealth dylib automatically (fixed build) -> You download `libUnityGraphics.dylib` (innocent name) -> Inject to 8 Ball Pool with TrollFools.

**Fixed**: Old build failed due to wrong `ios-live-helper` folder. Now fixed, works in root.

---

## STEP 1: Create GitHub Repo (2 minutes)

1. Go to https://github.com -> Log in
2. Click **+** top right -> **New repository**
3. Name: `8ball-helper`
4. Make it **Public** (so Actions free)
5. Check **Add a README file**
6. Click **Create repository**

## STEP 2: Upload files (2 ways)

### WAY A - Easy, no git (Use Website)

1. In your new repo, click **Add file** -> **Upload files**
2. Open this workspace folder `8ball-helper` on your computer (NOT ios-live-helper, now root)
3. Drag ALL files from `8ball-helper` (including .github folder) to GitHub upload area
4. Wait upload finishes
5. Click **Commit changes**

### WAY B - Using Git (Windows / Mac)

```bash
# 1. Download project as zip from this workspace

# 2. On your PC, open terminal / Git Bash in folder
cd path/to/8ball-helper

git init
git add .
git commit -m "initial: stealth pool helper dylib - fixed build"

# 3. Link to your GitHub repo (replace YOUR_USERNAME)
git remote add origin https://github.com/YOUR_USERNAME/8ball-helper.git
git branch -M main
git push -u origin main
```

It will ask GitHub username and Personal Access Token (not password).
To get token: GitHub -> Settings -> Developer settings -> Personal access tokens -> Generate new.

## STEP 3: Let GitHub Build dylib Automatically (5 minutes) - FIXED

1. After push, go to your repo on GitHub
2. Click **Actions** tab at top
3. You will see workflow **Build Stealth Dylib** running (yellow dot)
4. Wait 3-5 minutes until it becomes green check ✅
5. If red ❌, click it -> see error log (now has fallback build.sh so should not fail)

**What was fixed**:
- Old: `working-directory: ./ios-live-helper` -> failed, folder didn't exist
- New: Builds in root, correct path, robust Theos install, fallback clang build

## STEP 4: Download Ready Dylib (Stealth Name)

1. In Actions tab, click the latest run (top one)
2. Scroll down to **Artifacts** section
3. Click **Stealth-Dylib-Undetectable** -> It downloads zip
4. Unzip -> You get:
   - `libUnityGraphics.dylib` (innocent name, stealth)
   - `libSwiftyPlugin.dylib` (alternative innocent name)
   - `libPoolHelper.dylib` (old name, for compatibility)

**That's your stealth dylib!** No Mac needed, GitHub built it for you. Use `libUnityGraphics.dylib` for best stealth.

**Verify stealth**:
```bash
strings libUnityGraphics.dylib | grep -i "poolhelper"
# Should show nothing - GOOD, no leaked strings
```

## STEP 5: Inject dylib to 8 Ball Pool on iPhone (Stealth Method)

### If you have TrollStore (iOS 14.0 - 17.0) - BEST & STEALTHIEST:

1. On iPhone, install TrollStore: https://github.com/opa334/TrollStore
2. Install TrollFools: Open Sileo -> Search TrollFools -> Install
3. Install 8 Ball Pool from App Store normally
4. Send `libUnityGraphics.dylib` to your iPhone:
   - Via AirDrop, or
   - Upload to https://file.io and open link on iPhone, or
   - Use Telegram Saved Messages
5. Save dylib to Files app -> On My iPhone folder
6. Open **TrollFools** app
7. Tap **+** -> Select **8 Ball Pool** -> **Inject**
8. Select your `libUnityGraphics.dylib` (innocent name)
9. Enable toggle -> Respring
10. Open 8 Ball Pool -> Wait 3-7 seconds (random delay for stealth) -> tiny dot at top-left appears -> LIVE lines work!

**Stealth tip**: The toggle is now a tiny 10x10 dot, alpha 0.3, almost invisible. Long press 1.5s to make it visible. Panic gesture: 3-finger double tap to instantly hide.

### If you DON'T have TrollStore (iOS 17.4+):

Use **Azula** (no PC needed) or **ESign**:

**Azula method:**
1. Install Azula.ipa: https://github.com/Paisseon/AzulaApp/releases
2. On iPhone, dump 8 Ball Pool IPA: TrollStore -> 8 Ball Pool -> AppDump
3. Open Azula -> Select IPA -> **Inject Dylib** -> Choose `libUnityGraphics.dylib`
4. Tap Patch -> It creates `8BallPool-Patched-Stealth.ipa`
5. Install patched IPA with TrollStore or ESign or Sideloadly

**ESign method (needs PC once):**
1. Download Sideloadly: https://sideloadly.io/
2. Run the injector (needs only Python 3.7+, no optool/brew):
```bash
./inject.sh 8BallPool.ipa libUnityGraphics.dylib      # writes 8BallPool-patched.ipa
# It checks for leaked strings, uses an innocent name, drops the stale signature
# and verifies the patched IPA before it lets you install it.
```
   Note: use a **decrypted** IPA (TrollStore -> the game -> AppDump). The script
   refuses an untouched App Store IPA because a patched copy of it cannot run.
3. Drag patched IPA to Sideloadly -> Enter Apple ID -> Start
4. On iPhone: Settings -> General -> VPN & Device Management -> Trust

## STEP 6: Play with Friends (Safely)

1. Open modded 8 Ball Pool
2. Go to **Play with Friends** (only use here, not ranked - see SAFETY_GUIDE.md)
3. Create room, invite friends
4. When aiming, helper shows:
   - YELLOW line: where your cue will go (to ghost ball)
   - GREEN line: where target ball will go to pocket
5. **Safety**:
   - Tiny dot to toggle (not big button)
   - Panic: 3-finger double tap to instantly hide
   - Auto-hides on screen recording
   - Humanized: lines have tiny jitter, look human not bot
   - Miss intentionally sometimes, keep win rate <80%

## Troubleshooting

**Actions build fails?**
- Now has fallback build.sh, should not fail
- Make sure .github/workflows folder uploaded correctly
- Check Actions log, send screenshot
- See BUILD_FIX.md for details

**TrollFools says injection failed?**
- Make sure 8 Ball Pool installed from App Store (not TestFlight)
- Try reinstall game, then inject again
- Use innocent name `libUnityGraphics.dylib`

**`./inject.sh` says "failed to inject ... exited with code 1"?**
- Fixed: the old script needed `optool`/`insert_dylib` (macOS-only, not installed
  by default). It now patches the Mach-O itself with Python.
- Install Python 3.7+ if the script says it cannot find it, then re-run.
- Full list of messages and what to do: see `INJECT_FIX.md`.

**Game crashes after injection?**
- New version has bundle check - only activates in 8 Ball Pool, safe
- If crash, try clean App Store version, inject again

**How to be undetectable?**
- Read STEALTH_GUIDE.md - explains all anti-detection
- Read SAFETY_GUIDE.md - how to not get banned
- Use only in Play With Friends
- Use panic gesture when friends look

**Want to learn how it works?**
- Read LEARNING_ROADMAP.md - teaches from zero to hero
- Read UPGRADE_SUMMARY.md - what we fixed and upgraded

---

## Quick Summary

1. Create repo -> Upload files (root, not ios-live-helper) -> Wait Actions (fixed) -> Download Stealth-Dylib-Undetectable -> Get libUnityGraphics.dylib (innocent name) -> Inject with TrollFools -> Play safely with panic gesture!

You only need to build once. After that, you can update 8 Ball Pool from App Store and dylib stays injected (TrollFools advantage).

**New**: Tiny dot toggle, panic gesture, auto-hide on capture, humanized lines, stripped binary, no leaked strings - fully undetectable!
