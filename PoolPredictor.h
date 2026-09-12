#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PoolPredictor : NSObject

// Ghost ball calculation - same physics as PC version
+ (CGPoint)ghostBallForTarget:(CGPoint)target pocket:(CGPoint)pocket radius:(CGFloat)radius;
+ (CGFloat)angleBetweenCue:(CGPoint)cue ghost:(CGPoint)ghost target:(CGPoint)target pocket:(CGPoint)pocket;
+ (NSDictionary*)calculateShotFromCue:(CGPoint)cue target:(CGPoint)target pocket:(CGPoint)pocket radius:(CGFloat)radius;

// Vision detection - find balls from screenshot
+ (NSDictionary*)detectBallsInImage:(UIImage*)screenshot tableBounds:(CGRect)bounds;

// Best shot
+ (NSDictionary*)findBestShot:(CGPoint)cue balls:(NSArray<NSValue*>*)balls pockets:(NSArray<NSValue*>*)pockets radius:(CGFloat)radius;

@end
