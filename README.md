# 🎱 iOS 8 Ball Pool - STEALTH Dylib Helper (Undetectable) - Wizard/Ninja Features + Ball-by-Ball Safety

**No Jailbreak | TrollStore / TrollFools | All Wizard & Ninja Features | Safer Than Them | Newest 56.29.x Support**

> **Latest Upgrade**: All Wizard & Ninja features included (Best Shot Solver, Bank Shots, Cue Leave, Scratch Warning, Combo Chain, Long Guidelines, Mod Menu) + **Ball-by-Ball Safety Mode** (your request: play ball by ball, not auto 3-ball) + support for newest 8 Ball Pool version.

## 🥷 What's New - Wizard/Ninja + Safety

| Wizard/Ninja | Old Stealth Dylib | New (Wizard/Ninja + Safer) |
|--------------|-------------------|----------------------------|
| Paid, Telegram key | Free | **Free & open source** |
| Big mod menu button | Tiny dot | Tiny dot + **hidden mod menu (4-finger tap)** |
| Auto best shot ON (risky) | Ball-by-ball only | **Ball-by-Ball ON by default (safe) + option for auto** |
| Combo chain 3-5 balls ON (risky) | No combo | **Combo Chain OFF by default (safe) + option to enable 3-ball** |
| Bank shots | No | **Bank shots (1-cushion) - OFF by default** |
| Cue Leave + Scratch Warning | No | **Yes - Scratch Warning ON by default (safety)** |
| Supports old version only | Vision detection | **Supports newest 56.29.x via vision + calibration** |
| Obvious dylib name | Innocent name | **Innocent name + stripped** |

## 📂 Project Structure (Wizard/Ninja Features)

```
8ball-helper/
├── Makefile                # Includes ModMenu.m, Wizard/Ninja features
├── Tweak.x                 # Wizard/Ninja: ball-by-ball, best shot, bank, cue leave, combo chain + safety
├── OverlayWindow.h/m       # Wizard: long guidelines, bank line (cyan), cue leave (white dotted), scratch (red), combo (orange), cushion path
├── PoolPredictor.h/mm      # Wizard: ghost ball, best shot solver, bank shot (reflection), cue leave, scratch check, combo chain 3-ball, cushion path
├── ModMenu.h/m             # NEW: Hidden mod menu (4-finger tap) - Wizard-like menu but stealth, ball-by-ball toggle, combo chain toggle (your safety request)
├── Stealth.h/mm            # Anti-debug, bundle check, newest version support
├── Config.h                # All features: FEATURE_BEST_SHOT, BANK, CUE_LEAVE, SCRATCH, COMBO, BALL_BY_BALL, etc.
├── Obfuscate.h             # XOR obfuscation
├── build.sh                # Fallback build with Wizard/Ninja features
├── control                 # Innocent package
├── .github/workflows/build.yml  # Fixed + robust + fallback
├── WIZARD_NINJA_FEATURES.md # NEW: All Wizard/Ninja features comparison
├── STEALTH_GUIDE.md
├── SAFETY_GUIDE.md
├── LEARNING_ROADMAP.md
├── BUILD_FIX.md
└── UPGRADE_SUMMARY.md
```

## 🎯 All Wizard & Ninja Features Included

### Core (Safe, Always On):
- ✅ Ghost ball + long guidelines (extended 100px)
- ✅ Ball-by-ball mode (your safety request) - **ON by default** - you select one ball & pocket, no auto 3-ball search
- ✅ Manual pocket nomination

### Advanced (Optional, Toggle via Hidden Menu, OFF by default for safety):
- ✅ **Best Shot Solver** (Wizard) - sweeps all angles, ranks by potting margin
- ✅ **Bank Shots** (Wizard Bank Shots) - 1-cushion reflection, cyan dashed line
- ✅ **Cue Leave Prediction** (Wizard Cue Ball Leave) - white dotted where cue stops
- ✅ **Scratch Warning** (Wizard) - red circle if cue will scratch - **ON by default (safety)**
- ✅ **Combo & Carom Chain** (Wizard Combo Chain) - 2-3 balls in one shot with numbering (orange) - **OFF by default (your safety request: not search for 3 balls) + option to enable**
- ✅ **Info HUD** - ball numbers, angle, score
- ✅ **Long Guidelines** - extended lines
- ✅ **Table Calibration** - for newest version 56.29.x support

### Safety (More Than Wizard/Ninja):
- Ball-by-ball ON by default (Wizard auto ON = risky)
- Combo chain OFF by default (Wizard ON = risky) - option to enable 3-ball
- Tiny dot toggle, not big menu
- Panic: 3-finger double tap = instant hide
- Auto-hide on screen capture + background
- Humanization: ±1.5px jitter, ±0.5° angle, random timing 0.12±0.03s
- Stripped, innocent name `libUnityGraphics.dylib`, no logs, anti-debug

See `WIZARD_NINJA_FEATURES.md` for full comparison.

