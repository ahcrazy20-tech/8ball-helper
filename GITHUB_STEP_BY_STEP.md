# STEP BY STEP - How to get ready dylib from GitHub (No Mac needed)

## What will happen?
You push my code to GitHub -> GitHub's Mac server builds dylib automatically -> You download ready dylib -> Inject to 8 Ball Pool with TrollFools.

---

## STEP 1: Create GitHub Repo (2 minutes)

1. Go to https://github.com -> Log in
2. Click **+** top right -> **New repository**
3. Name: `8ball-helper`
4. Make it **Public** (so Actions free)
5. Check **Add a README file**
6. Click **Create repository**

## STEP 2: Upload my files (2 ways)

### WAY A - Easy, no git (Use Website)

1. In your new repo, click **Add file** -> **Upload files**
2. Open this workspace folder `ios-live-helper` on your computer
3. Drag ALL files from `ios-live-helper` (including .github folder) to GitHub upload area
4. Wait upload finishes
5. Click **Commit changes**

### WAY B - Using Git (Windows / Mac)

If you have Git installed:

```bash
# 1. Download my project as zip from this workspace
# Or clone if I gave you link

# 2. On your PC, open terminal / Git Bash in folder
cd path/to/ios-live-helper

git init
git add .
git commit -m "initial: pool helper dylib"

# 3. Link to your GitHub repo (replace YOUR_USERNAME)
git remote add origin https://github.com/YOUR_USERNAME/8ball-helper.git
git branch -M main
git push -u origin main
```

It will ask GitHub username and Personal Access Token (not password).
To get token: GitHub -> Settings -> Developer settings -> Personal access tokens -> Generate new.

## STEP 3: Let GitHub Build dylib Automatically (5 minutes)

1. After push, go to your repo on GitHub
2. Click **Actions** tab at top
3. You will see workflow **Build PoolHelper dylib** running (yellow dot)
4. Wait 3-5 minutes until it becomes green check ✅
5. If red ❌, click it -> see error log

## STEP 4: Download Ready Dylib

1. In Actions tab, click the latest run (top one)
2. Scroll down to **Artifacts** section
3. Click **PoolHelper-dylib** -> It downloads zip
4. Unzip -> You get `libPoolHelper.dylib` (and .deb)

**That's your ready dylib!** No Mac needed, GitHub built it for you.

## STEP 5: Inject dylib to 8 Ball Pool on iPhone

### If you have TrollStore (iOS 14.0 - 17.0) - BEST:

1. On iPhone, install TrollStore: https://github.com/opa334/TrollStore
2. Install TrollFools: Open Sileo -> Search TrollFools -> Install
3. Install 8 Ball Pool from App Store normally
4. Send `libPoolHelper.dylib` to your iPhone:
   - Via AirDrop, or
   - Upload to https://file.io and open link on iPhone, or
   - Use Telegram Saved Messages
5. Save dylib to Files app -> On My iPhone folder
6. Open **TrollFools** app
7. Tap **+** -> Select **8 Ball Pool** -> **Inject**
8. Select your `libPoolHelper.dylib`
9. Enable toggle -> Respring
10. Open 8 Ball Pool -> You see **Helper ON** button floating! LIVE lines work!

### If you DON'T have TrollStore (iOS 17.4+ or no jailbreak):

Use **Azula** (no PC needed) or **ESign**:

**Azula method:**
1. Install Azula.ipa: https://github.com/Paisseon/AzulaApp/releases
2. On iPhone, dump 8 Ball Pool IPA: TrollStore -> 8 Ball Pool -> AppDump
   - If no TrollStore, download decrypted IPA from your PC using Sideloadly tools
3. Open Azula -> Select IPA -> **Inject Dylib** -> Choose `libPoolHelper.dylib`
4. Tap Patch -> It creates `8BallPool-Patched.ipa`
5. Install patched IPA with TrollStore or ESign or Sideloadly

**ESign method (needs PC once):**
1. Download Sideloadly: https://sideloadly.io/
2. Run `inject.sh` script I gave you (on Mac) OR use Azula on iPhone
3. Drag patched IPA to Sideloadly -> Enter Apple ID -> Start
4. On iPhone: Settings -> General -> VPN & Device Management -> Trust

## STEP 6: Play with Friends

1. Open modded 8 Ball Pool
2. Go to **Play with Friends**
3. Create room, invite friends
4. When aiming, helper shows:
   - YELLOW = cue to ghost ball
   - GREEN = target to pocket
5. Tap Helper ON/OFF to hide when friends look

## Troubleshooting

**Actions build fails?**
- Make sure .github/workflows folder uploaded correctly
- Check Actions log, send me screenshot

**TrollFools says injection failed?**
- Make sure 8 Ball Pool installed from App Store (not TestFlight)
- Try reinstall game, then inject again

**Game crashes after injection?**
- My template uses vision method, no offsets, so should not crash
- If crash, the offset method is wrong - use vision-only version (comment out memory hooks)

**Want me to build for you?**
Push to GitHub and give me repo link, I can check Actions log.

---

## Quick Video Summary

1. Create repo -> Upload files -> Wait Actions -> Download dylib -> Inject with TrollFools -> Play!

You only need to build once. After that, you can update 8 Ball Pool from App Store and dylib stays injected (TrollFools advantage).
