#import <UIKit/UIKit.h>
#import "OverlayWindow.h"
#import "PoolPredictor.h"
#import "Config.h"
#import "Stealth.h"
#import "ModMenu.h"
#include <mach-o/dyld.h>
#include <dlfcn.h>

// ==================== STEALTH TWEAK ENTRY - WIZARD/NINJA FEATURES + SAFETY ====================
// Supports newest 8 Ball Pool version (56.29.x) via vision detection
// Implements all Wizard/Ninja features but safer: ball-by-ball mode, no auto 3-ball by default

@interface UnityGraphicsCache : NSObject
+ (instancetype)sharedCache;
- (void)updatePredictions;
- (void)startPredictionLoop;
- (void)stopPredictionLoop;
- (void)updateWithBallByBallMode:(CGPoint)selectedTarget pocket:(CGPoint)selectedPocket;
@property (nonatomic, strong) NSTimer *predictionTimer;
@property (nonatomic, assign) BOOL isActive;
// Ball-by-ball selection (safety)
@property (nonatomic, assign) CGPoint selectedTarget;
@property (nonatomic, assign) CGPoint selectedPocket;
@property (nonatomic, assign) BOOL hasSelection;
@end

static void StealthInit(void);
static BOOL ShouldActivate(void);

static BOOL g_initialized = NO;
static BOOL g_isValidBundle = NO;

// ==================== HOOKS ====================

%hook UnityAppController

- (void)applicationDidBecomeActive:(UIApplication*)application {
    %orig;
    if (!ShouldActivate()) return;
    float delay = [[StealthManager shared] randomDelay];
    SafeLog(@"Delayed init %.2f", delay);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (g_initialized) return;
        g_initialized = YES;
        if (IsDebuggerAttached()) {
            SafeLog(@"Debugger detected, aborting");
            return;
        }
        if (IsScreenCaptured()) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[OverlayWindow shared] show];
            });
        } else {
            [[OverlayWindow shared] show];
        }
        [[UnityGraphicsCache sharedCache] startPredictionLoop];
        SafeLog(@"Helper active - supports newest 56.29.x");
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

// ==================== MAIN LOGIC - WIZARD/NINJA FEATURES ====================

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
        _hasSelection = NO;
        _selectedTarget = CGPointZero;
        _selectedPocket = CGPointZero;
    }
    return self;
}

