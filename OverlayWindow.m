#import "OverlayWindow.h"
#import "Config.h"
#import "Stealth.h"
#import "ModMenu.h"
#import <QuartzCore/QuartzCore.h>

@interface OverlayWindow ()
@property (nonatomic, strong) CAShapeLayer *cueLineLayer;
@property (nonatomic, strong) CAShapeLayer *targetLineLayer;
@property (nonatomic, strong) CAShapeLayer *ghostLayer;
@property (nonatomic, strong) CAShapeLayer *bankLineLayer;
@property (nonatomic, strong) CAShapeLayer *cueLeaveLayer;
@property (nonatomic, strong) CAShapeLayer *scratchLayer;
@property (nonatomic, strong) CAShapeLayer *comboLayer;
@property (nonatomic, strong) CAShapeLayer *cushionLayer;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UILabel *infoLabel; // For HUD
@end

@implementation OverlayWindow

+ (instancetype)shared {
    static OverlayWindow *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initWithFrame:[UIScreen mainScreen].bounds];
    });
    return instance;
}

+ (instancetype)feedbackShared {
    return [self shared];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelStatusBar + 1;
        self.backgroundColor = [UIColor clearColor];
        self.hidden = YES;
        self.helperEnabled = !DEFAULT_HIDDEN;
        self.isPanicHidden = NO;
        self.tableBounds = CGRectZero;
        
        self.containerView = [[UIView alloc] initWithFrame:frame];
        self.containerView.backgroundColor = [UIColor clearColor];
        self.containerView.userInteractionEnabled = NO;
        self.containerView.tag = 0xCAFE;
        
        // Cue line - yellow
        self.cueLineLayer = [CAShapeLayer layer];
        self.cueLineLayer.strokeColor = [[UIColor colorWithRed:1.0 green:0.92 blue:0.23 alpha:LINE_ALPHA] CGColor];
        self.cueLineLayer.lineWidth = DEFAULT_LINE_THICKNESS;
        self.cueLineLayer.fillColor = nil;
        self.cueLineLayer.lineCap = kCALineCapRound;
        self.cueLineLayer.lineJoin = kCALineJoinRound;
        
        // Target line - green
        self.targetLineLayer = [CAShapeLayer layer];
        self.targetLineLayer.strokeColor = [[UIColor colorWithRed:0.2 green:0.9 blue:0.2 alpha:LINE_ALPHA] CGColor];
        self.targetLineLayer.lineWidth = DEFAULT_LINE_THICKNESS;
        self.targetLineLayer.fillColor = nil;
        self.targetLineLayer.lineCap = kCALineCapRound;
        
        // Ghost ball
        self.ghostLayer = [CAShapeLayer layer];
        self.ghostLayer.strokeColor = [[UIColor colorWithRed:1.0 green:0.92 blue:0.23 alpha:0.9] CGColor];
        self.ghostLayer.lineWidth = 1.5;
        self.ghostLayer.fillColor = [[UIColor clearColor] CGColor];
        
        // Bank line - cyan for bank shots (Wizard)
        self.bankLineLayer = [CAShapeLayer layer];
        self.bankLineLayer.strokeColor = [[UIColor colorWithRed:0.0 green:0.8 blue:1.0 alpha:LINE_ALPHA] CGColor];
        self.bankLineLayer.lineWidth = 2.0;
        self.bankLineLayer.fillColor = nil;
        self.bankLineLayer.lineDashPattern = @[@4, @3];
        
        // Cue leave - white dotted
        self.cueLeaveLayer = [CAShapeLayer layer];
        self.cueLeaveLayer.strokeColor = [[UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.6] CGColor];
        self.cueLeaveLayer.lineWidth = 1.5;
        self.cueLeaveLayer.fillColor = nil;
        self.cueLeaveLayer.lineDashPattern = @[@5, @5];
        
        // Scratch warning - red circle
        self.scratchLayer = [CAShapeLayer layer];
        self.scratchLayer.strokeColor = [[UIColor redColor] CGColor];
        self.scratchLayer.lineWidth = 2.5;
        self.scratchLayer.fillColor = [[UIColor redColor] colorWithAlphaComponent:0.2].CGColor;
        
        // Combo chain - orange
        self.comboLayer = [CAShapeLayer layer];
        self.comboLayer.strokeColor = [[UIColor orangeColor] CGColor];
        self.comboLayer.lineWidth = 2.0;
        self.comboLayer.fillColor = nil;
        
        // Cushion path - light blue
        self.cushionLayer = [CAShapeLayer layer];
        self.cushionLayer.strokeColor = [[UIColor colorWithRed:0.3 green:0.7 blue:1.0 alpha:0.7] CGColor];
        self.cushionLayer.lineWidth = 1.5;
        self.cushionLayer.fillColor = nil;
        self.cushionLayer.lineDashPattern = @[@6, @4];
        
        [self.containerView.layer addSublayer:self.cueLineLayer];
        [self.containerView.layer addSublayer:self.targetLineLayer];
        [self.containerView.layer addSublayer:self.ghostLayer];
        [self.containerView.layer addSublayer:self.bankLineLayer];
        [self.containerView.layer addSublayer:self.cueLeaveLayer];
        [self.containerView.layer addSublayer:self.scratchLayer];
        [self.containerView.layer addSublayer:self.comboLayer];
        [self.containerView.layer addSublayer:self.cushionLayer];
        
        [self addSubview:self.containerView];
        
        // Info label for HUD (Wizard Info HUD)
        self.infoLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, frame.size.height - 60, 200, 40)];
        self.infoLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
        self.infoLabel.textColor = [UIColor whiteColor];
        self.infoLabel.font = [UIFont systemFontOfSize:10];
        self.infoLabel.numberOfLines = 2;
        self.infoLabel.layer.cornerRadius = 6;
        self.infoLabel.layer.masksToBounds = YES;
        self.infoLabel.textAlignment = NSTextAlignmentCenter;
        self.infoLabel.hidden = YES;
        [self addSubview:self.infoLabel];
        
        // Tiny toggle button - stealth
        self.toggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.toggleButton.frame = CGRectMake(3, 35, 10, 10);
        self.toggleButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15];
        self.toggleButton.layer.cornerRadius = 5;
        self.toggleButton.alpha = 0.3;
        self.toggleButton.userInteractionEnabled = YES;
        [self.toggleButton addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside];
        
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        longPress.minimumPressDuration = 1.5;
        [self.toggleButton addGestureRecognizer:longPress];
        
        UIView *buttonContainer = [[UIView alloc] initWithFrame:frame];
        buttonContainer.backgroundColor = [UIColor clearColor];
        buttonContainer.userInteractionEnabled = YES;
        [buttonContainer addSubview:self.toggleButton];
        [self addSubview:buttonContainer];
        
        self.userInteractionEnabled = YES;
        
