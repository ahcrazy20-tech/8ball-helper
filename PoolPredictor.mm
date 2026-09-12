#import "PoolPredictor.h"
#import <Vision/Vision.h>
#import <CoreGraphics/CoreGraphics.h>
#include <vector>
#include <cmath>

@implementation PoolPredictor

+ (CGPoint)ghostBallForTarget:(CGPoint)target pocket:(CGPoint)pocket radius:(CGFloat)radius {
    // Vector target -> pocket
    CGPoint dir = CGPointMake(pocket.x - target.x, pocket.y - target.y);
    CGFloat len = sqrt(dir.x*dir.x + dir.y*dir.y);
    if (len == 0) return target;
    dir.x /= len;
    dir.y /= len;
    
    // Ghost = target - dir * 2*radius
    return CGPointMake(target.x - dir.x * radius * 2.0, target.y - dir.y * radius * 2.0);
}

+ (CGFloat)angleBetweenCue:(CGPoint)cue ghost:(CGPoint)ghost target:(CGPoint)target pocket:(CGPoint)pocket {
    CGPoint v1 = CGPointMake(ghost.x - cue.x, ghost.y - cue.y);
    CGPoint v2 = CGPointMake(pocket.x - target.x, pocket.y - target.y);
    CGFloat len1 = sqrt(v1.x*v1.x + v1.y*v1.y);
    CGFloat len2 = sqrt(v2.x*v2.x + v2.y*v2.y);
    if (len1==0 || len2==0) return 180;
    v1.x/=len1; v1.y/=len1;
    v2.x/=len2; v2.y/=len2;
    CGFloat dot = v1.x*v2.x + v1.y*v2.y;
    dot = fmax(-1.0, fmin(1.0, dot));
    return acos(dot) * 180.0 / M_PI;
}

+ (NSDictionary*)calculateShotFromCue:(CGPoint)cue target:(CGPoint)target pocket:(CGPoint)pocket radius:(CGFloat)radius {
    CGPoint ghost = [self ghostBallForTarget:target pocket:pocket radius:radius];
    CGFloat angle = [self angleBetweenCue:cue ghost:ghost target:target pocket:pocket];
    CGFloat distCue = hypot(cue.x - ghost.x, cue.y - ghost.y);
    CGFloat distTarget = hypot(target.x - pocket.x, target.y - pocket.y);
    
    return @{
        @"ghost": [NSValue valueWithCGPoint:ghost],
        @"angle": @(angle),
        @"distCue": @(distCue),
        @"distTarget": @(distTarget)
    };
}

+ (NSDictionary*)findBestShot:(CGPoint)cue balls:(NSArray<NSValue*>*)balls pockets:(NSArray<NSValue*>*)pockets radius:(CGFloat)radius {
    NSDictionary* best = nil;
    CGFloat bestScore = 1e9;
    
    for (NSValue* bVal in balls) {
        CGPoint ball = [bVal CGPointValue];
        for (NSValue* pVal in pockets) {
            CGPoint pocket = [pVal CGPointValue];
            NSDictionary* shot = [self calculateShotFromCue:cue target:ball pocket:pocket radius:radius];
            CGFloat angle = [shot[@"angle"] floatValue];
            if (angle > 60) continue; // too hard
            CGFloat score = angle + [shot[@"distCue"] floatValue]*0.01;
            if (score < bestScore) {
                bestScore = score;
                best = @{
                    @"target": bVal,
                    @"pocket": pVal,
                    @"shot": shot,
                    @"score": @(score)
                };
            }
        }
    }
    return best;
}

// Simple color-based detection - works without ML, replace with CoreML YOLO later
+ (NSDictionary*)detectBallsInImage:(UIImage*)screenshot tableBounds:(CGRect)bounds {
    // This is placeholder - in real dylib you'd use Vision or OpenCV
    // For now we return empty and let Tweak.x use manual tap positions
    // TODO: Implement with CVPixelBuffer + HSV filter similar to Python detector.py
    
    // Example using Vision to find circles would go here
    // VNRecognizedTextObservation etc.
    
    return @{
        @"cue": [NSValue valueWithCGPoint:CGPointMake(bounds.origin.x + bounds.size.width*0.2, bounds.origin.y + bounds.size.height*0.5)],
        @"balls": @[
            [NSValue valueWithCGPoint:CGPointMake(bounds.origin.x + bounds.size.width*0.5, bounds.origin.y + bounds.size.height*0.5)],
            [NSValue valueWithCGPoint:CGPointMake(bounds.origin.x + bounds.size.width*0.6, bounds.origin.y + bounds.size.height*0.4)]
        ],
        @"pockets": @[
            [NSValue valueWithCGPoint:CGPointMake(bounds.origin.x, bounds.origin.y)],
            [NSValue valueWithCGPoint:CGPointMake(bounds.origin.x + bounds.size.width/2, bounds.origin.y)],
            [NSValue valueWithCGPoint:CGPointMake(bounds.origin.x + bounds.size.width, bounds.origin.y)],
            [NSValue valueWithCGPoint:CGPointMake(bounds.origin.x, bounds.origin.y + bounds.size.height)],
            [NSValue valueWithCGPoint:CGPointMake(bounds.origin.x + bounds.size.width/2, bounds.origin.y + bounds.size.height)],
            [NSValue valueWithCGPoint:CGPointMake(bounds.origin.x + bounds.size.width, bounds.origin.y + bounds.size.height)]
        ]
    };
}

@end
