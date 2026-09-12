#import "Stealth.h"
#include <sys/sysctl.h>
#include <dlfcn.h>
#include <sys/types.h>
#include <unistd.h>
#import <UIKit/UIKit.h>

#if ENABLE_ANTIDEBUG
#include <sys/ptrace.h>
#endif

@implementation StealthManager

+ (instancetype)shared {
    static StealthManager* instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[StealthManager alloc] init];
    });
    return instance;
}

- (BOOL)shouldActivate {
#if ENABLE_BUNDLE_CHECK
    NSString* bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleID) return NO;
    
    // Only activate in 8 Ball Pool
    if ([bundleID isEqualToString:TARGET_BUNDLE_1]) return YES;
    if ([bundleID isEqualToString:TARGET_BUNDLE_2]) return YES;
    if ([bundleID isEqualToString:TARGET_BUNDLE_3]) return YES;
    
    // Also allow if bundle contains miniclip
    if ([bundleID containsString:@"miniclip"] && [bundleID containsString:@"8ball"]) return YES;
    
    return NO;
#else
    return YES;
#endif
}

- (void)setupAntiDetection {
#if ENABLE_ANTIDEBUG
    AntiDebug();
    // Check debugger in background thread, if debugger found, disable helper
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        if (IsDebuggerAttached()) {
            SafeLog(@"Debugger detected, disabling");
            // Could disable helper here
        }
    });
#endif
    
#if ENABLE_DYLD_CHECK
    TryHideDylib();
#endif
}

- (void)setupScreenCaptureObserver:(id)target selector:(SEL)sel {
#if HIDE_ON_SCREEN_CAPTURE
    if (@available(iOS 11.0, *)) {
        [[NSNotificationCenter defaultCenter] addObserver:target selector:sel name:UIScreenCapturedDidChangeNotification object:nil];
    }
#endif
}

- (float)randomDelay {
    return RandomFloat(MIN_INIT_DELAY, MAX_INIT_DELAY);
}

@end

// ==================== C FUNCTIONS ====================

BOOL IsDebuggerAttached(void) {
    int name[4];
    struct kinfo_proc info;
    size_t info_size = sizeof(info);
    
    info.kp_proc.p_flag = 0;
    name[0] = CTL_KERN;
    name[1] = KERN_PROC;
    name[2] = KERN_PROC_PID;
    name[3] = getpid();
    
    if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) {
        return NO;
    }
    return ((info.kp_proc.p_flag & P_TRACED) != 0);
}

void AntiDebug(void) {
#if ENABLE_ANTIDEBUG
    // PT_DENY_ATTACH - prevent debugger attaching
    // This is classic anti-debug, but can be detected itself, so we do it quietly
    // On iOS 12+, ptrace may not be allowed, so wrap in try
    #ifdef PT_DENY_ATTACH
    ptrace(PT_DENY_ATTACH, 0, 0, 0);
    #endif
#endif
}

BOOL IsValidBundle(void) {
    return [[StealthManager shared] shouldActivate];
}

BOOL IsScreenCaptured(void) {
    if (@available(iOS 11.0, *)) {
        return [[UIScreen mainScreen] isCaptured];
    }
    return NO;
}

float RandomFloat(float min, float max) {
    float r = (float)arc4random() / (float)UINT32_MAX;
    return min + r * (max - min);
}

CGPoint HumanizePoint(CGPoint p, float jitter) {
#if ENABLE_HUMANIZATION
    float jx = RandomFloat(-jitter, jitter);
    float jy = RandomFloat(-jitter, jitter);
    return CGPointMake(p.x + jx, p.y + jy);
#else
    return p;
#endif
}

void SafeLog(NSString* format, ...) {
#if ENABLE_LOGS
    va_list args;
    va_start(args, format);
    NSString* msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"%@", msg);
#else
    // No logging in release - critical for stealth
    // Logs can be dumped via Console and reveal cheat
    (void)format;
#endif
}

void TryHideDylib(void) {
#if ENABLE_DYLD_CHECK
    // Experimental: attempt to hide dylib
    // Real hiding requires hooking _dyld_get_image_name etc.
    // For now we just ensure we don't have obvious exports
    // Advanced technique would use: fishhook to hook dyld functions
    // This is left as placeholder - actual implementation is complex and may cause crashes
    // Safer to just use innocent name and strip symbols
#endif
}

BOOL IsAppActive(void) {
    return [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
}
