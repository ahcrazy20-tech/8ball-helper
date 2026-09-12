#ifndef STEALTH_H
#define STEALTH_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Config.h"

#ifdef __cplusplus
extern "C" {
#endif

// ==================== STEALTH UTILITIES ====================

// Check if debugger attached via sysctl
BOOL IsDebuggerAttached(void);

// Anti-debug using ptrace
void AntiDebug(void);

// Check if running in target bundle
BOOL IsValidBundle(void);

// Check if screen is being captured (screen recording)
BOOL IsScreenCaptured(void);

// Get random float in range
float RandomFloat(float min, float max);

// Humanize point with small jitter
CGPoint HumanizePoint(CGPoint p, float jitter);

// Safe log - only logs if ENABLE_LOGS
void SafeLog(NSString* format, ...);

// Hide dylib from dyld image list (experimental, may not work on iOS 16+)
void TryHideDylib(void);

// Check if app is in background or inactive
BOOL IsAppActive(void);

#ifdef __cplusplus
}
#endif

// Objective-C interface for stealth manager
@interface StealthManager : NSObject
+ (instancetype)shared;
- (BOOL)shouldActivate; // bundle + safety checks
- (void)setupAntiDetection;
- (void)setupScreenCaptureObserver:(id)target selector:(SEL)sel;
- (float)randomDelay;
@end

#endif