#if ENABLE_PANIC_GESTURE
        UITapGestureRecognizer *panicTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(panicHide)];
        panicTap.numberOfTouchesRequired = 3;
        panicTap.numberOfTapsRequired = 2;
        [self addGestureRecognizer:panicTap];
        
        UILongPressGestureRecognizer *panicLong = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(panicHide)];
        panicLong.numberOfTouchesRequired = 2;
        panicLong.minimumPressDuration = 0.8;
        [self addGestureRecognizer:panicLong];
#endif

#if ENABLE_MOD_MENU
        // 4-finger tap for mod menu (Wizard-like menu but stealth)
        UITapGestureRecognizer *menuTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showModMenu)];
        menuTap.numberOfTouchesRequired = 4;
        menuTap.numberOfTapsRequired = 1;
        [self addGestureRecognizer:menuTap];
        
        // Also 2-finger triple tap
        UITapGestureRecognizer *menuTap2 = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showModMenu)];
        menuTap2.numberOfTouchesRequired = 2;
        menuTap2.numberOfTapsRequired = 3;
        [self addGestureRecognizer:menuTap2];
#endif

#if HIDE_ON_SCREEN_CAPTURE
        [[StealthManager shared] setupScreenCaptureObserver:self selector:@selector(screenCaptureChanged)];
#endif
        
#if HIDE_ON_BACKGROUND
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
#endif
    }
    return self;
}

- (void)handleLongPress:(UILongPressGestureRecognizer*)gr {
    if (gr.state == UIGestureRecognizerStateBegan) {
        [UIView animateWithDuration:0.2 animations:^{
            self.toggleButton.alpha = 0.9;
            self.toggleButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
            [self.toggleButton setTitle:@"•" forState:UIControlStateNormal];
        }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!self.isPanicHidden) {
                [UIView animateWithDuration:0.3 animations:^{
                    self.toggleButton.alpha = 0.3;
                    [self.toggleButton setTitle:@"" forState:UIControlStateNormal];
                    self.toggleButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15];
                }];
            }
        });
    }
}

- (void)showModMenu {
#if ENABLE_MOD_MENU
    if (self.isPanicHidden) return;
    if (IsScreenCaptured()) return;
    
    ModMenu *menu = [ModMenu sharedMenu];
    if ([menu isVisible]) {
        [menu hide];
    } else {
        // Add menu to our window
        if (menu.superview != self) {
            [self addSubview:menu];
            menu.frame = self.bounds;
        }
        [menu show];
    }
#endif
}

