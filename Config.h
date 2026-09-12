#ifndef CONFIG_H
#define CONFIG_H

// ==================== STEALTH & FEATURE CONFIGURATION ====================
// All settings for undetectability, safety, and Wizard/Ninja features
// Supports newest 8 Ball Pool version (56.29.x) via vision detection (no hardcoded offsets)

// Build Mode
#define STEALTH_RELEASE 1
#define ENABLE_LOGS 0
#define ENABLE_OS_LOG 0

// Bundle Whitelist - only activate in these apps (supports newest version)
#define TARGET_BUNDLE_1 "com.miniclip.8ballpool"
#define TARGET_BUNDLE_2 "com.miniclip.8ballpool.beta"
#define TARGET_BUNDLE_3 "com.miniclip.8ballpoolmult" // new bundle id in some versions

// Timing - random delays to avoid pattern detection
#define MIN_INIT_DELAY 3.0
#define MAX_INIT_DELAY 7.5
#define PREDICTION_INTERVAL 0.12
#define JITTER_RANGE 0.03

// Overlay Stealth
#define USE_INNOCENT_CLASS_NAMES 1
#define HIDE_ON_SCREEN_CAPTURE 1
#define HIDE_ON_BACKGROUND 1
#define DEFAULT_HIDDEN 0

// Visual Stealth
#define LINE_ALPHA 0.85f
#define USE_DASHED_LINES 0
#define GLOW_ENABLED 0

// Safety Features
#define ENABLE_PANIC_GESTURE 1
#define ENABLE_HUMANIZATION 1
#define MAX_VISIBLE_TIME 0
#define ENABLE_SAFETY_CHECK 1

// Anti-Detection
#define ENABLE_ANTIDEBUG 1
#define ENABLE_BUNDLE_CHECK 1
#define ENABLE_DYLD_CHECK 0
#define ENABLE_JAILBREAK_FAKE 0

// Humanization values
#define HUMAN_JITTER_PIXELS 1.5f
#define HUMAN_ANGLE_NOISE 0.5f

// ==================== WIZARD / NINJA FEATURES ====================
// All Wizard & Ninja features included but with safety toggles

// Core Features (always on, safe)
#define FEATURE_GHOST_BALL 1           // Ghost ball calculation
#define FEATURE_LONG_GUIDELINES 1      // Extended lines beyond ghost/pocket
#define FEATURE_BALL_BY_BALL 1         // Safety: select ball by ball, not auto 3-ball (DEFAULT ON for safety)
#define FEATURE_MANUAL_POCKET 1        // Manual pocket nomination

// Advanced Features (optional, toggle via menu, more detectable if abused)
#define FEATURE_BEST_SHOT_SOLVER 1     // Sweeps all angles, ranks shots (Wizard Best Shot Solver)
#define FEATURE_BANK_SHOTS 1           // 1-cushion bank shots (Wizard Bank Shots)
#define FEATURE_CUE_LEAVE 1            // Shows where cue ball stops (Wizard Cue Ball Leave)
#define FEATURE_SCRATCH_WARNING 1      // Red flag if cue will scratch (Wizard Scratch Warning)
#define FEATURE_COMBO_CHAIN 1          // Rings and numbers each ball in chain (Wizard Combo & Carom Chain) - DISABLED by default for safety
#define FEATURE_INFO_HUD 1             // Ball numbers, turn timer, etc (optional)

// Safety Defaults - how features start (more safe than Wizard/Ninja)
#define DEFAULT_BALL_BY_BALL_MODE 1    // 1 = ball-by-ball (safe, user selects), 0 = auto best shot
#define DEFAULT_BEST_SHOT_ENABLED 0    // 0 = OFF by default (safer), user can enable via menu
#define DEFAULT_BANK_SHOTS_ENABLED 0   // 0 = OFF by default (bank shots are more obvious)
#define DEFAULT_CUE_LEAVE_ENABLED 0    // 0 = OFF by default
#define DEFAULT_SCRATCH_WARNING_ENABLED 1 // 1 = ON (safety feature)
#define DEFAULT_COMBO_CHAIN_ENABLED 0  // 0 = OFF by default - 3-ball in one shot is risky, option to enable
#define DEFAULT_INFO_HUD_ENABLED 0     // 0 = OFF

// Limits for safety - prevent 3-ball auto search
#define MAX_COMBO_BALLS 3              // Max balls in chain (Wizard shows up to 3-5)
#define MAX_BANK_BOUNCES 1             // Max cushion bounces for bank shots
#define SAFETY_MAX_ANGLE 55.0f         // Don't suggest shots >55° (too obvious)
#define SAFETY_MIN_DISTANCE 20.0f      // Min distance to avoid tiny shots

// Customization (Wizard-like sliders)
#define DEFAULT_LINE_THICKNESS 2.5f
#define DEFAULT_BALL_RADIUS 12.0f
#define DEFAULT_POCKET_RADIUS 18.0f
#define DEFAULT_GHOST_RADIUS 11.0f
#define DEFAULT_CUE_POWER 0            // 0 = auto read cue power, 1-14 force value (like Wizard)

// Table Calibration (for newest version support)
#define ENABLE_TABLE_CALIBRATION 1     // Allow manual table boundary adjustment
#define DEFAULT_TABLE_MARGIN_X 20
#define DEFAULT_TABLE_MARGIN_Y_TOP 100
#define DEFAULT_TABLE_MARGIN_Y_BOTTOM 100

// Version Support
#define SUPPORT_NEWEST_VERSION 1       // Use vision detection, no hardcoded offsets, works on 56.29.x
#define ENABLE_VERSION_CHECK 1         // Check game version and adapt

// Mod Menu
#define ENABLE_MOD_MENU 1              // Hidden mod menu (4-finger tap)
#define MOD_MENU_STEALTH 1             // Menu looks innocent, small, hidden

#endif
