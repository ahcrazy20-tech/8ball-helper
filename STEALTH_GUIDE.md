# 🥷 STEALTH GUIDE - How to be Undetectable

This guide explains how Miniclip detects cheats and how this dylib avoids detection.

## 1. Detection Vectors (How they catch you)

### A. Jailbreak Detection
- **How it works**: Game checks for Cydia, Sileo, /bin/bash, /etc/apt, canOpenURL for cydia://, fork() test, etc.
- **Our bypass**: 
  - We use TrollStore + TrollFools, NOT jailbreak. TrollStore uses CoreTrust bug, app runs as normal App Store app.
  - TrollFools injection doesn't leave jailbreak files. The game sees itself as legit App Store app.
  - We also check bundle and don't activate if jailbreak files exist (optional).

### B. Dylib Scanning
- **How it works**: Game can call `_dyld_image_count()` and `_dyld_get_image_name(i)` to list all loaded dylibs. If it sees `libPoolHelper.dylib`, instant ban.
- **Our bypass**:
  - **Innocent naming**: Final dylib is named `libUnityGraphics.dylib` or `libSwiftyPlugin.dylib` - looks like Unity plugin or Swift helper.
  - **Stripped symbols**: We use `-Wl,-x -Wl,-S` and `strip -x` to remove all symbol names. `nm` shows nothing.
  - **Hidden class names**: Classes are named `_UIFeedbackOverlay` and `_UGraphicsHelper` and `UnityGraphicsCache` - look like system/Unity classes.
  - **No obvious strings**: No "PoolHelper", "Cheat", "Ghost", "Hack" in binary. We use XOR obfuscation and avoid NSLog.
  - **Future**: Hook `_dyld_get_image_name` via fishhook to hide ourselves (experimental, not enabled by default because it can crash).

### C. String Scanning
- **How it works**: Anti-cheat scans binary for keywords like "ghost ball", "aimbot", "cheat".
- **Our bypass**:
  - All logs disabled in release (`ENABLE_LOGS=0`).
  - Strings built from fragments or XOR encrypted.
  - Control file says "Unity Graphics Cache - improves rendering" - innocent description.
  - Package ID `com.unity.graphicshelper` - looks legit.

### D. Overlay Detection
- **How it works**: Game can check `UIApplication.shared.windows.count` or look for extra UIWindow. If extra window found, flag.
- **Our bypass**:
  - **Low window level**: We use `UIWindowLevelStatusBar + 1` not `+100`. +100 is very suspicious.
  - **No makeKeyAndVisible**: Old code used `makeKeyAndVisible` which steals key window status - very detectable. We just set `hidden=NO`.
  - **Inject into existing view option**: In stealth mode we could add CAShapeLayer directly to Unity's view instead of new window (more stealth, implemented as option).
  - **Hide on screen capture**: If user starts screen recording (iOS 11+), we auto-hide. This prevents detection if Miniclip asks for screen recording permission or if user streams.

### E. Behavior Detection (Most Important)
- **How it works**: Server-side analysis of your aim. Perfect shots, 100% accuracy, impossible angles, same timing every shot = bot.
- **Our bypass**:
  - **Humanization**: Add small random jitter to ghost ball position (`HUMAN_JITTER_PIXELS = 1.5`) and angle noise.
  - **Random timing**: Prediction interval is `0.12 + random(-0.03, 0.03)` - not perfect 0.08.
  - **Don't show best shot always**: Randomly add `score += random(-2,2)` so sometimes it suggests second-best shot.
  - **Visual only**: We only draw lines, we don't auto-shoot. You still need to aim manually. This is much safer than auto-aim.
  - **Safety**: Only use in Play With Friends, not ranked.

### F. Screenshot / Stream Detection
- **How it works**: If you stream on Discord with overlay visible, friends report you. Also if game takes screenshot of its own view and sees overlay.
- **Our bypass**:
  - Tiny toggle button (10x10 dot, alpha 0.3) instead of big "Helper ON" button.
  - Panic gesture: 3-finger double tap instantly hides everything.
  - Auto-hide when `UIScreen.isCaptured` (screen recording active).
  - Option to hide on background.

