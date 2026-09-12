#import <UIKit/UIKit.h>
#import "Config.h"

// Stealth: Use innocent class name in binary to avoid detection
// The actual class name that will appear in binary is _UIFeedbackOverlay (looks like system)
// We provide OverlayWindow as a macro alias for ease of use in code

#if USE_INNOCENT_CLASS_NAMES
// Real class name is innocent
@interface _UIFeedbackOverlay : UIWindow

+ (instancetype)shared;
+ (instancetype)feedbackShared;
- (void)show;
- (void)hide;
- (void)drawPredictionFromCue:(CGPoint)cue ghost:(CGPoint)ghost target:(CGPoint)target pocket:(CGPoint)pocket;
- (void)clear;
- (void)panicHide;

@property (nonatomic, assign) BOOL helperEnabled;
@property (nonatomic, assign) BOOL isPanicHidden;

@end

// Alias for backward compatibility - code can use OverlayWindow but binary has _UIFeedbackOverlay
#define OverlayWindow _UIFeedbackOverlay

#else
// Non-stealth mode: normal name
@interface OverlayWindow : UIWindow

+ (instancetype)shared;
+ (instancetype)feedbackShared;
- (void)show;
- (void)hide;
- (void)drawPredictionFromCue:(CGPoint)cue ghost:(CGPoint)ghost target:(CGPoint)target pocket:(CGPoint)pocket;
- (void)clear;
- (void)panicHide;

@property (nonatomic, assign) BOOL helperEnabled;
@property (nonatomic, assign) BOOL isPanicHidden;

@end

#endif