- (void)screenCaptureChanged {
    if (@available(iOS 11.0, *)) {
        BOOL isCaptured = [[UIScreen mainScreen] isCaptured];
        if (isCaptured) {
            [self hide];
            [[ModMenu sharedMenu] hide];
        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (self.helperEnabled && !self.isPanicHidden) {
                    [self show];
                }
            });
        }
    }
}

- (void)appDidEnterBackground {
#if HIDE_ON_BACKGROUND
    [self hide];
    [[ModMenu sharedMenu] hide];
#endif
}

- (void)appDidBecomeActive {
    if (self.helperEnabled && !self.isPanicHidden) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self show];
        });
    }
}

- (void)toggle {
    self.helperEnabled = !self.helperEnabled;
    if (!self.helperEnabled) {
        [self clear];
        self.toggleButton.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.3];
    } else {
        self.toggleButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15];
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{
            self.toggleButton.alpha = 0.3;
        }];
    });
}

- (void)show {
    if (self.isPanicHidden) return;
    if (IsScreenCaptured()) return;
    self.hidden = NO;
    self.windowLevel = UIWindowLevelStatusBar + 1;
}

- (void)hide {
    self.hidden = YES;
}

- (void)panicHide {
    self.isPanicHidden = YES;
    self.helperEnabled = NO;
    [self clear];
    [self hide];
    [[ModMenu sharedMenu] hide];
    
    UITapGestureRecognizer *restore = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(restoreFromPanic)];
    restore.numberOfTouchesRequired = 4;
    restore.numberOfTapsRequired = 2;
    [self addGestureRecognizer:restore];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.hidden = YES;
    });
}

- (void)restoreFromPanic {
    self.isPanicHidden = NO;
    self.helperEnabled = YES;
    [self show];
}

- (void)clear {
    self.cueLineLayer.path = nil;
    self.targetLineLayer.path = nil;
    self.ghostLayer.path = nil;
    self.bankLineLayer.path = nil;
    self.cueLeaveLayer.path = nil;
    self.scratchLayer.path = nil;
    self.comboLayer.path = nil;
    self.cushionLayer.path = nil;
    self.infoLabel.hidden = YES;
}

- (void)updateTableBounds:(CGRect)bounds {
    self.tableBounds = bounds;
}

// ==================== CORE DRAWING - BALL-BY-BALL MODE (SAFE) ====================

- (void)drawPredictionFromCue:(CGPoint)cue ghost:(CGPoint)ghost target:(CGPoint)target pocket:(CGPoint)pocket {
    if (!self.helperEnabled) return;
    if (self.isPanicHidden) return;
    if (self.hidden) return;
    if (IsScreenCaptured()) return;
    
#if ENABLE_HUMANIZATION
    ghost = HumanizePoint(ghost, HUMAN_JITTER_PIXELS);
#endif
    
    ModMenu *menu = [ModMenu sharedMenu];
    CGFloat thickness = menu.lineThickness > 0 ? menu.lineThickness : DEFAULT_LINE_THICKNESS;
    self.cueLineLayer.lineWidth = thickness;
    self.targetLineLayer.lineWidth = thickness;
    
    UIBezierPath *cuePath = [UIBezierPath bezierPath];
    [cuePath moveToPoint:cue];
    [cuePath addLineToPoint:ghost];
    self.cueLineLayer.path = cuePath.CGPath;
    
    CGFloat radius = DEFAULT_GHOST_RADIUS + RandomFloat(-0.5, 0.5);
    UIBezierPath *ghostPath = [UIBezierPath bezierPathWithArcCenter:ghost radius:radius startAngle:0 endAngle:2*M_PI clockwise:YES];
    self.ghostLayer.path = ghostPath.CGPath;
    
    UIBezierPath *targetPath = [UIBezierPath bezierPath];
    [targetPath moveToPoint:target];
    [targetPath addLineToPoint:pocket];
    self.targetLineLayer.path = targetPath.CGPath;
    
    // Long guidelines if enabled (Wizard feature)
    if (menu.longGuidelinesEnabled) {
        // Extend cue line backwards
        CGPoint cueDir = CGPointMake(ghost.x - cue.x, ghost.y - cue.y);
        CGFloat len = hypot(cueDir.x, cueDir.y);
        if (len != 0) { cueDir.x /= len; cueDir.y /= len; }
        CGPoint extendedStart = CGPointMake(cue.x - cueDir.x * 100, cue.y - cueDir.y * 100);
        UIBezierPath *extPath = [UIBezierPath bezierPath];
        [extPath moveToPoint:extendedStart];
        [extPath addLineToPoint:cue];
        // Draw as separate layer or same? Use cue layer with extended path
        UIBezierPath *fullCuePath = [UIBezierPath bezierPath];
        [fullCuePath moveToPoint:extendedStart];
        [fullCuePath addLineToPoint:ghost];
        self.cueLineLayer.path = fullCuePath.CGPath;
    }
}

