#!/bin/bash
# build.sh - Fallback build without Theos, using direct clang
# Includes all Wizard/Ninja features + ball-by-ball safety + newest 56.29.x support

set -e

echo "[*] Building stealth dylib with Wizard/Ninja features..."

SDK=$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || echo "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk")
if [ ! -d "$SDK" ]; then
    SDK=$(ls -d /Applications/Xcode*.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS*.sdk 2>/dev/null | head -1)
fi
if [ ! -d "$SDK" ] && [ -n "$THEOS" ]; then
    # Last resort: use the newest SDK that Theos downloaded.
    SDK=$(ls -d "$THEOS"/sdks/iPhoneOS*.sdk 2>/dev/null | sort -V | tail -1)
fi

if [ ! -d "$SDK" ]; then
    echo "[!] ERROR: no iPhoneOS SDK found. Install Xcode (macOS) or set THEOS with \$THEOS/sdks populated." >&2
    exit 1
fi

echo "[*] Using SDK: $SDK"

mkdir -p build
mkdir -p artifact

cat > build/fallback_tweak.m << 'EOF'
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "OverlayWindow.h"
#import "PoolPredictor.h"
#import "Config.h"
#import "Stealth.h"
#import "ModMenu.h"

@interface UnityGraphicsCache : NSObject
+ (instancetype)sharedCache;
- (void)updatePredictions;
- (void)startPredictionLoop;
- (void)stopPredictionLoop;
@property (nonatomic, strong) NSTimer *predictionTimer;
@property (nonatomic, assign) BOOL isActive;
@end

@implementation UnityGraphicsCache
+ (instancetype)sharedCache {
    static UnityGraphicsCache *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[UnityGraphicsCache alloc] init];
    });
    return instance;
}
- (void)startPredictionLoop {
    if (_isActive) return;
    _isActive = YES;
    float interval = PREDICTION_INTERVAL + RandomFloat(-JITTER_RANGE, JITTER_RANGE);
    self.predictionTimer = [NSTimer scheduledTimerWithTimeInterval:interval repeats:YES block:^(NSTimer * _Nonnull timer) {
        if (!IsAppActive()) return;
        if (IsScreenCaptured()) { [[OverlayWindow shared] hide]; return; }
        [self updatePredictions];
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
    @try {
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        if (!keyWindow) return;
        CGRect screenBounds = keyWindow.bounds;
        ModMenu *menu = [ModMenu sharedMenu];
        CGRect tableBounds = [PoolPredictor calibratedTableBounds:screenBounds manualOffset:menu.tableBoundsOffset];
        [[OverlayWindow shared] updateTableBounds:tableBounds];
        
        CGPoint baseCue = CGPointMake(tableBounds.origin.x + tableBounds.size.width*0.25, tableBounds.origin.y + tableBounds.size.height*0.5);
        CGPoint baseTarget = CGPointMake(tableBounds.origin.x + tableBounds.size.width*0.6, tableBounds.origin.y + tableBounds.size.height*0.5);
        CGPoint basePocket = CGPointMake(tableBounds.origin.x + tableBounds.size.width, tableBounds.origin.y + 10);
        baseCue = HumanizePoint(baseCue, 0.8);
        
        NSArray *balls = @[
            [NSValue valueWithCGPoint:CGPointMake(tableBounds.origin.x + tableBounds.size.width*0.5, tableBounds.origin.y + tableBounds.size.height*0.5)],
            [NSValue valueWithCGPoint:CGPointMake(tableBounds.origin.x + tableBounds.size.width*0.6, tableBounds.origin.y + tableBounds.size.height*0.4)]
        ];
        NSArray *pockets = @[
            [NSValue valueWithCGPoint:CGPointMake(tableBounds.origin.x, tableBounds.origin.y)],
            [NSValue valueWithCGPoint:CGPointMake(tableBounds.origin.x + tableBounds.size.width/2, tableBounds.origin.y)],
            [NSValue valueWithCGPoint:CGPointMake(tableBounds.origin.x + tableBounds.size.width, tableBounds.origin.y)],
            [NSValue valueWithCGPoint:CGPointMake(tableBounds.origin.x, tableBounds.origin.y + tableBounds.size.height)],
            [NSValue valueWithCGPoint:CGPointMake(tableBounds.origin.x + tableBounds.size.width/2, tableBounds.origin.y + tableBounds.size.height)],
            [NSValue valueWithCGPoint:CGPointMake(tableBounds.origin.x + tableBounds.size.width, tableBounds.origin.y + tableBounds.size.height)]
        ];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![OverlayWindow shared].helperEnabled) return;
            ModMenu *menu = [ModMenu sharedMenu];
            if (menu.ballByBallMode) {
                NSDictionary *single = [PoolPredictor calculateSingleBallShot:baseCue target:baseTarget pocket:basePocket radius:menu.ballRadius > 0 ? menu.ballRadius : 12];
                CGPoint ghost = [single[@"shot"][@"ghost"] CGPointValue];
                [[OverlayWindow shared] drawPredictionFromCue:baseCue ghost:ghost target:baseTarget pocket:basePocket];
                if (menu.cueLeaveEnabled || menu.scratchWarningEnabled) {
                    CGPoint leave = [PoolPredictor predictCueLeave:baseCue ghost:ghost target:baseTarget pocket:basePocket power:0 tableBounds:tableBounds];
                    BOOL scratch = [PoolPredictor isScratch:leave pockets:pockets radius:18];
                    [[OverlayWindow shared] drawCueLeave:leave isScratch:scratch];
                }
            } else {
                if (menu.bestShotEnabled) {
                    NSDictionary *best = [PoolPredictor findBestShot:baseCue balls:balls pockets:pockets radius:12 maxAngle:menu.maxAngle > 0 ? menu.maxAngle : 55];
                    if (best) {
                        NSMutableDictionary *b = [best mutableCopy];
                        b[@"cue"] = [NSValue valueWithCGPoint:baseCue];
                        [[OverlayWindow shared] drawBestShot:b];
                    }
                } else {
                    CGPoint ghost = [PoolPredictor ghostBallForTarget:baseTarget pocket:basePocket radius:12];
                    [[OverlayWindow shared] drawPredictionFromCue:baseCue ghost:ghost target:baseTarget pocket:basePocket];
                }
                if (menu.comboChainEnabled) {
                    NSArray *chains = [PoolPredictor findComboChain:baseCue balls:balls pockets:pockets radius:12 maxBalls:3];
                    [[OverlayWindow shared] drawComboChain:chains];
                }
            }
        });
    } @catch (NSException* e) {}
}
@end

