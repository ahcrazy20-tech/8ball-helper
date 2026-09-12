#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "Config.h"

#if USE_INNOCENT_CLASS_NAMES

@interface _UGraphicsHelper : NSObject

// Core - Ghost ball (safe)
+ (CGPoint)ghostBallForTarget:(CGPoint)target pocket:(CGPoint)pocket radius:(CGFloat)radius;
+ (CGFloat)angleBetweenCue:(CGPoint)cue ghost:(CGPoint)ghost target:(CGPoint)target pocket:(CGPoint)pocket;
+ (NSDictionary*)calculateShotFromCue:(CGPoint)cue target:(CGPoint)target pocket:(CGPoint)pocket radius:(CGFloat)radius;
+ (CGPoint)humanizedGhost:(CGPoint)ghost;

// Best shot solver (Wizard feature) - sweeps all angles
+ (NSDictionary*)findBestShot:(CGPoint)cue balls:(NSArray<NSValue*>*)balls pockets:(NSArray<NSValue*>*)pockets radius:(CGFloat)radius maxAngle:(CGFloat)maxAngle;

// Bank shots (Wizard Bank Shots) - 1-cushion reflection
+ (NSDictionary*)findBestBankShot:(CGPoint)cue balls:(NSArray<NSValue*>*)balls pockets:(NSArray<NSValue*>*)pockets tableBounds:(CGRect)tableBounds radius:(CGFloat)radius;

// Cue leave & scratch warning (Wizard features)
+ (CGPoint)predictCueLeave:(CGPoint)cue ghost:(CGPoint)ghost target:(CGPoint)target pocket:(CGPoint)pocket power:(CGFloat)power tableBounds:(CGRect)tableBounds;
+ (BOOL)isScratch:(CGPoint)cueLeave pockets:(NSArray<NSValue*>*)pockets radius:(CGFloat)radius;

// Combo & Carom chain (Wizard Combo Chain) - 3 balls in one shot
+ (NSArray*)findComboChain:(CGPoint)cue balls:(NSArray<NSValue*>*)balls pockets:(NSArray<NSValue*>*)pockets radius:(CGFloat)radius maxBalls:(NSInteger)maxBalls;

// Cushion prediction (for bank shots)
+ (NSArray<NSValue*>*)predictCushionPath:(CGPoint)start direction:(CGPoint)direction tableBounds:(CGRect)tableBounds maxBounces:(NSInteger)maxBounces;

// Ball-by-ball mode (Safety feature - your request)
+ (NSDictionary*)calculateSingleBallShot:(CGPoint)cue target:(CGPoint)target pocket:(CGPoint)pocket radius:(CGFloat)radius; // Only one ball, no auto search

// Vision detection (supports newest version 56.29.x)
+ (NSDictionary*)detectBallsInImage:(UIImage*)screenshot tableBounds:(CGRect)bounds;

// Table calibration for newest version
+ (CGRect)calibratedTableBounds:(CGRect)screenBounds manualOffset:(CGRect)offset;

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

@end

#endif
