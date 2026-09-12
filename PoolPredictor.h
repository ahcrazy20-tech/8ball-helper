#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Config.h"

#if USE_INNOCENT_CLASS_NAMES

@interface _UGraphicsHelper : NSObject

// Core
+ (CGPoint)ghostBallForTarget:(CGPoint)target pocket:(CGPoint)pocket radius:(CGFloat)radius;
+ (CGFloat)angleBetweenCue:(CGPoint)cue ghost:(CGPoint)ghost target:(CGPoint)target pocket:(CGPoint)pocket;
+ (NSDictionary*)calculateShotFromCue:(CGPoint)cue target:(CGPoint)target pocket:(CGPoint)pocket radius:(CGFloat)radius;
+ (CGPoint)humanizedGhost:(CGPoint)ghost;

// Best shot solver
+ (NSDictionary*)findBestShot:(CGPoint)cue balls:(NSArray<NSValue*>*)balls pockets:(NSArray<NSValue*>*)pockets radius:(CGFloat)radius maxAngle:(CGFloat)maxAngle;

// Bank shots
+ (NSDictionary*)findBestBankShot:(CGPoint)cue balls:(NSArray<NSValue*>*)balls pockets:(NSArray<NSValue*>*)pockets tableBounds:(CGRect)tableBounds radius:(CGFloat)radius;

// Cue leave & scratch
+ (CGPoint)predictCueLeave:(CGPoint)cue ghost:(CGPoint)ghost target:(CGPoint)target pocket:(CGPoint)pocket power:(CGFloat)power tableBounds:(CGRect)tableBounds;
+ (BOOL)isScratch:(CGPoint)cueLeave pockets:(NSArray<NSValue*>*)pockets radius:(CGFloat)radius;

// Combo chain
+ (NSArray*)findComboChain:(CGPoint)cue balls:(NSArray<NSValue*>*)balls pockets:(NSArray<NSValue*>*)pockets radius:(CGFloat)radius maxBalls:(NSInteger)maxBalls;

// Cushion path
+ (NSArray<NSValue*>*)predictCushionPath:(CGPoint)start direction:(CGPoint)direction tableBounds:(CGRect)tableBounds maxBounces:(NSInteger)maxBounces;

// Ball-by-ball
+ (NSDictionary*)calculateSingleBallShot:(CGPoint)cue target:(CGPoint)target pocket:(CGPoint)pocket radius:(CGFloat)radius;

// Vision & calibration
+ (NSDictionary*)detectBallsInImage:(UIImage*)screenshot tableBounds:(CGRect)bounds;
+ (CGRect)calibratedTableBounds:(CGRect)screenBounds manualOffset:(CGRect)offset;

// ==================== AUTO POWER SUGGESTION (SAFER AUTO SHOT) ====================
// Suggests power based on distance, with humanization (NOT 100% accuracy)
// Safer than 100% auto-play: suggests power, optionally auto-adjusts with jitter

+ (CGFloat)calculateSuggestedPower:(CGPoint)cue ghost:(CGPoint)ghost target:(CGPoint)target pocket:(CGPoint)pocket accuracy:(CGFloat)accuracy;
+ (CGFloat)humanizedPower:(CGFloat)power accuracy:(CGFloat)accuracy;
+ (NSDictionary*)calculateShotWithPower:(CGPoint)cue target:(CGPoint)target pocket:(CGPoint)pocket radius:(CGFloat)radius accuracy:(CGFloat)accuracy;

@end

#define PoolPredictor _UGraphicsHelper

#else

@interface PoolPredictor : NSObject

+ (CGPoint)ghostBallForTarget:(CGPoint)target pocket:(CGPoint)pocket radius:(CGFloat)radius;
+ (CGFloat)angleBetweenCue:(CGPoint)cue ghost:(CGPoint)ghost target:(CGPoint)target pocket:(CGPoint)pocket;
+ (NSDictionary*)calculateShotFromCue:(CGPoint)cue target:(CGPoint)target pocket:(CGPoint)pocket radius:(CGFloat)radius;
+ (CGPoint)humanizedGhost:(CGPoint)ghost;
+ (NSDictionary*)findBestShot:(CGPoint)cue balls:(NSArray<NSValue*>*)balls pockets:(NSArray<NSValue*>*)pockets radius:(CGFloat)radius maxAngle:(CGFloat)maxAngle;
+ (NSDictionary*)findBestBankShot:(CGPoint)cue balls:(NSArray<NSValue*>*)balls pockets:(NSArray<NSValue*>*)pockets tableBounds:(CGRect)tableBounds radius:(CGFloat)radius;
+ (CGPoint)predictCueLeave:(CGPoint)cue ghost:(CGPoint)ghost target:(CGPoint)target pocket:(CGPoint)pocket power:(CGFloat)power tableBounds:(CGRect)tableBounds;
+ (BOOL)isScratch:(CGPoint)cueLeave pockets:(NSArray<NSValue*>*)pockets radius:(CGFloat)radius;
+ (NSArray*)findComboChain:(CGPoint)cue balls:(NSArray<NSValue*>*)balls pockets:(NSArray<NSValue*>*)pockets radius:(CGFloat)radius maxBalls:(NSInteger)maxBalls;
+ (NSArray<NSValue*>*)predictCushionPath:(CGPoint)start direction:(CGPoint)direction tableBounds:(CGRect)tableBounds maxBounces:(NSInteger)maxBounces;
+ (NSDictionary*)calculateSingleBallShot:(CGPoint)cue target:(CGPoint)target pocket:(CGPoint)pocket radius:(CGFloat)radius;
+ (NSDictionary*)detectBallsInImage:(UIImage*)screenshot tableBounds:(CGRect)bounds;
+ (CGRect)calibratedTableBounds:(CGRect)screenBounds manualOffset:(CGRect)offset;
+ (CGFloat)calculateSuggestedPower:(CGPoint)cue ghost:(CGPoint)ghost target:(CGPoint)target pocket:(CGPoint)pocket accuracy:(CGFloat)accuracy;
+ (CGFloat)humanizedPower:(CGFloat)power accuracy:(CGFloat)accuracy;
+ (NSDictionary*)calculateShotWithPower:(CGPoint)cue target:(CGPoint)target pocket:(CGPoint)pocket radius:(CGFloat)radius accuracy:(CGFloat)accuracy;

@end

#endif
