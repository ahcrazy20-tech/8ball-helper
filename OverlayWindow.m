#import "OverlayWindow.h"
#import <QuartzCore/QuartzCore.h>

@interface OverlayWindow ()
@property (nonatomic, strong) CAShapeLayer *cueLineLayer;
@property (nonatomic, strong) CAShapeLayer *targetLineLayer;
@property (nonatomic, strong) CAShapeLayer *ghostLayer;
@property (nonatomic, strong) UIButton *toggleButton;
@end

@implementation OverlayWindow

+ (instancetype)shared {
    static OverlayWindow *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[OverlayWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    });
    return instance;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelStatusBar + 100; // on top of everything
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO; // let touches pass to game, except button
        self.hidden = YES;
        self.helperEnabled = YES;
        
        // Layers for lines
        self.cueLineLayer = [CAShapeLayer layer];
        self.cueLineLayer.strokeColor = [UIColor yellowColor].CGColor;
        self.cueLineLayer.lineWidth = 3.0;
        self.cueLineLayer.fillColor = nil;
        
        self.targetLineLayer = [CAShapeLayer layer];
        self.targetLineLayer.strokeColor = [UIColor greenColor].CGColor;
        self.targetLineLayer.lineWidth = 3.0;
        self.targetLineLayer.fillColor = nil;
        
        self.ghostLayer = [CAShapeLayer layer];
        self.ghostLayer.strokeColor = [UIColor yellowColor].CGColor;
        self.ghostLayer.lineWidth = 2.0;
        self.ghostLayer.fillColor = [UIColor clearColor].CGColor;
        
        UIView *container = [[UIView alloc] initWithFrame:frame];
        container.backgroundColor = [UIColor clearColor];
        container.userInteractionEnabled = NO;
        [container.layer addSublayer:self.cueLineLayer];
        [container.layer addSublayer:self.targetLineLayer];
        [container.layer addSublayer:self.ghostLayer];
        
        [self addSubview:container];
        
        // Toggle button - small, draggable
        self.toggleButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.toggleButton.frame = CGRectMake(20, 80, 90, 35);
        self.toggleButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
        [self.toggleButton setTitle:@"Helper ON" forState:UIControlStateNormal];
        [self.toggleButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.toggleButton.layer.cornerRadius = 8;
        self.toggleButton.userInteractionEnabled = YES;
        [self.toggleButton addTarget:self action:@selector(toggle) forControlEvents:UIControlEventTouchUpInside];
        
        // Make window interactive only for button area
        self.userInteractionEnabled = YES;
        
        UIView *buttonContainer = [[UIView alloc] initWithFrame:frame];
        buttonContainer.backgroundColor = [UIColor clearColor];
        [buttonContainer addSubview:self.toggleButton];
        [self addSubview:buttonContainer];
    }
    return self;
}

- (void)toggle {
    self.helperEnabled = !self.helperEnabled;
    [self.toggleButton setTitle:self.helperEnabled ? @"Helper ON" : @"Helper OFF" forState:UIControlStateNormal];
    if (!self.helperEnabled) [self clear];
}

- (void)show {
    self.hidden = NO;
    [self makeKeyAndVisible];
}

- (void)clear {
    self.cueLineLayer.path = nil;
    self.targetLineLayer.path = nil;
    self.ghostLayer.path = nil;
}

- (void)drawPredictionFromCue:(CGPoint)cue ghost:(CGPoint)ghost target:(CGPoint)target pocket:(CGPoint)pocket {
    if (!self.helperEnabled) return;
    
    // Cue -> Ghost (yellow)
    UIBezierPath *cuePath = [UIBezierPath bezierPath];
    [cuePath moveToPoint:cue];
    [cuePath addLineToPoint:ghost];
    self.cueLineLayer.path = cuePath.CGPath;
    
    // Ghost circle
    UIBezierPath *ghostPath = [UIBezierPath bezierPathWithArcCenter:ghost radius:12 startAngle:0 endAngle:2*M_PI clockwise:YES];
    self.ghostLayer.path = ghostPath.CGPath;
    
    // Target -> Pocket (green)
    UIBezierPath *targetPath = [UIBezierPath bezierPath];
    [targetPath moveToPoint:target];
    [targetPath addLineToPoint:pocket];
    self.targetLineLayer.path = targetPath.CGPath;
    
    // Add glow effect
    self.cueLineLayer.shadowColor = [UIColor yellowColor].CGColor;
    self.cueLineLayer.shadowOpacity = 0.8;
    self.cueLineLayer.shadowRadius = 3;
}

@end
