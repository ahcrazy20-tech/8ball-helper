#import "PoolPredictor.h"
#import "Config.h"
#import "Stealth.h"
#import <Vision/Vision.h>
#import <CoreGraphics/CoreGraphics.h>
#include <vector>
#include <cmath>

@implementation PoolPredictor

// ==================== CORE - GHOST BALL ====================

+ (CGPoint)ghostBallForTarget:(CGPoint)target pocket:(CGPoint)pocket radius:(CGFloat)radius {
    CGPoint dir = CGPointMake(pocket.x - target.x, pocket.y - target.y);
    CGFloat len = sqrt(dir.x*dir.x + dir.y*dir.y);
    if (len == 0) return target;
    dir.x /= len; dir.y /= len;
    CGPoint ghost = CGPointMake(target.x - dir.x * radius * 2.0, target.y - dir.y * radius * 2.0);
#if ENABLE_HUMANIZATION
    ghost = HumanizePoint(ghost, HUMAN_JITTER_PIXELS * 0.5);
#endif
    return ghost;
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
    CGFloat angle = acos(dot) * 180.0 / M_PI;
#if ENABLE_HUMANIZATION
    angle += RandomFloat(-HUMAN_ANGLE_NOISE, HUMAN_ANGLE_NOISE);
#endif
    return angle;
}

+ (NSDictionary*)calculateShotFromCue:(CGPoint)cue target:(CGPoint)target pocket:(CGPoint)pocket radius:(CGFloat)radius {
    CGPoint ghost = [self ghostBallForTarget:target pocket:pocket radius:radius];
    CGFloat angle = [self angleBetweenCue:cue ghost:ghost target:target pocket:pocket];
    CGFloat distCue = hypot(cue.x - ghost.x, cue.y - ghost.y);
    CGFloat distTarget = hypot(target.x - pocket.x, target.y - pocket.y);
    
    // Direction vectors
    CGPoint cueDir = CGPointMake(ghost.x - cue.x, ghost.y - cue.y);
    CGFloat len = hypot(cueDir.x, cueDir.y);
    if (len != 0) { cueDir.x /= len; cueDir.y /= len; }
    CGPoint targetDir = CGPointMake(pocket.x - target.x, pocket.y - target.y);
    len = hypot(targetDir.x, targetDir.y);
    if (len != 0) { targetDir.x /= len; targetDir.y /= len; }
    
    return @{
        @"ghost": [NSValue valueWithCGPoint:ghost],
        @"angle": @(angle),
        @"distCue": @(distCue),
        @"distTarget": @(distTarget),
        @"cueDir": [NSValue valueWithCGPoint:cueDir],
        @"targetDir": [NSValue valueWithCGPoint:targetDir]
    };
}

+ (CGPoint)humanizedGhost:(CGPoint)ghost {
#if ENABLE_HUMANIZATION
    return HumanizePoint(ghost, HUMAN_JITTER_PIXELS);
#else
    return ghost;
#endif
}

// ==================== BALL-BY-BALL MODE (YOUR SAFETY REQUEST) ====================
// Only calculates for ONE ball and ONE pocket, no auto search for 3 balls
// This is safest - looks human, you select ball by ball

+ (NSDictionary*)calculateSingleBallShot:(CGPoint)cue target:(CGPoint)target pocket:(CGPoint)pocket radius:(CGFloat)radius {
    // Just one ball, one pocket - no searching
    NSDictionary *shot = [self calculateShotFromCue:cue target:target pocket:pocket radius:radius];
    return @{
        @"target": [NSValue valueWithCGPoint:target],
        @"pocket": [NSValue valueWithCGPoint:pocket],
        @"shot": shot,
        @"isSingleBall": @YES // Flag for ball-by-ball mode
    };
}

// ==================== BEST SHOT SOLVER (Wizard feature) ====================

