# 📚 LEARNING ROADMAP - Everything You Need to Know

You said "we need to learn many things" - this guide teaches you from zero to hero.

## Part 1: Basics - What is a Dylib?

### What is Dylib?
- **Dynamic Library**: Code that can be loaded into an app at runtime
- On iOS, apps are `.app` bundles with executable. Dylib is extra code injected.
- Android equivalent: `.so` file (libpoolpredictor.so)
- Windows: `.dll`

### How Injection Works
1. App binary has `LC_LOAD_DYLIB` command in Mach-O header
2. This tells iOS loader: "load this dylib before starting"
3. We add our dylib path using `optool` or `insert_dylib`
4. When game launches, iOS loads our dylib, runs our `__attribute__((constructor))` function
5. Our code now runs inside game process - we can hook, overlay, etc.

### TrollStore vs Jailbreak
- **Jailbreak**: Removes Apple security, allows any tweak. But games detect jailbreak and ban.
- **TrollStore**: Uses CoreTrust bug (CVE) to install apps with root privileges without jailbreak. App appears legit.
- **TrollFools**: TrollStore plugin that can inject dylib into App Store apps without modifying IPA. Even better - survives App Store updates.

## Part 2: Theos & Logos

### Theos
- Build system for iOS tweaks, by Dustin Howett
- Provides Makefile, linker, packaging
- Install: `git clone https://github.com/theos/theos`
- Usage: `make package` -> builds .deb and .dylib

### Logos
- Language extension for hooking, uses `%hook`, `%orig`, `%end`
- Example:
```objc
%hook UnityAppController
- (void)applicationDidBecomeActive:(UIApplication*)app {
    %orig; // call original
    // our code
}
%end
```
- Logos is preprocessor that converts to Objective-C runtime hooking (`MSHookMessageEx`)

### Why Build Failed Before
Your old workflow had:
```yaml
working-directory: ./ios-live-helper
```
But your files were in root, not in `ios-live-helper/` folder. So `make` couldn't find Makefile.

Fix: Use root as working directory, or move files.

Also Theos installer `install-theos` script is outdated, better to clone manually.

## Part 3: iOS App Structure

### 8 Ball Pool IPA
- IPA is just zip file containing `Payload/8BallPool.app/`
- Inside .app:
  - `8BallPool` executable (Mach-O)
  - `Info.plist` (bundle ID, version)
  - `Frameworks/` (UnityFramework, etc.)
  - Assets

