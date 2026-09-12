#!/bin/bash
# build.sh - Fallback build without Theos, using direct clang
# For stealth dylib building on GitHub Actions or Mac without Theos

set -e

echo "[*] Building stealth dylib without Theos..."

# Find SDK
SDK=$(xcrun --sdk iphoneos --show-sdk-path 2>/dev/null || echo "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk")
if [ ! -d "$SDK" ]; then
    SDK=$(ls -d /Applications/Xcode*.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS*.sdk 2>/dev/null | head -1)
fi

echo "[*] Using SDK: $SDK"

# Output dir
mkdir -p build
mkdir -p artifact

# Source files
FILES="Tweak.x OverlayWindow.m PoolPredictor.mm Stealth.mm"

# Convert .x to .m for clang (Logos syntax needs preprocessing, but we have plain ObjC now)
# Our Tweak.x is mostly ObjC with %hook, which needs Logos. For fallback we need to use raw hooking
# So we create a simplified version that uses manual hooking

cat > build/fallback_tweak.m << 'EOF'
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "OverlayWindow.h"
#import "PoolPredictor.h"
#import "Config.h"
#import "Stealth.h"

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
        CGRect tableBounds = CGRectMake(screenBounds.origin.x + 20, screenBounds.origin.y + 100, screenBounds.size.width - 40, screenBounds.size.height - 200);
        CGPoint baseCue = CGPointMake(tableBounds.origin.x + tableBounds.size.width*0.25, tableBounds.origin.y + tableBounds.size.height*0.5);
        CGPoint baseTarget = CGPointMake(tableBounds.origin.x + tableBounds.size.width*0.6, tableBounds.origin.y + tableBounds.size.height*0.5);
        CGPoint basePocket = CGPointMake(tableBounds.origin.x + tableBounds.size.width, tableBounds.origin.y + 10);
        baseCue = HumanizePoint(baseCue, 0.8);
        CGPoint ghost = [PoolPredictor ghostBallForTarget:baseTarget pocket:basePocket radius:12];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[OverlayWindow shared] drawPredictionFromCue:baseCue ghost:ghost target:baseTarget pocket:basePocket];
        });
    } @catch (NSException* e) {}
}
@end

static BOOL g_initialized = NO;

static void swizzleMethod(Class cls, SEL orig, SEL newSel) {
    Method origMethod = class_getInstanceMethod(cls, orig);
    Method newMethod = class_getInstanceMethod(cls, newSel);
    if (origMethod && newMethod) {
        method_exchangeImplementations(origMethod, newMethod);
    }
}

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
    
    // Hook UnityAppController at runtime
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        Class cls = NSClassFromString(@"UnityAppController");
        if (!cls) cls = NSClassFromString(@"UnityAppController");
        if (!cls) return;
        
        // Swizzle
        Method orig = class_getInstanceMethod(cls, @selector(applicationDidBecomeActive:));
        Method newM = class_getInstanceMethod([UnityAppControllerHook class], @selector(hooked_applicationDidBecomeActive:));
        if (orig && newM) {
            method_exchangeImplementations(orig, newM);
        }
        Method orig2 = class_getInstanceMethod(cls, @selector(applicationWillResignActive:));
        Method new2 = class_getInstanceMethod([UnityAppControllerHook class], @selector(hooked_applicationWillResignActive:));
        if (orig2 && new2) {
            method_exchangeImplementations(orig2, new2);
        }
    });
}
EOF

# Build command
echo "[*] Compiling..."

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
    -I. \
    -framework Foundation \
    -framework UIKit \
    -framework QuartzCore \
    -framework Vision \
    -framework CoreGraphics \
    -lobjc \
    -lstdc++ \
    build/fallback_tweak.m OverlayWindow.m PoolPredictor.mm Stealth.mm \
    -o build/libUnityGraphics.dylib \
    -Wl,-x -Wl,-S -Wl,-dead_strip || {
    echo "[!] First attempt failed, trying without Vision..."
    xcrun clang -dynamiclib \
        -arch arm64 \
        -miphoneos-version-min=14.0 \
        -isysroot "$SDK" \
        -fobjc-arc \
        -O2 \
        -fvisibility=hidden \
        -I. \
        -framework Foundation \
        -framework UIKit \
        -framework QuartzCore \
        -framework CoreGraphics \
        -lobjc \
        -lstdc++ \
        build/fallback_tweak.m OverlayWindow.m PoolPredictor.mm Stealth.mm \
        -o build/libUnityGraphics.dylib \
        -Wl,-x -Wl,-S
}

# Strip
echo "[*] Stripping..."
xcrun strip -x build/libUnityGraphics.dylib || strip -x build/libUnityGraphics.dylib || true

# Copy to artifact with multiple innocent names
cp build/libUnityGraphics.dylib artifact/libUnityGraphics.dylib
cp build/libUnityGraphics.dylib artifact/libSwiftyPlugin.dylib
cp build/libUnityGraphics.dylib artifact/libPoolHelper.dylib || true

echo "[+] Build success!"
ls -lh artifact/
echo "[*] Checking strings..."
strings artifact/*.dylib | grep -i "poolhelper\|cheat" && echo "WARNING: leaked strings" || echo "No obvious strings - GOOD"
otool -L artifact/libUnityGraphics.dylib | head -20

echo "[+] Done - dylib ready for TrollFools injection"