+ (NSDictionary*)findBestShot:(CGPoint)cue balls:(NSArray<NSValue*>*)balls pockets:(NSArray<NSValue*>*)pockets radius:(CGFloat)radius maxAngle:(CGFloat)maxAngle {
    NSDictionary* best = nil;
    CGFloat bestScore = 1e9;
    
    for (NSValue* bVal in balls) {
        CGPoint ball = [bVal CGPointValue];
        for (NSValue* pVal in pockets) {
            CGPoint pocket = [pVal CGPointValue];
            NSDictionary* shot = [self calculateShotFromCue:cue target:ball pocket:pocket radius:radius];
            CGFloat angle = [shot[@"angle"] floatValue];
            
            // Safety filter
            if (angle > maxAngle) continue;
            if ([shot[@"distCue"] floatValue] < SAFETY_MIN_DISTANCE) continue;
            
            // Score: lower is easier - like Wizard's ranking by potting margin, scratch risk, position
            CGFloat score = angle + [shot[@"distCue"] floatValue]*0.01 + [shot[@"distTarget"] floatValue]*0.005;
            
            // Scratch risk penalty (if cue leave near pocket)
            // For simplicity, we add distance factor
            
#if ENABLE_HUMANIZATION
            score += RandomFloat(-2.0, 2.0);
#endif
            
            if (score < bestScore) {
                bestScore = score;
                best = @{
                    @"target": bVal,
                    @"pocket": pVal,
                    @"shot": shot,
                    @"score": @(score),
                    @"isSingleBall": @NO
                };
            }
        }
    }
    return best;
}

// ==================== BANK SHOTS (Wizard Bank Shots) ====================

+ (NSDictionary*)findBestBankShot:(CGPoint)cue balls:(NSArray<NSValue*>*)balls pockets:(NSArray<NSValue*>*)pockets tableBounds:(CGRect)tableBounds radius:(CGFloat)radius {
    // Bank shot: target ball bounces off cushion then to pocket
    // Calculate reflection
    NSDictionary* best = nil;
    CGFloat bestScore = 1e9;
    
    // For each ball, try each cushion as bounce
    NSArray *cushions = @[
        @{@"normal": [NSValue valueWithCGPoint:CGPointMake(1,0)], @"pos": @(tableBounds.origin.x)}, // left
        @{@"normal": [NSValue valueWithCGPoint:CGPointMake(-1,0)], @"pos": @(tableBounds.origin.x + tableBounds.size.width)}, // right
        @{@"normal": [NSValue valueWithCGPoint:CGPointMake(0,1)], @"pos": @(tableBounds.origin.y)}, // top
        @{@"normal": [NSValue valueWithCGPoint:CGPointMake(0,-1)], @"pos": @(tableBounds.origin.y + tableBounds.size.height)} // bottom
    ];
    
    for (NSValue* bVal in balls) {
        CGPoint ball = [bVal CGPointValue];
        for (NSValue* pVal in pockets) {
            CGPoint pocket = [pVal CGPointValue];
            
            // Try each cushion for bank
            for (NSDictionary *cushion in cushions) {
                CGPoint normal = [cushion[@"normal"] CGPointValue];
                // Reflect pocket across cushion to find bank point
                // Simplified: find point on cushion where angle in = angle out
                // For now, approximate bank point as middle of ball-pocket with cushion offset
                
                // Calculate bank point (where ball hits cushion)
                // Use reflection method: reflect pocket over cushion line
                CGPoint reflectedPocket = pocket;
                CGFloat cushionPos = [cushion[@"pos"] floatValue];
                if (normal.x != 0) {
                    // vertical cushion
                    reflectedPocket.x = 2*cushionPos - pocket.x;
                } else {
                    reflectedPocket.y = 2*cushionPos - pocket.y;
                }
                
                // Now find intersection of ball->reflectedPocket with cushion
                CGPoint dir = CGPointMake(reflectedPocket.x - ball.x, reflectedPocket.y - ball.y);
                CGFloat len = hypot(dir.x, dir.y);
                if (len == 0) continue;
                dir.x /= len; dir.y /= len;
                
                // Find t where it hits cushion
                CGFloat t = 0;
                CGPoint bankPoint = CGPointZero;
                if (normal.x != 0) {
                    if (dir.x == 0) continue;
                    t = (cushionPos - ball.x) / dir.x;
                    if (t <= 0) continue;
                    bankPoint = CGPointMake(cushionPos, ball.y + t*dir.y);
                    if (bankPoint.y < tableBounds.origin.y || bankPoint.y > tableBounds.origin.y + tableBounds.size.height) continue;
                } else {
                    if (dir.y == 0) continue;
                    t = (cushionPos - ball.y) / dir.y;
                    if (t <= 0) continue;
                    bankPoint = CGPointMake(ball.x + t*dir.x, cushionPos);
                    if (bankPoint.x < tableBounds.origin.x || bankPoint.x > tableBounds.origin.x + tableBounds.size.width) continue;
                }
                
                // Now calculate shot to bank point
                CGPoint ghost = [self ghostBallForTarget:ball pocket:bankPoint radius:radius];
                CGFloat angle = [self angleBetweenCue:cue ghost:ghost target:ball pocket:bankPoint];
                if (angle > SAFETY_MAX_ANGLE) continue;
                
                CGFloat score = angle + hypot(cue.x - ghost.x, cue.y - ghost.y)*0.01 + 10; // +10 penalty for bank (harder)
                if (score < bestScore) {
                    bestScore = score;
                    NSDictionary *shot = [self calculateShotFromCue:cue target:ball pocket:bankPoint radius:radius];
                    best = @{
                        @"target": bVal,
                        @"pocket": pVal,
                        @"bankPoint": [NSValue valueWithCGPoint:bankPoint],
                        @"shot": shot,
                        @"score": @(score),
                        @"isBank": @YES
                    };
                }
            }
        }
    }
    return best;
}

