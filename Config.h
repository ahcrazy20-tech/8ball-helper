#ifndef CONFIG_H
#define CONFIG_H

// ==================== STEALTH & FEATURE CONFIGURATION ====================
// Wizard/Ninja features + Ball-by-Ball Safety + Auto Power Suggestion (humanized, not 100%)
// Supports newest 8 Ball Pool 56.29.x

// Build Mode
#define STEALTH_RELEASE 1
#define ENABLE_LOGS 0
#define ENABLE_OS_LOG 0

// Bundle Whitelist
#define TARGET_BUNDLE_1 "com.miniclip.8ballpool"
#define TARGET_BUNDLE_2 "com.miniclip.8ballpool.beta"
#define TARGET_BUNDLE_3 "com.miniclip.8ballpoolmult"

#define MIN_INIT_DELAY 3.0
#define MAX_INIT_DELAY 7.5
#define PREDICTION_INTERVAL 0.12
#define JITTER_RANGE 0.03

#define USE_INNOCENT_CLASS_NAMES 1
#define HIDE_ON_SCREEN_CAPTURE 1
#define HIDE_ON_BACKGROUND 1
#define DEFAULT_HIDDEN 0

#define LINE_ALPHA 0.85f
#define USE_DASHED_LINES 0
#define GLOW_ENABLED 0

#define ENABLE_PANIC_GESTURE 1
#define ENABLE_HUMANIZATION 1
#define MAX_VISIBLE_TIME 0
#define ENABLE_SAFETY_CHECK 1

#define ENABLE_ANTIDEBUG 1
#define ENABLE_BUNDLE_CHECK 1
#define ENABLE_DYLD_CHECK 0
#define ENABLE_JAILBREAK_FAKE 0

#define HUMAN_JITTER_PIXELS 1.5f
#define HUMAN_ANGLE_NOISE 0.5f

// ==================== WIZARD / NINJA FEATURES ====================

#define FEATURE_GHOST_BALL 1
#define FEATURE_LONG_GUIDELINES 1
#define FEATURE_BALL_BY_BALL 1
#define FEATURE_MANUAL_POCKET 1
#define FEATURE_BEST_SHOT_SOLVER 1
#define FEATURE_BANK_SHOTS 1
#define FEATURE_CUE_LEAVE 1
#define FEATURE_SCRATCH_WARNING 1
#define FEATURE_COMBO_CHAIN 1
#define FEATURE_INFO_HUD 1

// Safety Defaults
#define DEFAULT_BALL_BY_BALL_MODE 1
#define DEFAULT_BEST_SHOT_ENABLED 0
#define DEFAULT_BANK_SHOTS_ENABLED 0
#define DEFAULT_CUE_LEAVE_ENABLED 0
#define DEFAULT_SCRATCH_WARNING_ENABLED 1
#define DEFAULT_COMBO_CHAIN_ENABLED 0
#define DEFAULT_INFO_HUD_ENABLED 0

#define MAX_COMBO_BALLS 3
#define MAX_BANK_BOUNCES 1
#define SAFETY_MAX_ANGLE 55.0f
#define SAFETY_MIN_DISTANCE 20.0f

#define DEFAULT_LINE_THICKNESS 2.5f
#define DEFAULT_BALL_RADIUS 12.0f
#define DEFAULT_POCKET_RADIUS 18.0f
#define DEFAULT_GHOST_RADIUS 11.0f
#define DEFAULT_CUE_POWER 0

#define ENABLE_TABLE_CALIBRATION 1
#define DEFAULT_TABLE_MARGIN_X 20
#define DEFAULT_TABLE_MARGIN_Y_TOP 100
#define DEFAULT_TABLE_MARGIN_Y_BOTTOM 100

#define SUPPORT_NEWEST_VERSION 1
#define ENABLE_VERSION_CHECK 1

#define ENABLE_MOD_MENU 1
#define MOD_MENU_STEALTH 1

// ==================== AUTO POWER SUGGESTION (SAFER AUTO SHOT) ====================
// Auto shot according to suggestion power - with humanization, NOT 100% accuracy
// Safer than Wizard/Ninja auto-play: suggests power, auto-adjusts with jitter, user still shoots manually

#define FEATURE_AUTO_POWER_SUGGESTION 1   // Suggest power based on distance (Wizard Cue Power 0-14)
#define FEATURE_AUTO_POWER_ADJUST 1       // Auto-adjust power slider to suggested power (with humanization)
#define FEATURE_AUTO_SHOT_ASSIST 1        // Optional auto-shot assist (OFF by default, risky)

#define DEFAULT_AUTO_POWER_ENABLED 1      // 1 = ON - show suggested power (safe)
#define DEFAULT_AUTO_POWER_ADJUST_ENABLED 0 // 0 = OFF by default - auto-adjust power slider (more risky, option)
#define DEFAULT_AUTO_SHOT_ENABLED 0       // 0 = OFF by default - auto shot assist (most risky, option)

#define DEFAULT_POWER_ACCURACY 75.0f      // 75% accuracy = human-like, misses sometimes (NOT 100% bot)
#define MIN_POWER_ACCURACY 50.0f
#define MAX_POWER_ACCURACY 85.0f          // Max 85% - we don't allow 100% to avoid bot detection
#define DEFAULT_SUGGESTED_POWER 5         // 1-14, 0 = auto

#define POWER_HUMANIZATION 1.2f           // Power jitter ±1.2
#define POWER_DISTANCE_FACTOR 0.015f      // Power based on distance * factor

// Power calculation: power = distance * factor + random(-humanization, humanization)
// Accuracy affects random range: lower accuracy = more random miss

#endif