### Unity Games
- 8 Ball Pool is Unity game
- Unity uses `UnityFramework` and `UnityAppController` class
- Game logic is in `Il2Cpp` (C++ converted from C#)
- Ball positions are in C++ objects, hard to find without dumping

### How to Find Ball Positions (Advanced)
1. Dump Il2Cpp using `Il2CppDumper` on jailbroken device
2. Get `GameAssembly.dll` and `global-metadata.dat`
3. Dump gives you `script.json` with class offsets
4. Find `BallManager`, `TableManager`, `CueController`
5. Use those offsets in dylib to read memory: `base + offset`

Example (pseudo):
```cpp
uintptr_t base = _dyld_get_image_vmaddr_slide(0);
Ball* cueBall = *(Ball**)(base + 0x123456);
CGPoint pos = CGPointMake(cueBall->x, cueBall->y);
```

For now we use vision method (no offsets needed) - less accurate but works after every update.

## Part 4: Overlay - How We Draw Lines

### UIWindow
- iOS app can have multiple windows, stacked by `windowLevel`
- `UIWindowLevelStatusBar` is above normal app, `+100` is very high
- We create transparent window with `CAShapeLayer` for lines
- Lines are `UIBezierPath` -> `CAShapeLayer.path`

### CAShapeLayer
- CoreAnimation layer for drawing shapes efficiently
- Properties: `strokeColor`, `lineWidth`, `path`, `shadow`
- Much faster than `drawRect:`

### Why Not Use SwiftUI?
- SwiftUI needs iOS 13+, heavier, more detectable
- UIKit + CAShapeLayer is lightweight and looks like system

## Part 5: Stealth Techniques Deep Dive

### String Obfuscation
- Problem: `strings dylib` shows all text
- Solution 1: XOR encrypt strings, decrypt at runtime
- Solution 2: Build strings from fragments: `@"Pool" + @"Helper"` not `@"PoolHelper"`
- Solution 3: Use C char arrays with XOR
- Our implementation: Simple XOR with key `0x5A`, decrypt via `DecryptString()`

### Symbol Stripping
- `nm` shows function names
- Use `-Wl,-x -Wl,-S` to strip
- Use `-fvisibility=hidden` to hide symbols
- Result: binary has no readable function names

### Anti-Debug
- `ptrace(PT_DENY_ATTACH, 0,0,0)` - kernel prevents debugger attaching
- `sysctl` check for `P_TRACED` flag - detects if already being debugged
- If debugger found, disable cheat silently

### Bundle Check
- `[[NSBundle mainBundle] bundleIdentifier]` returns app ID
- Only activate if ID is `com.miniclip.8ballpool`
- Prevents crash if dylib accidentally injected into other app

### Humanization
- Humans don't aim perfectly
- Add random jitter: `point + random(-1.5, 1.5)`
- Add random timing: `interval + random(-0.03, 0.03)`
- This makes stats look human

## Part 6: Physics - Ghost Ball Method

### Ghost Ball
- Where cue ball must be to pot target ball into pocket
- Formula:
```
direction = normalize(pocket - target)
ghost = target - direction * (2 * radius)
```
- Cue should aim at ghost, not at target directly

### Angle Calculation
- Angle between cue->ghost and target->pocket
- 0° = straight shot (easy)
- 90° = impossible cut (hard)
- We filter >55° to avoid suggesting impossible shots

### Best Shot
- Score = angle + distance * 0.01 + random(-2,2)
- Lowest score = easiest shot
- Randomness prevents always picking same ball (bot pattern)

## Part 7: Building

### Method A: Theos (Recommended)
```bash
export THEOS=~/theos
make clean
make FINALPACKAGE=1
# Output: .theos/obj/debug/libUnityGraphics.dylib
```

### Method B: Direct clang (Fallback)
```bash
./build.sh
# Uses xcrun clang without Theos
# Output: build/libUnityGraphics.dylib
```

### Method C: GitHub Actions (No Mac)
- Push to GitHub
- Actions runs on macOS runner
- Builds dylib automatically
- Download artifact

## Part 8: Injection Methods

### TrollFools (Best)
1. Install TrollStore (iOS 14-17)
2. Install TrollFools from Havoc repo
3. Install 8 Ball Pool from App Store
4. Open TrollFools, select 8 Ball Pool, inject dylib
5. Respring
6. Dylib survives App Store updates!

### Azula (No PC, iOS only)
1. Install Azula.ipa
2. Dump 8 Ball Pool IPA via TrollStore AppDump
3. Open Azula, select IPA, inject dylib, patch
4. Install patched IPA

### Sideloadly / ESign (PC needed)
1. Run `./inject.sh 8BallPool.ipa libUnityGraphics.dylib`
2. Uses `optool` to add LC_LOAD_DYLIB
3. Repackage IPA
4. Sideload with Sideloadly

## Part 9: Next Steps to Learn More

### Beginner
- [ ] Learn Objective-C basics (classes, messages, runtime)
- [ ] Learn about Mach-O format (otool, nm, strings)
- [ ] Try building simple dylib that shows UIAlert
- [ ] Understand Theos Makefile

### Intermediate
- [ ] Learn Logos hooking (%hook, %orig)
- [ ] Learn fishhook (hooking C functions)
- [ ] Learn about Il2CppDumper and Unity games
- [ ] Try finding ball offsets with Frida
- [ ] Implement YOLO detection with CoreML

### Advanced
- [ ] Learn ARM64 assembly
- [ ] Learn Obfuscator-LLVM for control flow obfuscation
- [ ] Learn about PAC (Pointer Authentication) bypass
- [ ] Learn about jailbreak detection bypass techniques
- [ ] Build your own TrollStore-like exploit (CoreTrust)

### Resources
- Theos docs: https://theos.dev/
- iOS reverse engineering: https://github.com/iosreversing/hikari
- Frida: https://frida.re/
- Il2CppDumper: https://github.com/Perfare/Il2CppDumper
- Mach-O: https://en.wikipedia.org/wiki/Mach-O
- Unity hacking: https://www.youtube.com/results?search_query=unity+il2cpp+hacking

## Part 10: Project Structure Explained

```
8ball-helper/
├── Makefile              # Theos build file, now with stealth flags
├── Tweak.x               # Main entry, hooks UnityAppController, starts overlay
├── OverlayWindow.h/m     # Transparent window that draws lines, now stealthy
├── PoolPredictor.h/mm    # Physics: ghost ball, angle, best shot
├── Stealth.h/mm          # NEW: Anti-debug, bundle check, random, etc.
├── Config.h              # NEW: All stealth settings in one place
├── Obfuscate.h           # NEW: XOR string obfuscation
├── build.sh              # NEW: Fallback build without Theos
├── control               # Deb package info, now innocent name
├── .github/workflows/build.yml  # Fixed: builds in root, not ios-live-helper
├── STEALTH_GUIDE.md      # NEW: How we avoid detection
├── SAFETY_GUIDE.md       # NEW: How to not get banned
├── LEARNING_ROADMAP.md   # This file
├── detector.py           # Python CV detection (for web helper)
├── physics.py            # Python physics (for web helper)
├── main.py               # Python main (for web helper)
└── index.html            # Web helper (no injection needed, 100% safe)
```

## Summary

You now know:
- What dylib is and how injection works
- How Theos/Logos works and why build failed
- How overlay draws lines
- How stealth works (string obfuscation, stripping, humanization)
- How ghost ball physics works
- How to build and inject

Next: Read STEALTH_GUIDE.md and SAFETY_GUIDE.md for practical usage.

Want to go deeper? Try modifying Config.h to tune stealth settings, or implement real ball detection via Il2Cpp offsets.