// ==================== CUE LEAVE & SCRATCH WARNING (Wizard features) ====================

+ (CGPoint)predictCueLeave:(CGPoint)cue ghost:(CGPoint)ghost target:(CGPoint)target pocket:(CGPoint)pocket power:(CGFloat)power tableBounds:(CGRect)tableBounds {
    // Predict where cue ball stops after hitting target
    // Simplified physics: cue ball follows tangent line after collision
    
    // Direction cue->ghost
    CGPoint cueDir = CGPointMake(ghost.x - cue.x, ghost.y - cue.y);
    CGFloat len = hypot(cueDir.x, cueDir.y);
    if (len != 0) { cueDir.x /= len; cueDir.y /= len; }
    
    // Direction target->pocket
    CGPoint targetDir = CGPointMake(pocket.x - target.x, pocket.y - target.y);
    len = hypot(targetDir.x, targetDir.y);
    if (len != 0) { targetDir.x /= len; targetDir.y /= len; }
    
    // Tangent: 90° from target direction
    // Cue ball after collision goes perpendicular to target direction (for stun shot)
    // Simplified: cue leave = ghost + tangent * power
    
    // Calculate tangent (perpendicular)
    CGPoint tangent = CGPointMake(-targetDir.y, targetDir.x);
    
    // Determine which side of tangent based on cue position
    CGPoint toCue = CGPointMake(cue.x - target.x, cue.y - target.y);
    CGFloat dot = toCue.x * tangent.x + toCue.y * tangent.y;
    if (dot < 0) {
        tangent.x = -tangent.x;
        tangent.y = -tangent.y;
    }
    
    // Power factor: 0-14 like Wizard, 0 = auto
    CGFloat powerFactor = (power == 0) ? 100 : power * 15;
    
    CGPoint leave = CGPointMake(ghost.x + tangent.x * powerFactor, ghost.y + tangent.y * powerFactor);
    
    // Clamp to table bounds
    leave.x = fmax(tableBounds.origin.x + 10, fmin(tableBounds.origin.x + tableBounds.size.width - 10, leave.x));
    leave.y = fmax(tableBounds.origin.y + 10, fmin(tableBounds.origin.y + tableBounds.size.height - 10, leave.y));
    
    return leave;
}

+ (BOOL)isScratch:(CGPoint)cueLeave pockets:(NSArray<NSValue*>*)pockets radius:(CGFloat)radius {
    // Check if cue leave is near any pocket (scratch risk)
    for (NSValue *pVal in pockets) {
        CGPoint pocket = [pVal CGPointValue];
        CGFloat dist = hypot(cueLeave.x - pocket.x, cueLeave.y - pocket.y);
        if (dist < radius * 2.5) { // Within 2.5x pocket radius = scratch
            return YES;
        }
    }
    return NO;
}

// ==================== COMBO & CAROM CHAIN (Wizard Combo Chain) ====================
// Shows 3 balls in one shot chain - RISKY, disabled by default for safety
// Your request: option to do 3-ball but also option for ball-by-ball only

