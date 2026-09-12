#import "OverlayWindow.h"
#import "Config.h"
#import "Stealth.h"
#import <QuartzCore/QuartzCore.h>

// Innocent-looking class for stealth
@interface OverlayWindow ()
@property (nonatomic, strong) CAShapeLayer *cueLineLayer;
@property (nonatomic, strong) CAShapeLayer *targetLineLayer;
@property (nonatomic, strong) CAShapeLayer *ghostLayer;
@property (nonatomic, strong) UIButton *toggleButton;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) CADisplayLink *displayLink;
@end

@implementation OverlayWindow

+ (instancetype)shared {
    static OverlayWindow *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Use main screen bounds but with stealth init
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
        // STEALTH: Use lower window level than before, still above game but less obvious
        // UIWindowLevelStatusBar + 1 instead of +100 (which is very suspicious)
        self.windowLevel = UIWindowLevelStatusBar + 1;
        self.backgroundColor = [UIColor clearColor];
        self.hidden = YES;
        self.helperEnabled = !DEFAULT_HIDDEN;
        self.isPanicHidden = NO;
        
        // Make window not appear in screenshots if possible
        // iOS 13+ has option to exclude from capture? We handle via notification
        
        // Container for lines - will be added to existing view hierarchy for more stealth
        self.containerView = [[UIView alloc] initWithFrame:frame];
        self.containerView.backgroundColor = [UIColor clearColor];
        self.containerView.userInteractionEnabled = NO;
        self.containerView.tag = 0xCAFE; // innocent tag
        
        // Cue line - yellow but with stealth alpha
        self.cueLineLayer = [CAShapeLayer layer];
        self.cueLineLayer.strokeColor = [[UIColor colorWithRed:1.0 green:0.92 blue:0.23 alpha:LINE_ALPHA] CGColor];
        self.cueLineLayer.lineWidth = 2.5; // slightly thinner, less obvious
        self.cueLineLayer.fillColor = nil;
        self.cueLineLayer.lineCap = kCALineCapRound;
        self.cueLineLayer.lineJoin = kCALineJoinRound;
#if GLOW_ENABLED
        self.cueLineLayer.shadowColor = [UIColor yellowColor].CGColor;
        self.cueLineLayer.shadowOpacity = 0.6;
        self.cueLineLayer.shadowRadius = 2;
#endif
#if USE_DASHED_LINES
        self.cueLineLayer.lineDashPattern = @[@6, @3];
#endif
        
        // Target line - green
        self.targetLineLayer = [CAShapeLayer layer];
        self.targetLineLayer.strokeColor = [[UIColor colorWithRed:0.2 green:0.9 blue:0.2 alpha:LINE_ALPHA] CGColor];
        self.targetLineLayer.lineWidth = 2.5;
        self.targetLineLayer.fillColor = nil;
        self.targetLineLayer.lineCap = kCALineCapRound;
#if USE_DASHED_LINES
        self.targetLineLayer.lineDashPattern = @[@6, @3];
#endif
        
        // Ghost ball circle
        self.ghostLayer = [CAShapeLayer layer];
        self.ghostLayer.strokeColor = [[UIColor colorWithRed:1.0 green:0.92 blue:0.23 alpha:0.9] CGColor];
        self.ghostLayer.lineWidth = 1.5;
        self.ghostLayer.fillColor = [[UIColor clearColor] CGColor];
        
        [self.containerView.layer addSublayer:self.cueLineLayer];
        [self.containerView.layer addSublayer:self.targetLineLayer];
        [self.containerView.layer addSublayer:self.ghostLayer];
        
        [self addSubview:self.containerView];
        
        // STEALTH TOGGLE BUTTON - much smaller, more hidden
        // Old: 90x35 big button saying "Helper ON" - very obvious on stream
        // New: 8x8 dot in corner, almost invisible, or completely hidden and use gesture
        self.toggleButton = [UIButton buttonWithType:UIButtonTypeCustom];
        // Tiny dot at top-left, near status bar, looks like dead pixel or system UI
        self.toggleButton.frame = CGRectMake(3, 35, 10, 10);
        self.toggleButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15];
        self.toggleButton.layer.cornerRadius = 5;
        self.toggleButton.alpha = 0.3; // almost invisible
        self.toggleButton.userInteractionEnabled = YES;
        [self.toggleButton addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside];
        
        // Long press to make more visible
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
        // Panic gesture: 3-finger double tap to instantly hide
        UITapGestureRecognizer *panicTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(panicHide)];
        panicTap.numberOfTouchesRequired = 3;
        panicTap.numberOfTapsRequired = 2;
        [self addGestureRecognizer:panicTap];
        
        // Alternative: 2-finger long press
        UILongPressGestureRecognizer *panicLong = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(panicHide)];
        panicLong.numberOfTouchesRequired = 2;
        panicLong.minimumPressDuration = 0.8;
        [self addGestureRecognizer:panicLong];
