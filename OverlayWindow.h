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

// Core drawing - ball-by-ball mode (safe)
- (void)drawPredictionFromCue:(CGPoint)cue ghost:(CGPoint)ghost target:(CGPoint)target pocket:(CGPoint)pocket;
- (void)drawSingleBallShot:(NSDictionary*)shotData; // Ball-by-ball mode

// Wizard/Ninja features
- (void)drawBestShot:(NSDictionary*)bestShot; // Best shot solver
- (void)drawBankShot:(NSDictionary*)bankShot; // Bank shot with cushion point
- (void)drawCueLeave:(CGPoint)cueLeave isScratch:(BOOL)isScratch; // Cue leave + scratch warning
- (void)drawComboChain:(NSArray*)chain; // 3-ball combo chain (risky, optional)
- (void)drawCushionPath:(NSArray<NSValue*>*)path; // Bank cushion path

// Table calibration for newest version
- (void)updateTableBounds:(CGRect)bounds;

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

@property (nonatomic, assign) BOOL helperEnabled;
@property (nonatomic, assign) BOOL isPanicHidden;
@property (nonatomic, assign) CGRect tableBounds;

@end

#endif