+ (NSArray*)findComboChain:(CGPoint)cue balls:(NSArray<NSValue*>*)balls pockets:(NSArray<NSValue*>*)pockets radius:(CGFloat)radius maxBalls:(NSInteger)maxBalls {
    // Find chain: cue -> ball1 -> ball2 -> pocket
    // This is more detectable (server can flag multi-ball patterns), so disabled by default
    
    NSMutableArray *chains = [NSMutableArray array];
    
    if (balls.count < 2) return chains;
    
    // Try all combinations of 2-3 balls
    for (NSInteger i = 0; i < balls.count; i++) {
        CGPoint ball1 = [balls[i] CGPointValue];
        
        // First ball to pocket via second ball?
        for (NSInteger j = 0; j < balls.count; j++) {
            if (i == j) continue;
            CGPoint ball2 = [balls[j] CGPointValue];
            
            // ball1 should hit ball2 then ball2 to pocket
            for (NSValue *pVal in pockets) {
                CGPoint pocket = [pVal CGPointValue];
                
                // Calculate ghost for ball1 -> ball2
                CGPoint ghost1 = [self ghostBallForTarget:ball1 pocket:ball2.x radius:radius];
                CGFloat angle1 = [self angleBetweenCue:cue ghost:ghost1 target:ball1 pocket:ball2];
                if (angle1 > SAFETY_MAX_ANGLE) continue;
                
                // Calculate ghost for ball2 -> pocket
                CGPoint ghost2 = [self ghostBallForTarget:ball2 pocket:pocket radius:radius];
                CGFloat angle2 = [self angleBetweenCue:ball1 ghost:ghost2 target:ball2 pocket:pocket];
                if (angle2 > SAFETY_MAX_ANGLE) continue;
                
                CGFloat totalScore = angle1 + angle2;
                
                NSDictionary *chain = @{
                    @"balls": @[balls[i], balls[j]],
                    @"pocket": pVal,
                    @"ghost1": [NSValue valueWithCGPoint:ghost1],
                    @"ghost2": [NSValue valueWithCGPoint:ghost2],
                    @"score": @(totalScore),
                    @"isCombo": @YES
                };
                [chains addObject:chain];
                
                // If maxBalls == 3, try 3-ball chain
                if (maxBalls >= 3 && balls.count >= 3) {
                    for (NSInteger k = 0; k < balls.count; k++) {
                        if (k == i || k == j) continue;
                        CGPoint ball3 = [balls[k] CGPointValue];
                        
                        // ball2 -> ball3 -> pocket
                        CGPoint ghost2_3 = [self ghostBallForTarget:ball2 pocket:ball3 radius:radius];
                        CGFloat angle2_3 = [self angleBetweenCue:ball1 ghost:ghost2_3 target:ball2 pocket:ball3];
                        if (angle2_3 > SAFETY_MAX_ANGLE) continue;
                        
                        CGPoint ghost3 = [self ghostBallForTarget:ball3 pocket:pocket radius:radius];
                        CGFloat angle3 = [self angleBetweenCue:ball2 ghost:ghost3 target:ball3 pocket:pocket];
                        if (angle3 > SAFETY_MAX_ANGLE) continue;
                        
                        NSDictionary *chain3 = @{
                            @"balls": @[balls[i], balls[j], balls[k]],
                            @"pocket": pVal,
                            @"ghost1": [NSValue valueWithCGPoint:ghost1],
                            @"ghost2": [NSValue valueWithCGPoint:ghost2_3],
                            @"ghost3": [NSValue valueWithCGPoint:ghost3],
                            @"score": @(angle1 + angle2_3 + angle3),
                            @"isCombo": @YES,
                            @"is3Ball": @YES
                        };
                        [chains addObject:chain3];
                    }
                }
            }
        }
    }
    
    // Sort by score
    [chains sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"score"] compare:b[@"score"]];
    }];
    
    // Return top 3 chains
    if (chains.count > 3) {
        return [chains subarrayWithRange:NSMakeRange(0, 3)];
    }
    return chains;
}

// ==================== CUSHION PATH ====================