- (void)drawSingleBallShot:(NSDictionary*)shotData {
    // Ball-by-ball mode - safest, only one ball
    if (!shotData) return;
    CGPoint target = [shotData[@"target"] CGPointValue];
    CGPoint pocket = [shotData[@"pocket"] CGPointValue];
    NSDictionary *shot = shotData[@"shot"];
    CGPoint ghost = [shot[@"ghost"] CGPointValue];
    CGPoint cue = CGPointZero;
    
    // Need cue - try to get from shot data or use last known
    // For now we use target as reference, cue should be passed separately
    // This method is called with full context in Tweak.x
    
    // If shotData has cue, use it
    if (shotData[@"cue"]) {
        cue = [shotData[@"cue"] CGPointValue];
    } else {
        // Fallback - will be set by caller
        return;
    }
    
    [self drawPredictionFromCue:cue ghost:ghost target:target pocket:pocket];
    
    // Show info HUD if enabled
    ModMenu *menu = [ModMenu sharedMenu];
    if (menu.infoHUDEnabled) {
        CGFloat angle = [shot[@"angle"] floatValue];
        self.infoLabel.text = [NSString stringWithFormat:@"Ball-by-Ball: %.1f°\nTarget: (%.0f,%.0f)", angle, target.x, target.y];
        self.infoLabel.hidden = NO;
    }
}

// ==================== WIZARD FEATURES ====================

- (void)drawBestShot:(NSDictionary*)bestShot {
    if (!bestShot) return;
    if (![[ModMenu sharedMenu] bestShotEnabled]) return;
    
    CGPoint target = [bestShot[@"target"] CGPointValue];
    CGPoint pocket = [bestShot[@"pocket"] CGPointValue];
    NSDictionary *shot = bestShot[@"shot"];
    CGPoint ghost = [shot[@"ghost"] CGPointValue];
    CGPoint cue = CGPointZero;
    
    if (bestShot[@"cue"]) {
        cue = [bestShot[@"cue"] CGPointValue];
    } else {
        // Try to get cue from container - fallback
        return;
    }
    
    // Draw with special styling for best shot - thicker, with glow
    [self drawPredictionFromCue:cue ghost:ghost target:target pocket:pocket];
    
    // Add ring around target and pocket (Wizard style)
    UIBezierPath *targetRing = [UIBezierPath bezierPathWithArcCenter:target radius:18 startAngle:0 endAngle:2*M_PI clockwise:YES];
    CAShapeLayer *ringLayer = [CAShapeLayer layer];
    ringLayer.path = targetRing.CGPath;
    ringLayer.strokeColor = [UIColor greenColor].CGColor;
    ringLayer.lineWidth = 2;
    ringLayer.fillColor = nil;
    [self.containerView.layer addSublayer:ringLayer];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [ringLayer removeFromSuperlayer];
    });
    
    if ([[ModMenu sharedMenu] infoHUDEnabled]) {
        CGFloat angle = [shot[@"angle"] floatValue];
        CGFloat score = [bestShot[@"score"] floatValue];
        self.infoLabel.text = [NSString stringWithFormat:@"Best Shot: %.1f° Score:%.1f\nBall-by-Ball OFF - Auto", angle, score];
        self.infoLabel.hidden = NO;
    }
}