### G. Anti-Debug
- **How it works**: Debugger can dump memory and find cheat. Also some anti-cheats check if debugger attached.
- **Our bypass**:
  - `ptrace(PT_DENY_ATTACH)` - prevents debugger attaching.
  - `sysctl` check for `P_TRACED` flag.
  - If debugger detected, we disable helper silently.

### H. Timing & Performance
- **How it works**: Cheat that uses 100% CPU is detectable via battery/thermal logs.
- **Our bypass**:
  - Interval 0.12s not 0.05s - less CPU.
  - Only run when app active.
  - Stop timer when background.

## 2. Stealth Features Implemented

| Feature | File | Status |
|---------|------|--------|
| Innocent dylib name | Makefile, build.sh | ✅ libUnityGraphics.dylib |
| Stripped symbols | Makefile LDFLAGS | ✅ |
| No NSLog in release | Config.h, Stealth.mm | ✅ |
| Innocent class names | OverlayWindow.h, PoolPredictor.h | ✅ |
| Low window level | OverlayWindow.m | ✅ |
| No makeKeyAndVisible | OverlayWindow.m | ✅ |
| Tiny hidden toggle | OverlayWindow.m | ✅ |
| Panic gesture (3-finger) | OverlayWindow.m | ✅ |
| Screen capture hide | OverlayWindow.m + Stealth.h | ✅ |
| Random delays | Tweak.x, Stealth.mm | ✅ |
| Humanized positions | PoolPredictor.mm, OverlayWindow.m | ✅ |
| Bundle whitelist | Stealth.mm | ✅ |
| Anti-debug ptrace | Stealth.mm | ✅ |
| Humanized timing | Tweak.x | ✅ |

## 3. How to Make Even More Stealthy (Advanced)

### Level 1 - Current (Good for friends)
- Use as is, only in Play With Friends
- Don't use 24/7, take breaks

### Level 2 - Extra Stealth (For cautious)
- Rename dylib to `libUnityPlugin.dylib` or `libFLEX.dylib` (FLEX is common dev tool)
- Use TrollFools injection (not IPA patching) - survives updates
- Enable `HIDE_ON_SCREEN_CAPTURE`
- Use panic gesture when friends look

### Level 3 - Paranoid (Maximum)
- Modify source to inject CAShapeLayer directly into Unity's GL view instead of UIWindow
  - Find Unity view: `[[UIApplication sharedApplication].keyWindow.subviews firstObject]`
  - Add layer there - no extra window at all
- Hook `_dyld_image_count` to hide dylib (requires fishhook)
- Use XOR for ALL strings (currently only critical ones)
- Compile with `-fstack-protector` and obfuscate control flow (use Obfuscator-LLVM)

## 4. Testing Stealth

After building, test:

```bash
# Check for leaked strings
strings libUnityGraphics.dylib | grep -i "pool\|helper\|cheat\|ghost\|hack"
# Should output nothing or minimal

# Check symbols
nm -gU libUnityGraphics.dylib
# Should be empty or only system symbols

# Check exports
otool -L libUnityGraphics.dylib
# Should only show system frameworks

# Check size - smaller is more stealthy
ls -lh libUnityGraphics.dylib
# Should be < 500KB
```

## 5. What NOT to do

- ❌ Don't name dylib `cheat.dylib`, `hack.dylib`, `PoolHelper.dylib` in final injection - rename to innocent name
- ❌ Don't use big visible button saying "CHEAT ON"
- ❌ Don't auto-shoot (that is easily detected server-side)
- ❌ Don't use in ranked/tournaments - high risk of manual review
- ❌ Don't share screenshots with overlay visible
- ❌ Don't leave NSLog enabled - logs can be retrieved

## 6. Summary

Stealth is layers:
1. **File stealth**: Innocent name, stripped, no strings
2. **Runtime stealth**: No extra window or hidden window, bundle check, anti-debug
3. **Visual stealth**: Tiny toggle, panic gesture, hide on capture
4. **Behavioral stealth**: Humanization, random timing, manual aim only

This dylib implements all 4 layers.

Next: Read SAFETY_GUIDE.md for how to use safely without ban.