+ (NSArray<NSValue*>*)predictCushionPath:(CGPoint)start direction:(CGPoint)direction tableBounds:(CGRect)tableBounds maxBounces:(NSInteger)maxBounces {
    NSMutableArray *path = [NSMutableArray array];
    [path addObject:[NSValue valueWithCGPoint:start]];
    
    CGPoint pos = start;
    CGPoint dir = direction;
    CGFloat len = hypot(dir.x, dir.y);
    if (len != 0) { dir.x /= len; dir.y /= len; }
    
    for (NSInteger i = 0; i < maxBounces; i++) {
        CGFloat tMin = 1e9;
        CGPoint hitPoint = CGPointZero;
        CGPoint normal = CGPointZero;
        
        // Check each wall
        if (dir.x != 0) {
            // Left
            CGFloat t = (tableBounds.origin.x - pos.x) / dir.x;
            if (t > 0.1 && t < tMin) {
                CGFloat y = pos.y + t * dir.y;
                if (y >= tableBounds.origin.y && y <= tableBounds.origin.y + tableBounds.size.height) {
                    tMin = t;
                    hitPoint = CGPointMake(tableBounds.origin.x, y);
                    normal = CGPointMake(1, 0);
                }
            }
            // Right
            t = (tableBounds.origin.x + tableBounds.size.width - pos.x) / dir.x;
            if (t > 0.1 && t < tMin) {
                CGFloat y = pos.y + t * dir.y;
                if (y >= tableBounds.origin.y && y <= tableBounds.origin.y + tableBounds.size.height) {
                    tMin = t;
                    hitPoint = CGPointMake(tableBounds.origin.x + tableBounds.size.width, y);
                    normal = CGPointMake(-1, 0);
                }
            }
        }
        if (dir.y != 0) {
            // Top
            CGFloat t = (tableBounds.origin.y - pos.y) / dir.y;
            if (t > 0.1 && t < tMin) {
                CGFloat x = pos.x + t * dir.x;
                if (x >= tableBounds.origin.x && x <= tableBounds.origin.x + tableBounds.size.width) {
                    tMin = t;
                    hitPoint = CGPointMake(x, tableBounds.origin.y);
                    normal = CGPointMake(0, 1);
                }
            }
            // Bottom
            t = (tableBounds.origin.y + tableBounds.size.height - pos.y) / dir.y;
            if (t > 0.1 && t < tMin) {
                CGFloat x = pos.x + t * dir.x;
                if (x >= tableBounds.origin.x && x <= tableBounds.origin.x + tableBounds.size.width) {
                    tMin = t;
                    hitPoint = CGPointMake(x, tableBounds.origin.y + tableBounds.size.height);
                    normal = CGPointMake(0, -1);
                }
            }
        }
        
        if (tMin == 1e9) break;
        
        [path addObject:[NSValue valueWithCGPoint:hitPoint]];
        
        // Reflect
        CGFloat dot = dir.x * normal.x + dir.y * normal.y;
        dir.x = dir.x - 2 * dot * normal.x;
        dir.y = dir.y - 2 * dot * normal.y;
        pos = CGPointMake(hitPoint.x + dir.x * 2, hitPoint.y + dir.y * 2);
    }
    
    // Final extension
    CGPoint final = CGPointMake(pos.x + dir.x * 500, pos.y + dir.y * 500);
    [path addObject:[NSValue valueWithCGPoint:final]];
    
    return path;
}

// ==================== VISION DETECTION (Supports newest version) ====================

+ (NSDictionary*)detectBallsInImage:(UIImage*)screenshot tableBounds:(CGRect)bounds {
    // Placeholder - in real dylib you'd use Vision or CoreML YOLO
    // For newest version support, we use dynamic bounds detection
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

+ (CGRect)calibratedTableBounds:(CGRect)screenBounds manualOffset:(CGRect)offset {
    // Support newest version with manual calibration
    // Auto-detect table bounds with margins
    CGRect base = CGRectMake(screenBounds.origin.x + DEFAULT_TABLE_MARGIN_X,
                            screenBounds.origin.y + DEFAULT_TABLE_MARGIN_Y_TOP,
                            screenBounds.size.width - 2*DEFAULT_TABLE_MARGIN_X,
                            screenBounds.size.height - DEFAULT_TABLE_MARGIN_Y_TOP - DEFAULT_TABLE_MARGIN_Y_BOTTOM);
    
    // Apply manual offset if provided
    if (!CGRectEqualToRect(offset, CGRectZero)) {
        base.origin.x += offset.origin.x;
        base.origin.y += offset.origin.y;
        base.size.width += offset.size.width;
        base.size.height += offset.size.height;
    }
    
    return base;
}

@end