static BOOL g_initialized = NO;

@interface UnityAppControllerHook : NSObject
@end

@implementation UnityAppControllerHook
- (void)hooked_applicationDidBecomeActive:(UIApplication*)app {
    [self hooked_applicationDidBecomeActive:app];
    if (!IsValidBundle()) return;
    float delay = [[StealthManager shared] randomDelay];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (g_initialized) return;
        g_initialized = YES;
        if (IsDebuggerAttached()) return;
        [[OverlayWindow shared] show];
        [[UnityGraphicsCache sharedCache] startPredictionLoop];
    });
}
- (void)hooked_applicationWillResignActive:(UIApplication*)app {
    [self hooked_applicationWillResignActive:app];
    [[OverlayWindow shared] hide];
    [[UnityGraphicsCache sharedCache] stopPredictionLoop];
}
@end

__attribute__((constructor))
static void init_fallback() {
    if (!IsValidBundle()) return;
    [[StealthManager shared] setupAntiDetection];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"UnityAppController");
        if (!cls) return;
        Method orig = class_getInstanceMethod(cls, @selector(applicationDidBecomeActive:));
        Method newM = class_getInstanceMethod([UnityAppControllerHook class], @selector(hooked_applicationDidBecomeActive:));
        if (orig && newM) method_exchangeImplementations(orig, newM);
        Method orig2 = class_getInstanceMethod(cls, @selector(applicationWillResignActive:));
        Method new2 = class_getInstanceMethod([UnityAppControllerHook class], @selector(hooked_applicationWillResignActive:));
        if (orig2 && new2) method_exchangeImplementations(orig2, new2);
    });
}
EOF

echo "[*] Compiling with Wizard/Ninja features..."

# NOTE: -lstdc++ is NOT available in the iOS SDK (Apple ships libc++ only) and
# makes ld fail with "library not found for -lstdc++". The C++/ObjC++ objects
# (.mm) make the clang driver link libc++ automatically, so no -l flag is needed.
# Also NOTE: -std=c++17 must NOT be passed here - this single invocation also
# compiles the plain Objective-C .m files, and clang errors out with
# "invalid argument '-std=c++17' not allowed with 'Objective-C'". The .mm files
# get their C++ standard from the driver default.
# Vision.framework is not referenced by any source, so it is not linked.
xcrun clang -dynamiclib \
    -arch arm64 \
    -miphoneos-version-min=14.0 \
    -isysroot "$SDK" \
    -fobjc-arc \
    -O2 \
    -fvisibility=hidden \
    -fvisibility-inlines-hidden \
    -DNDEBUG \
    -DSTEALTH_RELEASE=1 \
    -Qunused-arguments \
    -Wno-unused-variable \
    -Wno-unused-function \
    -I. \
    -framework Foundation \
    -framework UIKit \
    -framework QuartzCore \
    -framework CoreGraphics \
    -lobjc \
    build/fallback_tweak.m OverlayWindow.m PoolPredictor.mm Stealth.mm ModMenu.m \
    -o build/libUnityGraphics.dylib \
    -Wl,-x -Wl,-S -Wl,-dead_strip || {
    echo "[!] First attempt failed, retrying with a relaxed flag set..."
    xcrun clang -dynamiclib \
        -arch arm64 \
        -miphoneos-version-min=14.0 \
        -isysroot "$SDK" \
        -fobjc-arc \
        -O2 \
        -fvisibility=hidden \
        -Qunused-arguments \
        -I. \
        -framework Foundation \
        -framework UIKit \
        -framework QuartzCore \
        -framework CoreGraphics \
        -lobjc \
        build/fallback_tweak.m OverlayWindow.m PoolPredictor.mm Stealth.mm ModMenu.m \
        -o build/libUnityGraphics.dylib \
        -Wl,-x -Wl,-S
}

echo "[*] Stripping..."
xcrun strip -x build/libUnityGraphics.dylib 2>/dev/null || strip -x build/libUnityGraphics.dylib 2>/dev/null || true

cp build/libUnityGraphics.dylib artifact/libUnityGraphics.dylib
cp build/libUnityGraphics.dylib artifact/libSwiftyPlugin.dylib

echo "[+] Build success! Wizard/Ninja features included"
ls -lh artifact/
echo "[*] Checking strings..."
# grep exits 1 when nothing matches, which would abort the script under `set -e`.
strings artifact/*.dylib 2>/dev/null | grep -i "poolhelper\|cheat" && echo "WARNING: leaked strings" || echo "No obvious strings - GOOD"
otool -L artifact/libUnityGraphics.dylib 2>/dev/null | head -20 || true


echo "[+] Done - dylib ready for TrollFools injection"
echo "[*] Features: Ball-by-Ball (safe), Best Shot, Bank, Cue Leave, Scratch Warning, Combo Chain (optional), Long Guidelines, Mod Menu, Newest 56.29.x support"