- (void)drawBankShot:(NSDictionary*)bankShot {
    if (!bankShot) return;
    if (![[ModMenu sharedMenu] bankShotsEnabled]) return;
    
    CGPoint target = [bankShot[@"target"] CGPointValue];
    CGPoint pocket = [bankShot[@"pocket"] CGPointValue];
    CGPoint bankPoint = [bankShot[@"bankPoint"] CGPointValue];
    NSDictionary *shot = bankShot[@"shot"];
    CGPoint ghost = [shot[@"ghost"] CGPointValue];
    
    if (!bankShot[@"cue"]) return;
    CGPoint cue = [bankShot[@"cue"] CGPointValue];
    
    // Cue -> ghost
    [self drawPredictionFromCue:cue ghost:ghost target:target pocket:bankPoint];
    
    // Bank point -> pocket (cyan dashed)
    UIBezierPath *bankPath = [UIBezierPath bezierPath];
    [bankPath moveToPoint:bankPoint];
    [bankPath addLineToPoint:pocket];
    self.bankLineLayer.path = bankPath.CGPath;
    
    // Draw bank point circle
    UIBezierPath *bankCircle = [UIBezierPath bezierPathWithArcCenter:bankPoint radius:8 startAngle:0 endAngle:2*M_PI clockwise:YES];
    CAShapeLayer *circleLayer = [CAShapeLayer layer];
    circleLayer.path = bankCircle.CGPath;
    circleLayer.strokeColor = [UIColor cyanColor].CGColor;
    circleLayer.fillColor = [[UIColor cyanColor] colorWithAlphaComponent:0.3].CGColor;
    circleLayer.lineWidth = 1.5;
    [self.containerView.layer addSublayer:circleLayer];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [circleLayer removeFromSuperlayer];
    });
}

- (void)drawCueLeave:(CGPoint)cueLeave isScratch:(BOOL)isScratch {
    if (![[ModMenu sharedMenu] cueLeaveEnabled]) return;
    
    // Draw cue leave point
    UIBezierPath *leavePath = [UIBezierPath bezierPathWithArcCenter:cueLeave radius:10 startAngle:0 endAngle:2*M_PI clockwise:YES];
    self.cueLeaveLayer.path = leavePath.CGPath;
    
    // If scratch, show red warning (Wizard Scratch Warning)
    if (isScratch && [[ModMenu sharedMenu] scratchWarningEnabled]) {
        UIBezierPath *scratchPath = [UIBezierPath bezierPathWithArcCenter:cueLeave radius:16 startAngle:0 endAngle:2*M_PI clockwise:YES];
        self.scratchLayer.path = scratchPath.CGPath;
        self.scratchLayer.fillColor = [[UIColor redColor] colorWithAlphaComponent:0.3].CGColor;
        self.scratchLayer.strokeColor = [UIColor redColor].CGColor;
    } else {
        self.scratchLayer.path = nil;
    }
}

- (void)drawComboChain:(NSArray*)chain {
    // Combo chain - 3 balls in one shot - RISKY, only if enabled
    if (![[ModMenu sharedMenu] comboChainEnabled]) return;
    if (!chain || chain.count == 0) return;
    
    // Draw chain - this is more detectable, so we show warning
    // For safety, only draw first chain
    NSDictionary *firstChain = chain.firstObject;
    NSArray *balls = firstChain[@"balls"];
    if (balls.count < 2) return;
    
    // Draw lines connecting chain
    UIBezierPath *comboPath = [UIBezierPath bezierPath];
    for (NSInteger i = 0; i < balls.count - 1; i++) {
        CGPoint b1 = [balls[i] CGPointValue];
        CGPoint b2 = [balls[i+1] CGPointValue];
        if (i == 0) [comboPath moveToPoint:b1];
        [comboPath addLineToPoint:b2];
    }
    // Last ball to pocket
    CGPoint pocket = [firstChain[@"pocket"] CGPointValue];
    CGPoint lastBall = [balls.lastObject CGPointValue];
    [comboPath addLineToPoint:pocket];
    
    self.comboLayer.path = comboPath.CGPath;
    
    // Number the balls (Wizard style)
    for (NSInteger i = 0; i < balls.count; i++) {
        CGPoint ball = [balls[i] CGPointValue];
        UILabel *numLabel = [[UILabel alloc] initWithFrame:CGRectMake(ball.x - 10, ball.y - 25, 20, 20)];
        numLabel.text = [NSString stringWithFormat:@"%ld", (long)i+1];
        numLabel.textColor = [UIColor whiteColor];
        numLabel.backgroundColor = [UIColor orangeColor];
        numLabel.font = [UIFont boldSystemFontOfSize:12];
        numLabel.textAlignment = NSTextAlignmentCenter;
        numLabel.layer.cornerRadius = 10;
        numLabel.layer.masksToBounds = YES;
        [self addSubview:numLabel];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [numLabel removeFromSuperview];
        });
    }
}

- (void)drawCushionPath:(NSArray<NSValue*>*)path {
    if (!path || path.count < 2) return;
    
    UIBezierPath *cushionPath = [UIBezierPath bezierPath];
    for (NSInteger i = 0; i < path.count; i++) {
        CGPoint p = [path[i] CGPointValue];
        if (i == 0) [cushionPath moveToPoint:p];
        else [cushionPath addLineToPoint:p];
    }
    self.cushionLayer.path = cushionPath.CGPath;
}

@end
