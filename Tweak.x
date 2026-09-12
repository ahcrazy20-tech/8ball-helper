#import <UIKit/UIKit.h>
#import "OverlayWindow.h"
#import "PoolPredictor.h"
#import "Config.h"
#import "Stealth.h"
#include <mach-o/dyld.h>
#include <dlfcn.h>

// ==================== STEALTH TWEAK ENTRY ====================
// This is the main injection point, heavily obfuscated for undetectability

// Use innocent-looking class names
// Old: PoolHelperManager -> New: UnityGraphicsCache (looks like Unity internal)
@interface UnityGraphicsCache : NSObject
+ (instancetype)sharedCache;
- (void)updatePredictions;
- (void)startPredictionLoop;
- (void)stopPredictionLoop;
@property (nonatomic, strong) NSTimer *predictionTimer;
@property (nonatomic, assign) BOOL isActive;
@end

// Forward declarations for stealth functions
static void StealthInit(void);
static BOOL ShouldActivate(void);

// Global flag to avoid double init
static BOOL g_initialized = NO;
static BOOL g_isValidBundle = NO;

// ==================== HOOKS - STEALTH VERSION ====================

// Instead of hooking UnityAppController directly with %hook which leaves obvious symbols,
// we use multiple methods and obfuscate

// Method 1: Hook via notification (less detectable than %hook)
// Method 2: Keep %hook but with innocuous naming and delayed

%hook UnityAppController

- (void)applicationDidBecomeActive:(UIApplication*)application {
    %orig;
    
    // Safety: only run in target bundle
    if (!ShouldActivate()) return;
    
    // Random delay to avoid pattern detection
    float delay = [[StealthManager shared] randomDelay];
    SafeLog(@"Delayed init %.2f", delay);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (g_initialized) return;
        g_initialized = YES;
        
        // Additional safety: check if debugger attached
        if (IsDebuggerAttached()) {
            SafeLog(@"Debugger detected, aborting");
            return;
        }
        
        // Check screen capture
        if (IsScreenCaptured()) {
            SafeLog(@"Screen captured, delaying");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[OverlayWindow shared] show];
            });
        } else {
            [[OverlayWindow shared] show];
        }
        
        [[UnityGraphicsCache sharedCache] startPredictionLoop];
        SafeLog(@"Helper active");
    });
}

- (void)applicationWillResignActive:(UIApplication*)application {
    %orig;
    if (!ShouldActivate()) return;
    [[OverlayWindow shared] hide];
    [[UnityGraphicsCache sharedCache] stopPredictionLoop];
}

- (void)applicationDidEnterBackground:(UIApplication*)application {
    %orig;
    [[OverlayWindow shared] hide];
}

%end

// ==================== MAIN LOGIC ====================

@implementation UnityGraphicsCache

+ (instancetype)sharedCache {
    static UnityGraphicsCache *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[UnityGraphicsCache alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isActive = NO;
    }
    return self;
}

- (void)startPredictionLoop {
    if (_isActive) return;
    _isActive = YES;
    
    // Use random interval with jitter to avoid perfect timing detection
    // Bot detection often looks for perfect intervals like 0.08 exactly
    float interval = PREDICTION_INTERVAL + RandomFloat(-JITTER_RANGE, JITTER_RANGE);
    
    // Use dispatch timer instead of NSTimer for less obvious pattern? NSTimer is okay
    // But we add jitter each time by rescheduling
    
    self.predictionTimer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer * _Nonnull timer) {
        // Check if still valid
        if (!IsAppActive()) return;
        if (IsScreenCaptured()) {
            [[OverlayWindow shared] hide];
            return;
        }
        [self updatePredictions];
        
        // Randomly reschedule with new jitter to avoid perfect pattern
        if (arc4random_uniform(10) == 0) { // 10% chance to reschedule
            [timer invalidate];
            float newInterval = PREDICTION_INTERVAL + RandomFloat(-JITTER_RANGE, JITTER_RANGE);
            self.predictionTimer = [NSTimer scheduledTimerWithTimeInterval:newInterval repeats:YES block:^(NSTimer * _Nonnull t) {
                if (!IsAppActive()) return;
                [self updatePredictions];
            }];
        }
    }];
}