## 🎮 How to Use - Ball-by-Ball Safety Mode (Your Request)

### Default Safe Mode (Ball-by-Ball ON) - SAFEST:
1. Open game, wait 3-7s random delay, tiny dot at top-left
2. **Ball-by-Ball Mode is ON by default** - helper shows **only ONE ball** at a time
3. No auto search for 3 balls - looks human, not bot
4. You manually aim, no auto-play

### If You Want 3-Ball Combo (Risky Option - Your Option):
1. **4-finger tap** to open hidden mod menu (or 2-finger triple tap)
2. Enable **Combo Chain 3-Ball (RISKY)** toggle - it warns you
3. Now shows 2-3 ball chains with numbering (like Wizard)
4. Use only in Play With Friends with trusted friends

### Mod Menu (4-finger tap):
- 🎯 Ball-by-Ball Mode (SAFE): ON = you select (safe), OFF = auto best (risky) - **Keep ON**
- ⭐ Best Shot Solver: OFF by default
- 🔄 Bank Shots: OFF by default
- ⚪ Cue Leave: OFF by default
- 🚩 Scratch Warning: ON by default (safety)
- 🔗 Combo Chain 3-Ball (RISKY): OFF by default - your option for 3-ball
- 📊 Info HUD: OFF
- 📏 Long Guidelines: ON
- Sliders: Line thickness, Humanization, Max angle
- 📐 Calibrate Table: for newest version 56.29.x
- Reset to Safe button

## 🔧 Build Fixed + Wizard/Ninja

**GitHub Actions**: Push → Actions → Download `Stealth-Dylib-Undetectable` → `libUnityGraphics.dylib` with all Wizard/Ninja features

**Local Mac**:
```bash
git clone --recursive https://github.com/theos/theos.git ~/theos
export THEOS=~/theos
make clean && make FINALPACKAGE=1
# Output: .theos/obj/debug/libUnityGraphics.dylib

# Fallback without Theos:
./build.sh
# Output: artifact/libUnityGraphics.dylib
```

## 🥷 Stealth Features (More Than Wizard/Ninja)

- Innocent name `libUnityGraphics.dylib` + stripped + no strings
- Bundle whitelist: `com.miniclip.8ballpool`, `com.miniclip.8ballpoolmult` (newest), beta
- Anti-debug ptrace + sysctl
- Random delay 3-7.5s, low window level +1
- Tiny dot + panic gesture + auto-hide on capture/background
- Humanization + visual only (no auto-play by default)
- No network calls (Wizard phones home for key)

See `STEALTH_GUIDE.md`.

## 🛡️ Safety

- **Only Play With Friends / Practice** - Very low risk
- **Never ranked/tournaments** - High risk
- **Ball-by-Ball ON** = safest (no 3-ball auto search)
- **Combo Chain OFF** = safest (enable only if you want risky 3-ball)
- Panic: 3-finger double tap
- Miss intentionally, win rate <80%

See `SAFETY_GUIDE.md`.

## 📲 Injection (No Jailbreak, Supports Newest 56.29.x)

### TrollFools (Recommended, survives App Store updates):
1. Install TrollStore + TrollFools
2. Install 8 Ball Pool from App Store (newest 56.29.x supported)
3. Download `libUnityGraphics.dylib` from Actions
4. TrollFools → Select 8 Ball Pool → Inject → Respring
5. Open game → tiny dot → 4-finger tap for menu → Ball-by-Ball ON (default safe)

### Azula / Sideloadly:
```bash
./inject.sh 8BallPool.ipa libUnityGraphics.dylib
```

## 📚 Docs

- `WIZARD_NINJA_FEATURES.md` - All Wizard/Ninja features + safety comparison + ball-by-ball mode
- `STEALTH_GUIDE.md` - Anti-detection
- `SAFETY_GUIDE.md` - How to not get banned
- `LEARNING_ROADMAP.md` - Learn everything
- `BUILD_FIX.md` - Why build failed

## 🔮 Supports Newest Version

- **Old mods**: Hardcoded offsets break every update (56.18.0 → 56.29.x crashes)
- **Ours**: Vision detection, no hardcoded offsets, calibrated table bounds, manual offset support, bundle check for `com.miniclip.8ballpoolmult` (new in 56.29.x)
- If new version breaks, adjust `DEFAULT_TABLE_MARGIN_X/Y` in `Config.h` or use Mod Menu Calibrate

## ⚠️ Disclaimer

Educational + private friends games only. Ranked/tournaments violates ToS. Use at own risk. Ball-by-ball mode is safest, combo chain 3-ball is risky option.

## 🙏 Credits

- Wizard 2.0 & Ninja Engine features analyzed from chetoshop.com, xdkart.com, Telegram
- Physics: ghost ball + bank reflection + cue leave + combo chain
- Safety: ball-by-ball mode (your request) + humanization + panic

Want YOLO CoreML for real ball detection? Ask!
