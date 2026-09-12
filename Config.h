#ifndef CONFIG_H
#define CONFIG_H

// ==================== STEALTH CONFIGURATION ====================
// All settings for undetectability and safety

// Build Mode
#define STEALTH_RELEASE 1          // 1 = strip logs, obfuscate, 0 = debug
#define ENABLE_LOGS 0              // 0 = no NSLog (critical for stealth)
#define ENABLE_OS_LOG 0            // 0 = no os_log

// Bundle Whitelist - only activate in these apps
#define TARGET_BUNDLE_1 "com.miniclip.8ballpool"
#define TARGET_BUNDLE_2 "com.miniclip.8ballpool.beta"

// Timing - random delays to avoid pattern detection
#define MIN_INIT_DELAY 3.0         // seconds
#define MAX_INIT_DELAY 7.5
#define PREDICTION_INTERVAL 0.12   // 0.08 is too fast, more human, less CPU
#define JITTER_RANGE 0.03          // add jitter to timer

// Overlay Stealth
#define USE_INNOCENT_CLASS_NAMES 1 // Use system-like class names
#define HIDE_ON_SCREEN_CAPTURE 1   // Auto-hide when user screenshots/records
#define HIDE_ON_BACKGROUND 1       // Hide when app backgrounds
#define DEFAULT_HIDDEN 0           // Start visible? 0 = visible after delay, 1 = hidden until gesture

// Visual Stealth - make lines less obvious on stream/record
#define LINE_ALPHA 0.85f
#define USE_DASHED_LINES 0         // 0 = solid (more legit), 1 = dashed (more obvious cheat)
#define GLOW_ENABLED 0             // Glow is pretty but more detectable on stream

// Safety Features
#define ENABLE_PANIC_GESTURE 1     // 3-finger double tap = instant hide
#define ENABLE_HUMANIZATION 1      // Add slight randomness to lines
#define MAX_VISIBLE_TIME 0         // 0 = unlimited, else auto-hide after N seconds (safety)
#define ENABLE_SAFETY_CHECK 1      // Disable in tournaments/ranked if detectable

// Anti-Detection
#define ENABLE_ANTIDEBUG 1         // ptrace deny + sysctl check
#define ENABLE_BUNDLE_CHECK 1      // Only run in target app
#define ENABLE_DYLD_CHECK 0        // Optional: try to hide from dyld (experimental, may crash)
#define ENABLE_JAILBREAK_FAKE 0    // Fake no jailbreak (if game checks, we already bypass via TrollStore)

// Humanization values
#define HUMAN_JITTER_PIXELS 1.5f   // Small random offset to ghost ball (looks human)
#define HUMAN_ANGLE_NOISE 0.5f     // Degrees of noise

// Dylib name for stealth - use innocuous name in final artifact
// Final dylib should be renamed to libUnityGraphics.dylib or similar

#endif
