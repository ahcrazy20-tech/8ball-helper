#import <UIKit/UIKit.h>
#import "Config.h"

#if USE_INNOCENT_CLASS_NAMES
@interface _UIFeedbackOverlay : UIWindow

+ (instancetype)shared;
+ (instancetype)feedbackShared;
- (void)show;
- (void)hide;
- (void)clear;
- (void)panicHide;

- (void)drawPredictionFromCue:(CGPoint)cue ghost:(CGPoint)ghost target:(CGPoint)target pocket:(CGPoint)pocket;
- (void)drawSingleBallShot:(NSDictionary*)shotData;
- (void)drawBestShot:(NSDictionary*)bestShot;
- (void)drawBankShot:(NSDictionary*)bankShot;
- (void)drawCueLeave:(CGPoint)cueLeave isScratch:(BOOL)isScratch;
- (void)drawComboChain:(NSArray*)chain;
- (void)drawCushionPath:(NSArray<NSValue*>*)path;
- (void)updateTableBounds:(CGRect)bounds;

// Auto power suggestion (safer auto shot)
- (void)drawPowerSuggestion:(CGFloat)power accuracy:(CGFloat)accuracy;
- (void)showAutoShotIndicator:(BOOL)show;

@property (nonatomic, assign) BOOL helperEnabled;
@property (nonatomic, assign) BOOL isPanicHidden;
@property (nonatomic, assign) CGRect tableBounds;

@end

#define OverlayWindow _UIFeedbackOverlay

#else

@interface OverlayWindow : UIWindow

+ (instancetype)shared;
+ (instancetype)feedbackShared;
- (void)show;
- (void)hide;
- (void)clear;
- (void)panicHide;
- (void)drawPredictionFromCue:(CGPoint)cue ghost:(CGPoint)ghost target:(CGPoint)target pocket:(CGPoint)pocket;
- (void)drawSingleBallShot:(NSDictionary*)shotData;
- (void)drawBestShot:(NSDictionary*)bestShot;
- (void)drawBankShot:(NSDictionary*)bankShot;
- (void)drawCueLeave:(CGPoint)cueLeave isScratch:(BOOL)isScratch;
- (void)drawComboChain:(NSArray*)chain;
- (void)drawCushionPath:(NSArray<NSValue*>*)path;
- (void)updateTableBounds:(CGRect)bounds;
- (void)drawPowerSuggestion:(CGFloat)power accuracy:(CGFloat)accuracy;
- (void)showAutoShotIndicator:(BOOL)show;

@property (nonatomic, assign) BOOL helperEnabled;
@property (nonatomic, assign) BOOL isPanicHidden;
@property (nonatomic, assign) CGRect tableBounds;

@end

#endif