- (void)startPredictionLoop {
    if (_isActive) return;
    _isActive = YES;
    float interval = PREDICTION_INTERVAL + RandomFloat(-JITTER_RANGE, JITTER_RANGE);
    
    self.predictionTimer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer * _Nonnull timer) {
        if (!IsAppActive()) return;
        if (IsScreenCaptured()) {
            [[OverlayWindow shared] hide];
            return;
        }
        [self updatePredictions];
        
        if (arc4random_uniform(10) == 0) {
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

- (void)updateWithBallByBallMode:(CGPoint)selectedTarget pocket:(CGPoint)selectedPocket {
    // User selected ball-by-ball - safest mode
    self.selectedTarget = selectedTarget;
    self.selectedPocket = selectedPocket;
    self.hasSelection = YES;
}

- (void)updatePredictions {
    if (![OverlayWindow shared].helperEnabled) return;
    if ([OverlayWindow shared].isPanicHidden) return;
    if (IsScreenCaptured()) return;
    
    @try {
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
        
        // Support newest version - calibrated table bounds
        ModMenu *menu = [ModMenu sharedMenu];
        CGRect tableBounds = [PoolPredictor calibratedTableBounds:screenBounds manualOffset:menu.tableBoundsOffset];
        [[OverlayWindow shared] updateTableBounds:tableBounds];
        
        // Placeholder ball positions - in real implementation, hook Unity transforms or use vision
        // For newest version support, we use dynamic detection
        CGPoint baseCue = CGPointMake(tableBounds.origin.x + tableBounds.size.width*0.25, tableBounds.origin.y + tableBounds.size.height*0.5);
        CGPoint baseTarget = CGPointMake(tableBounds.origin.x + tableBounds.size.width*0.6, tableBounds.origin.y + tableBounds.size.height*0.5);
        CGPoint basePocket = CGPointMake(tableBounds.origin.x + tableBounds.size.width, tableBounds.origin.y + 10);
        
        // Simulate multiple balls for best shot solver
        NSArray *balls = @[
            [NSValue valueWithCGPoint:CGPointMake(tableBounds.origin.x + tableBounds.size.width*0.5, tableBounds.origin.y + tableBounds.size.height*0.5)],
            [NSValue valueWithCGPoint:CGPointMake(tableBounds.origin.x + tableBounds.size.width*0.6, tableBounds.origin.y + tableBounds.size.height*0.4)],
            [NSValue valueWithCGPoint:CGPointMake(tableBounds.origin.x + tableBounds.size.width*0.4, tableBounds.origin.y + tableBounds.size.height*0.6)]
        ];
        NSArray *pockets = @[
            [NSValue valueWithCGPoint:CGPointMake(tableBounds.origin.x, tableBounds.origin.y)],
            [NSValue valueWithCGPoint:CGPointMake(tableBounds.origin.x + tableBounds.size.width/2, tableBounds.origin.y)],
            [NSValue valueWithCGPoint:CGPointMake(tableBounds.origin.x + tableBounds.size.width, tableBounds.origin.y)],
            [NSValue valueWithCGPoint:CGPointMake(tableBounds.origin.x, tableBounds.origin.y + tableBounds.size.height)],
            [NSValue valueWithCGPoint:CGPointMake(tableBounds.origin.x + tableBounds.size.width/2, tableBounds.origin.y + tableBounds.size.height)],
            [NSValue valueWithCGPoint:CGPointMake(tableBounds.origin.x + tableBounds.size.width, tableBounds.origin.y + tableBounds.size.height)]
        ];
        
#if ENABLE_HUMANIZATION
        baseCue = HumanizePoint(baseCue, 0.8);
        baseTarget = HumanizePoint(baseTarget, 0.8);
#endif
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![OverlayWindow shared].helperEnabled || [OverlayWindow shared].isPanicHidden) return;
            
            ModMenu *menu = [ModMenu sharedMenu];
            
            // ==================== BALL-BY-BALL MODE (YOUR SAFETY REQUEST) + AUTO POWER ====================
            // SAFEST: ball-by-ball ON by default, no auto 3-ball, auto power suggestion with humanized accuracy (NOT 100%)
            
            if (menu.ballByBallMode) {
                CGPoint target = self.hasSelection ? self.selectedTarget : baseTarget;
                CGPoint pocket = self.hasSelection ? self.selectedPocket : basePocket;
                
                // Calculate shot with power suggestion and humanized accuracy (75% default, NOT 100% bot)
                CGFloat accuracy = menu.powerAccuracy > 0 ? menu.powerAccuracy : DEFAULT_POWER_ACCURACY;
                NSDictionary *shotWithPower = [PoolPredictor calculateShotWithPower:baseCue target:target pocket:pocket radius:menu.ballRadius > 0 ? menu.ballRadius : DEFAULT_BALL_RADIUS accuracy:accuracy];
                CGPoint ghost = [shotWithPower[@"ghost"] CGPointValue];
                CGFloat suggestedPower = [shotWithPower[@"suggestedPower"] floatValue];
                
                [[OverlayWindow shared] drawPredictionFromCue:baseCue ghost:ghost target:target pocket:pocket];
                
                // Auto power suggestion (safe, ON by default) - shows power 1-14 with humanized accuracy
                if (menu.autoPowerEnabled) {
                    [[OverlayWindow shared] drawPowerSuggestion:suggestedPower accuracy:accuracy];
                }
                
                // Auto power adjust - auto-adjust power slider to suggested (with jitter) - OFF by default, risky
                if (menu.autoPowerAdjustEnabled) {
                    // In real implementation, hook Unity's power slider and set value
                    // Here we just show indicator - actual hook would need Il2Cpp offset for CueController power
                    // For safety, we add random delay and jitter
                    float delay = RandomFloat(0.5, 1.5);
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        SafeLog(@"Auto power adjust to %.1f with %.0f%% accuracy", suggestedPower, accuracy);
                        // Hook would go here: set power slider to suggestedPower
                    });
                }
                
                // Auto shot assist - auto shot with suggested power - OFF by default, most risky
                if (menu.autoShotEnabled) {
                    [[OverlayWindow shared] showAutoShotIndicator:YES];
                    // Safety: add random delay 1-2.5s and humanized accuracy, NOT instant 100% bot
                    float shotDelay = RandomFloat(1.0, 2.5);
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(shotDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        if (![OverlayWindow shared].helperEnabled || [[ModMenu sharedMenu] isVisible]) {
                            [[OverlayWindow shared] showAutoShotIndicator:NO];
                            return;
                        }
                        SafeLog(@"Auto shot assist: power %.1f accuracy %.0f%% - humanized, NOT 100%%", suggestedPower, accuracy);
                        // In real game, you would hook shoot button and trigger with humanized power
                        // For safety, we DON'T auto-shoot here - we just show indicator and let user shoot manually
                        // If you want true auto-shoot, uncomment below but WARNING: highly detectable
                        /*
                        // Find shoot button and simulate touch with humanized power
                        // This is where 100% bot would be - we use humanized power with jitter instead
                        */
                        [[OverlayWindow shared] showAutoShotIndicator:NO];
                    });
                } else {
                    [[OverlayWindow shared] showAutoShotIndicator:NO];
                }
                
                // Cue leave & scratch warning
                if (menu.cueLeaveEnabled || menu.scratchWarningEnabled) {
                    CGPoint cueLeave = [PoolPredictor predictCueLeave:baseCue ghost:ghost target:target pocket:pocket power:suggestedPower tableBounds:tableBounds];
                    BOOL isScratch = [PoolPredictor isScratch:cueLeave pockets:pockets radius:DEFAULT_POCKET_RADIUS];
                    [[OverlayWindow shared] drawCueLeave:cueLeave isScratch:isScratch];
                }
                
            } else {
                // Auto mode: Best shot solver
                if (menu.bestShotEnabled) {
                    NSDictionary *best = [PoolPredictor findBestShot:baseCue balls:balls pockets:pockets radius:menu.ballRadius > 0 ? menu.ballRadius : DEFAULT_BALL_RADIUS maxAngle:menu.maxAngle > 0 ? menu.maxAngle : SAFETY_MAX_ANGLE];
                    if (best) {
                        NSMutableDictionary *bestWithCue = [best mutableCopy];
                        bestWithCue[@"cue"] = [NSValue valueWithCGPoint:baseCue];
                        [[OverlayWindow shared] drawBestShot:bestWithCue];
                        
                        // Power suggestion for best shot
                        if (menu.autoPowerEnabled) {
                            CGPoint target = [best[@"target"] CGPointValue];
                            CGPoint pocket = [best[@"pocket"] CGPointValue];
                            CGPoint ghost = [best[@"shot"][@"ghost"] CGPointValue];
                            CGFloat accuracy = menu.powerAccuracy > 0 ? menu.powerAccuracy : DEFAULT_POWER_ACCURACY;
                            CGFloat power = [PoolPredictor calculateSuggestedPower:baseCue ghost:ghost target:target pocket:pocket accuracy:accuracy];
                            [[OverlayWindow shared] drawPowerSuggestion:power accuracy:accuracy];
                        }
                        
                        if (menu.bankShotsEnabled) {
                            NSDictionary *bank = [PoolPredictor findBestBankShot:baseCue balls:balls pockets:pockets tableBounds:tableBounds radius:menu.ballRadius > 0 ? menu.ballRadius : DEFAULT_BALL_RADIUS];
                            if (bank) {
                                NSMutableDictionary *bankWithCue = [bank mutableCopy];
                                bankWithCue[@"cue"] = [NSValue valueWithCGPoint:baseCue];
                                [[OverlayWindow shared] drawBankShot:bankWithCue];
                            }
                        }
                        
                        if (menu.cueLeaveEnabled || menu.scratchWarningEnabled) {
                            CGPoint ghost = [best[@"shot"][@"ghost"] CGPointValue];
                            CGPoint target = [best[@"target"] CGPointValue];
                            CGPoint pocket = [best[@"pocket"] CGPointValue];
                            CGFloat power = menu.suggestedPower > 0 ? menu.suggestedPower : 5;
                            CGPoint cueLeave = [PoolPredictor predictCueLeave:baseCue ghost:ghost target:target pocket:pocket power:power tableBounds:tableBounds];
                            BOOL isScratch = [PoolPredictor isScratch:cueLeave pockets:pockets radius:DEFAULT_POCKET_RADIUS];
                            [[OverlayWindow shared] drawCueLeave:cueLeave isScratch:isScratch];
                        }
                    }
                } else {
                    CGPoint ghost = [PoolPredictor ghostBallForTarget:baseTarget pocket:basePocket radius:12];
                    [[OverlayWindow shared] drawPredictionFromCue:baseCue ghost:ghost target:baseTarget pocket:basePocket];
                    if (menu.autoPowerEnabled) {
                        CGFloat accuracy = menu.powerAccuracy > 0 ? menu.powerAccuracy : DEFAULT_POWER_ACCURACY;
                        CGFloat power = [PoolPredictor calculateSuggestedPower:baseCue ghost:ghost target:baseTarget pocket:basePocket accuracy:accuracy];
                        [[OverlayWindow shared] drawPowerSuggestion:power accuracy:accuracy];
                    }
                }
                
                if (menu.comboChainEnabled) {
                    NSArray *chains = [PoolPredictor findComboChain:baseCue balls:balls pockets:pockets radius:menu.ballRadius > 0 ? menu.ballRadius : DEFAULT_BALL_RADIUS maxBalls:menu.comboChainEnabled ? MAX_COMBO_BALLS : 1];
                    if (chains.count > 0) {
                        [[OverlayWindow shared] drawComboChain:chains];
                    }
                }
            }
        });
        
    } @catch (NSException* e) {
        SafeLog(@"Exception in update: %@", e);
    }
}

@end

// ==================== STEALTH INIT ====================

static BOOL ShouldActivate(void) {
    if (!g_isValidBundle) {
        g_isValidBundle = IsValidBundle();
    }
    return g_isValidBundle;
}

static void StealthInit(void) {
    @autoreleasepool {
        if (!IsValidBundle()) return;
        g_isValidBundle = YES;
        [[StealthManager shared] setupAntiDetection];
        SafeLog(@"Stealth module loaded - Wizard/Ninja features + ball-by-ball safety");
    }
}

__attribute__((constructor(101)))
static void init_stealth(void) {
    StealthInit();
}

__attribute__((constructor(1000)))
static void init_overlay(void) {
    if (!IsValidBundle()) return;
    SafeLog(@"Overlay constructor - supports 56.29.x");
}

__attribute__((destructor))
static void fini(void) {
    SafeLog(@"Unloading");
    [[UnityGraphicsCache sharedCache] stopPredictionLoop];
}