#endif

#if HIDE_ON_SCREEN_CAPTURE
        // Observe screen capture
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
        // Make button temporarily visible
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

- (void)screenCaptureChanged {
    if (@available(iOS 11.0, *)) {
        BOOL isCaptured = [[UIScreen mainScreen] isCaptured];
        if (isCaptured) {
            SafeLog(@"Screen captured, hiding");
            [self hide];
        } else {
            // Delay showing again
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
        // Visual feedback via dot color
        self.toggleButton.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.3];
    } else {
        self.toggleButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15];
    }
    // Auto-hide button again
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{
            self.toggleButton.alpha = 0.3;
        }];
    });
}

- (void)show {
    if (self.isPanicHidden) return;
    if (IsScreenCaptured()) {
        SafeLog(@"Not showing - screen captured");
        return;
    }
    self.hidden = NO;
    // Don't use makeKeyAndVisible - that's detectable and steals focus
    // Use setHidden:NO and make sure window is on top via windowLevel
    // Old code used makeKeyAndVisible which can break game input
    self.windowLevel = UIWindowLevelStatusBar + 1;
}

- (void)hide {
    self.hidden = YES;
}

- (void)panicHide {
    SafeLog(@"Panic hide triggered");
    self.isPanicHidden = YES;
    self.helperEnabled = NO;
    [self clear];
    [self hide];
    // Show alert? No, silent
    // To re-enable, user must triple-tap or restart? Let's allow re-enable via 4-finger tap
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
    SafeLog(@"Restored from panic");
}

- (void)clear {
    self.cueLineLayer.path = nil;
    self.targetLineLayer.path = nil;
    self.ghostLayer.path = nil;
}

- (void)drawPredictionFromCue:(CGPoint)cue ghost:(CGPoint)ghost target:(CGPoint)target pocket:(CGPoint)pocket {
    if (!self.helperEnabled) return;
    if (self.isPanicHidden) return;
    if (self.hidden) return;
    if (IsScreenCaptured()) return;
    
#if ENABLE_HUMANIZATION
    // Add tiny jitter to look human, not bot-perfect
    ghost = HumanizePoint(ghost, HUMAN_JITTER_PIXELS);
    // Don't humanize cue and target too much, only ghost
#endif
    
    // Cue -> Ghost (yellow)
    UIBezierPath *cuePath = [UIBezierPath bezierPath];
    [cuePath moveToPoint:cue];
    [cuePath addLineToPoint:ghost];
    self.cueLineLayer.path = cuePath.CGPath;
    
    // Ghost circle with slight randomness in radius
    CGFloat radius = 11.0 + RandomFloat(-0.5, 0.5);
    UIBezierPath *ghostPath = [UIBezierPath bezierPathWithArcCenter:ghost radius:radius startAngle:0 endAngle:2*M_PI clockwise:YES];
    self.ghostLayer.path = ghostPath.CGPath;
    
    // Target -> Pocket (green)
    UIBezierPath *targetPath = [UIBezierPath bezierPath];
    [targetPath moveToPoint:target];
    [targetPath addLineToPoint:pocket];
    self.targetLineLayer.path = targetPath.CGPath;
}

@end
