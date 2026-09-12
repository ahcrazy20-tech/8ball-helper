#import <UIKit/UIKit.h>

@interface OverlayWindow : UIWindow

+ (instancetype)shared;
- (void)show;
- (void)hide;
- (void)drawPredictionFromCue:(CGPoint)cue ghost:(CGPoint)ghost target:(CGPoint)target pocket:(CGPoint)pocket;
- (void)clear;

@property (nonatomic, assign) BOOL helperEnabled;

@end