- (void)stopPredictionLoop {
    _isActive = NO;
    [self.predictionTimer invalidate];
    self.predictionTimer = nil;
    [[OverlayWindow shared] clear];
}

- (void)updatePredictions {
    if (![OverlayWindow shared].helperEnabled) return;
    if ([OverlayWindow shared].isPanicHidden) return;
    if (IsScreenCaptured()) return;
    
    @try {
        // Get main window bounds safely
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene* scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    for (UIWindow* w in scene.windows) {
                        if (w.isKeyWindow) {
                            keyWindow = w;
                            break;
                        }
                    }
                }
            }
        }
        if (!keyWindow) {
            keyWindow = [UIApplication sharedApplication].keyWindow;
        }
        if (!keyWindow) return;
        
        CGRect screenBounds = keyWindow.bounds;
        // Estimate table bounds - more accurate estimation
        CGRect tableBounds = CGRectMake(screenBounds.origin.x + 20, screenBounds.origin.y + 100, screenBounds.size.width - 40, screenBounds.size.height - 200);
        
        // TODO: Replace with real ball detection
        // For now use placeholder positions that can be calibrated
        // In production, you would hook Unity's Transform positions via Il2Cpp
        
        // Add slight randomization to positions to look human (not perfect tracking)
        CGPoint baseCue = CGPointMake(tableBounds.origin.x + tableBounds.size.width*0.25, tableBounds.origin.y + tableBounds.size.height*0.5);
        CGPoint baseTarget = CGPointMake(tableBounds.origin.x + tableBounds.size.width*0.6, tableBounds.origin.y + tableBounds.size.height*0.5);
        CGPoint basePocket = CGPointMake(tableBounds.origin.x + tableBounds.size.width, tableBounds.origin.y + 10);
        
#if ENABLE_HUMANIZATION
        // Humanize slightly
        baseCue = HumanizePoint(baseCue, 0.8);
        baseTarget = HumanizePoint(baseTarget, 0.8);
#endif
        
        // Calculate ghost ball
        CGPoint ghost = [PoolPredictor ghostBallForTarget:baseTarget pocket:basePocket radius:12];
        
        // Draw on main thread
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([OverlayWindow shared].helperEnabled && ![OverlayWindow shared].isPanicHidden) {
                [[OverlayWindow shared] drawPredictionFromCue:baseCue ghost:ghost target:baseTarget pocket:basePocket];
            }
        });
        
    } @catch (NSException* e) {
        SafeLog(@"Exception in update: %@", e);
        // Don't crash game - safety first
    }
}

@end

// ==================== STEALTH INIT ====================

static BOOL ShouldActivate(void) {
    if (!g_isValidBundle) {
        // Check once and cache
        g_isValidBundle = IsValidBundle();
    }
    return g_isValidBundle;
}

static void StealthInit(void) {
    @autoreleasepool {
        // Early bundle check - don't do anything if not target app
        if (!IsValidBundle()) {
            return;
        }
        g_isValidBundle = YES;
        
        // Setup anti-detection
        [[StealthManager shared] setupAntiDetection];
        
        SafeLog(@"Stealth module loaded");
        
        // Additional stealth: delay even more if needed
        // Hide our presence from dyld by not doing heavy work in constructor
    }
}

// Constructor with low priority to run late (less detectable)
__attribute__((constructor(101)))
static void init_stealth(void) {
    StealthInit();
}

// Second constructor with even lower priority for overlay setup
__attribute__((constructor(1000)))
static void init_overlay(void) {
    if (!IsValidBundle()) return;
    
    // Don't init overlay immediately, wait for app to become active
    // This is handled in UnityAppController hook
    SafeLog(@"Overlay constructor");
}

// Destructor - cleanup
__attribute__((destructor))
static void fini(void) {
    SafeLog(@"Unloading");
    [[UnityGraphicsCache sharedCache] stopPredictionLoop];
}
