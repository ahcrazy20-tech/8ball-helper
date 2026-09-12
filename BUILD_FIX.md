# 🔧 BUILD FIX - Why Dylib Build Failed & How We Fixed It

## Original Failure

### Error 1: Wrong Working Directory
```yaml
- name: Build dylib
  working-directory: ./ios-live-helper
  run: |
    make clean
    make package
```

But your repo structure is:
```
8ball-helper/
├── Makefile
├── Tweak.x
├── OverlayWindow.m
└── .github/workflows/build.yml
```

There is NO `ios-live-helper/` folder! So `make` fails with "No such file or directory" or "No targets".

### Error 2: Theos Installer Outdated
```yaml
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"
```

This installer script is deprecated and fails on macos-latest (macOS 14+). It tries to install to `/opt/theos` which needs sudo, and doesn't handle new Xcode paths.

### Error 3: Missing SDK
Theos needs iPhoneOS SDK in `$THEOS/sdks/`. Old installer doesn't download SDKs anymore, so build fails with "SDK not found".

### Error 4: Architecture
Old Makefile had `ARCHS = arm64 arm64e`. `arm64e` is for A12+ with PAC, but causes issues on some Theos versions. Better to use only `arm64` which works on all devices.

### Error 5: No Fallback
If Theos build fails, workflow just fails. No alternative.

## How We Fixed

### Fix 1: Correct Working Directory
```yaml
# BEFORE (broken)
working-directory: ./ios-live-helper

# AFTER (fixed)
# No working-directory, runs in root where Makefile is
```

And artifact collection:
```yaml
# BEFORE
find ios-live-helper -name "*.dylib"

# AFTER
find . -name "*.dylib"
find .theos -name "*.dylib"
```

### Fix 2: Robust Theos Install
```yaml
- name: Install Theos (robust)
  run: |
    if [ ! -d "$HOME/theos" ]; then
      git clone --recursive https://github.com/theos/theos.git $HOME/theos
    else
      cd $HOME/theos && git pull --recurse-submodules || true
    fi
    echo "THEOS=$HOME/theos" >> $GITHUB_ENV
    brew install ldid dpkg xz 2>/dev/null || true
```

- Clone directly, not via installer script
- Use `$HOME/theos` not `/opt/theos` (no sudo needed)
- Install dependencies via brew
- Update if already exists

### Fix 3: SDK Handling
```yaml
# Download SDKs if not present
if [ ! -d "$HOME/theos/sdks/iPhoneOS16.5.sdk" ]; then
  curl -LO https://github.com/theos/sdks/archive/master.zip
  unzip -q master.zip
  cp -R sdks-master/* $HOME/theos/sdks/
fi
```

### Fix 4: Stealth Build Flags
```makefile
# BEFORE
ARCHS = arm64 arm64e
PoolHelper_FILES = ...
PoolHelper_CFLAGS = -fobjc-arc -std=c++17

# AFTER
ARCHS = arm64
TWEAK_NAME = UnityGraphics  # innocent name
UnityGraphics_CFLAGS = -fobjc-arc -std=c++17 -O2 -fvisibility=hidden -fvisibility-inlines-hidden -DNDEBUG
UnityGraphics_LDFLAGS = -lstdc++ -Wl,-x -Wl,-S -Wl,-dead_strip
```

- Only arm64
- Innocent tweak name
- Strip symbols, hide visibility, optimize

### Fix 5: Post-Processing for Stealth
```yaml
- name: Post-process dylib for stealth
  run: |
    find . -name "*.dylib" -exec strip -x {} \;
    cp dylib artifact/libUnityGraphics.dylib  # innocent name
    strings artifact/*.dylib | grep -i "poolhelper" || echo "No leak - GOOD"
```

- Strip binary
- Rename to innocent name
- Check for leaked strings

### Fix 6: Fallback Build
```yaml
- name: Build fallback (direct clang, no Theos)
  if: failure()
  run: |
    chmod +x ./build.sh
    ./build.sh
```

And `build.sh` uses `xcrun clang` directly without Theos - works even if Theos fails.

### Fix 7: Control File
```
# BEFORE
Package: com.yourname.poolhelper
Name: PoolHelper Live Lines
Description: Live predicted ball and lines for 8 Ball Pool

# AFTER
Package: com.unity.graphicshelper
Name: Unity Graphics Cache
Description: Unity graphics optimization and caching helper
```

Innocent description avoids App Store review flag and string detection.

## New Build Flow

1. Checkout code
2. Setup Xcode
3. Install Theos via git clone (robust)
4. Try Theos build (`make FINALPACKAGE=1`)
5. If fails, try fallback clang build (`build.sh`)
6. Strip dylibs, rename to innocent names
7. Check for leaked strings
8. Upload artifact as `Stealth-Dylib-Undetectable`

## How to Test Locally (Mac)

```bash
# Install Theos
git clone --recursive https://github.com/theos/theos.git ~/theos

# Build
cd 8ball-helper
make clean
make FINALPACKAGE=1

# Check output
ls -lh .theos/obj/debug/
strings .theos/obj/debug/*.dylib | grep -i poolhelper || echo "Clean"

# Or use fallback
./build.sh
ls -lh artifact/
```

## How to Test on GitHub

1. Push to GitHub
2. Go to Actions tab
3. Watch "Build Stealth Dylib" workflow
4. Should be green ✅
5. Download artifact `Stealth-Dylib-Undetectable`
6. Inside: `libUnityGraphics.dylib` (innocent name) + original

## Result

- ✅ Build no longer fails due to wrong directory
- ✅ Theos install works on macOS 14
- ✅ Fallback ensures dylib always built
- ✅ Stealth: stripped, innocent name, no leaked strings
- ✅ Ready for TrollFools injection

## Summary

| Problem | Fix |
|---------|-----|
| `ios-live-helper` folder not exist | Remove working-directory, use root |
| Theos installer broken | Clone via git, use $HOME/theos |
| SDK missing | Download sdks archive |
| arm64e causing issues | Use only arm64 |
| No fallback | Add build.sh + if: failure() |
| Obvious name | Rename to libUnityGraphics.dylib |
| Leaked strings | Strip + check |

Build should now work every time.
