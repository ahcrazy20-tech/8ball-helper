#import "ModMenu.h"
#import "Stealth.h"

@interface ModMenu ()
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, assign) BOOL visible;
@end

@implementation ModMenu

+ (instancetype)sharedMenu {
    static ModMenu *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initWithFrame:[UIScreen mainScreen].bounds];
    });
    return instance;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        self.hidden = YES;
        self.visible = NO;
        self.userInteractionEnabled = YES;
        [self loadSettings];
        
        CGFloat width = MIN(frame.size.width - 40, 340);
        CGFloat height = MIN(frame.size.height - 100, 600);
        self.contentView = [[UIView alloc] initWithFrame:CGRectMake((frame.size.width - width)/2, (frame.size.height - height)/2, width, height)];
        self.contentView.backgroundColor = [[UIColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:0.95] colorWithAlphaComponent:0.95];
        self.contentView.layer.cornerRadius = 12;
        self.contentView.layer.masksToBounds = YES;
        self.contentView.userInteractionEnabled = YES;
        
        self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
        self.scrollView.userInteractionEnabled = YES;
        self.scrollView.showsVerticalScrollIndicator = YES;
        [self.contentView addSubview:self.scrollView];
        [self addSubview:self.contentView];
        [self setupUI];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hide)];
        tap.cancelsTouchesInView = NO;
        [self addGestureRecognizer:tap];
        
        UITapGestureRecognizer *panic = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(panicHide)];
        panic.numberOfTouchesRequired = 3;
        panic.numberOfTapsRequired = 2;
        [self addGestureRecognizer:panic];
    }
    return self;
}

- (void)setupUI {
    CGFloat y = 10;
    CGFloat padding = 10;
    CGFloat width = self.contentView.frame.size.width - 20;
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(padding, y, width, 25)];
    title.text = @"🎱 Graphics Settings - Auto Power";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:15];
    title.textAlignment = NSTextAlignmentCenter;
    [self.scrollView addSubview:title];
    y += 30;
    
    UILabel *safety = [[UILabel alloc] initWithFrame:CGRectMake(padding, y, width, 40)];
    safety.text = @"🛡️ Safety: Ball-by-Ball ON = safest | Auto Shot OFF by default\nPower 75% = human-like, NOT 100% bot";
    safety.textColor = [UIColor colorWithRed:0.3 green:1.0 blue:0.3 alpha:1.0];
    safety.font = [UIFont systemFontOfSize:10];
    safety.numberOfLines = 2;
    safety.textAlignment = NSTextAlignmentCenter;
    safety.backgroundColor = [[UIColor greenColor] colorWithAlphaComponent:0.1];
    safety.layer.cornerRadius = 6;
    safety.layer.masksToBounds = YES;
    [self.scrollView addSubview:safety];
    y += 45;
    
    y = [self addToggle:@"🎯 Ball-by-Ball Mode (SAFE)" desc:@"ON = you select ball & pocket (safe)\nOFF = auto finds best" value:self.ballByBallMode tag:100 atY:y width:width];
    y = [self addToggle:@"⭐ Best Shot Solver" desc:@"Auto finds easiest shot (OFF for safety)" value:self.bestShotEnabled tag:101 atY:y width:width];
    y = [self addToggle:@"🔄 Bank Shots (1-cushion)" desc:@"Cushion-first shots (more obvious)" value:self.bankShotsEnabled tag:102 atY:y width:width];
    y = [self addToggle:@"⚪ Cue Leave Prediction" desc:@"Show where cue ball stops" value:self.cueLeaveEnabled tag:103 atY:y width:width];
    y = [self addToggle:@"🚩 Scratch Warning (SAFE)" desc:@"Red flag if cue will scratch" value:self.scratchWarningEnabled tag:104 atY:y width:width];
    y = [self addToggle:@"🔗 Combo Chain 3-Ball (RISKY)" desc:@"Show 3 balls chain - OFF safest" value:self.comboChainEnabled tag:105 atY:y width:width];
    y = [self addToggle:@"📊 Info HUD" desc:@"Show ball numbers, stats" value:self.infoHUDEnabled tag:106 atY:y width:width];
    y = [self addToggle:@"📏 Long Guidelines" desc:@"Extended lines beyond ghost" value:self.longGuidelinesEnabled tag:107 atY:y width:width];
    
    y += 5;
    UILabel *powerHeader = [[UILabel alloc] initWithFrame:CGRectMake(padding, y, width, 20)];
    powerHeader.text = @"⚡ Auto Power Suggestion (Safer Auto Shot)";
    powerHeader.textColor = [UIColor colorWithRed:1.0 green:0.8 blue:0.2 alpha:1.0];
    powerHeader.font = [UIFont boldSystemFontOfSize:12];
    powerHeader.textAlignment = NSTextAlignmentCenter;
    [self.scrollView addSubview:powerHeader];
    y += 25;
    
    y = [self addToggle:@"💡 Auto Power Suggestion (SAFE)" desc:@"Show suggested power 1-14 based on distance" value:self.autoPowerEnabled tag:108 atY:y width:width];
    y = [self addToggle:@"🎚️ Auto Power Adjust (RISKY)" desc:@"Auto-adjust power slider to suggested (with jitter)" value:self.autoPowerAdjustEnabled tag:109 atY:y width:width];
    y = [self addToggle:@"🤖 Auto Shot Assist (VERY RISKY)" desc:@"Auto shot with suggested power - OFF by default\nUses humanized accuracy, NOT 100% bot" value:self.autoShotEnabled tag:110 atY:y width:width];
    
    y += 10;
    y = [self addSlider:@"Line Thickness" value:self.lineThickness min:1.0 max:5.0 tag:200 atY:y width:width];
    y = [self addSlider:@"Humanization Jitter" value:self.humanizationJitter min:0.0 max:3.0 tag:201 atY:y width:width];
    y = [self addSlider:@"Max Angle (safety)" value:self.maxAngle min:30 max:90 tag:202 atY:y width:width];
    y = [self addSlider:@"Power Accuracy % (SAFE 75%)" value:self.powerAccuracy min:50 max:85 tag:203 atY:y width:width];
    y = [self addSlider:@"Suggested Power 1-14" value:self.suggestedPower min:1 max:14 tag:204 atY:y width:width];
    
    y += 10;
    UIButton *calibrateBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    calibrateBtn.frame = CGRectMake(padding, y, width, 40);
    calibrateBtn.backgroundColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.9 alpha:1.0];
    [calibrateBtn setTitle:@"📐 Calibrate Table (Newest 56.29.x)" forState:UIControlStateNormal];
    [calibrateBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    calibrateBtn.layer.cornerRadius = 8;
    calibrateBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [calibrateBtn addTarget:self action:@selector(calibrateTable) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:calibrateBtn];
    y += 50;
    
    UIButton *resetBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    resetBtn.frame = CGRectMake(padding, y, width/2 - 5, 35);
    resetBtn.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.3];
    [resetBtn setTitle:@"Reset to Safe" forState:UIControlStateNormal];
    [resetBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    resetBtn.layer.cornerRadius = 6;
    resetBtn.titleLabel.font = [UIFont systemFontOfSize:12];
    [resetBtn addTarget:self action:@selector(resetToSafe) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:resetBtn];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(padding + width/2 + 5, y, width/2 - 5, 35);
    closeBtn.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.6];
    [closeBtn setTitle:@"Close" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.layer.cornerRadius = 6;
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [closeBtn addTarget:self action:@selector(hide) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:closeBtn];
    y += 50;
    
    UILabel *version = [[UILabel alloc] initWithFrame:CGRectMake(padding, y, width, 35)];
    version.text = [NSString stringWithFormat:@"v1.4.0 Stealth | Auto Power Humanized 75%% (NOT 100%%)\nSupports 8BP 56.29.x | Ball-by-Ball Safe"];
    version.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
    version.font = [UIFont systemFontOfSize:9];
    version.numberOfLines = 2;
    version.textAlignment = NSTextAlignmentCenter;
    [self.scrollView addSubview:version];
    y += 45;
    
    self.scrollView.contentSize = CGSizeMake(width, y);
}

- (CGFloat)addToggle:(NSString*)title desc:(NSString*)desc value:(BOOL)value tag:(NSInteger)tag atY:(CGFloat)y width:(CGFloat)width {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(10, y, width, 60)];
    container.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.08];
    container.layer.cornerRadius = 8;
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, width - 70, 20)];
    titleLabel.text = title;
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont systemFontOfSize:11];
    [container addSubview:titleLabel];
    UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 25, width - 70, 30)];
    descLabel.text = desc;
    descLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    descLabel.font = [UIFont systemFontOfSize:9];
    descLabel.numberOfLines = 2;
    [container addSubview:descLabel];
    UISwitch *sw = [[UISwitch alloc] initWithFrame:CGRectMake(width - 55, 15, 50, 30)];
    sw.on = value;
    sw.tag = tag;
    sw.onTintColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.2 alpha:1.0];
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:sw];
    if ([title containsString:@"RISKY"] || [title containsString:@"VERY RISKY"] || [title containsString:@"Combo Chain"] || [title containsString:@"Auto Shot"]) {
        container.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.15];
        if (value) {
            container.layer.borderColor = [UIColor redColor].CGColor;
            container.layer.borderWidth = 1;
        }
    }
    if ([title containsString:@"SAFE"]) {
        container.backgroundColor = [[UIColor greenColor] colorWithAlphaComponent:0.1];
    }
    [self.scrollView addSubview:container];
    return y + 65;
}

- (CGFloat)addSlider:(NSString*)title value:(float)value min:(float)min max:(float)max tag:(NSInteger)tag atY:(CGFloat)y width:(CGFloat)width {
    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(10, y, width, 50)];
    container.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.05];
    container.layer.cornerRadius = 8;
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 5, 200, 20)];
    titleLabel.text = [NSString stringWithFormat:@"%@: %.1f", title, value];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont systemFontOfSize:10];
    titleLabel.tag = tag + 1000;
    [container addSubview:titleLabel];
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(10, 25, width - 20, 20)];
    slider.minimumValue = min;
    slider.maximumValue = max;
    slider.value = value;
    slider.tag = tag;
    slider.minimumTrackTintColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:1.0];
    [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [container addSubview:slider];
    [self.scrollView addSubview:container];
    return y + 55;
}

- (void)switchChanged:(UISwitch*)sw {
    switch (sw.tag) {
        case 100: self.ballByBallMode = sw.on; break;
        case 101: self.bestShotEnabled = sw.on; break;
        case 102: self.bankShotsEnabled = sw.on; break;
        case 103: self.cueLeaveEnabled = sw.on; break;
        case 104: self.scratchWarningEnabled = sw.on; break;
        case 105: self.comboChainEnabled = sw.on; break;
        case 106: self.infoHUDEnabled = sw.on; break;
        case 107: self.longGuidelinesEnabled = sw.on; break;
        case 108: self.autoPowerEnabled = sw.on; break;
        case 109: self.autoPowerAdjustEnabled = sw.on; break;
        case 110: self.autoShotEnabled = sw.on; break;
    }
    [self saveSettings];
    
    if ((sw.tag == 105 || sw.tag == 110) && sw.on) {
        NSString *msg = sw.tag == 105 ? @"Combo Chain (3 balls in one shot) is more detectable. Server can flag multi-ball patterns." : @"Auto Shot Assist automatically shoots with suggested power. This is most risky - server detects auto-play timing and 100% accuracy is bot flag. Our version uses 75% humanized accuracy, NOT 100%, but still risky. Use only in Play With Friends.";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚠️ Safety Warning" message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            sw.on = NO;
            if (sw.tag == 105) self.comboChainEnabled = NO;
            if (sw.tag == 110) self.autoShotEnabled = NO;
            [self saveSettings];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Enable (Risky)" style:UIAlertActionStyleDestructive handler:nil]];
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        UIViewController *vc = keyWindow.rootViewController;
        while (vc.presentedViewController) vc = vc.presentedViewController;
        [vc presentViewController:alert animated:YES completion:nil];
    }
    if (sw.tag == 109 && sw.on) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚠️ Auto Power Adjust" message:@"Auto-adjust power slider to suggested power with humanized jitter (NOT 100% accurate). More detectable than manual power. Continue?" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            sw.on = NO;
            self.autoPowerAdjustEnabled = NO;
            [self saveSettings];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Enable" style:UIAlertActionStyleDefault handler:nil]];
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        UIViewController *vc = keyWindow.rootViewController;
        while (vc.presentedViewController) vc = vc.presentedViewController;
        [vc presentViewController:alert animated:YES completion:nil];
    }
}

- (void)sliderChanged:(UISlider*)slider {
    UILabel *label = (UILabel*)[self.scrollView viewWithTag:slider.tag + 1000];
    switch (slider.tag) {
        case 200: self.lineThickness = slider.value; if (label) label.text = [NSString stringWithFormat:@"Line Thickness: %.1f", slider.value]; break;
        case 201: self.humanizationJitter = slider.value; if (label) label.text = [NSString stringWithFormat:@"Humanization Jitter: %.1f", slider.value]; break;
        case 202: self.maxAngle = slider.value; if (label) label.text = [NSString stringWithFormat:@"Max Angle: %.0f°", slider.value]; break;
        case 203: self.powerAccuracy = slider.value; if (label) label.text = [NSString stringWithFormat:@"Power Accuracy %% (SAFE 75%%): %.0f%%", slider.value]; break;
        case 204: self.suggestedPower = slider.value; if (label) label.text = [NSString stringWithFormat:@"Suggested Power 1-14: %.0f", slider.value]; break;
    }
    [self saveSettings];
}

- (void)calibrateTable {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"📐 Table Calibration" message:@"For newest 8 Ball Pool 56.29.x, auto-detection works for most devices. If lines misaligned, adjust in Config.h." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Auto-Calibrate" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.tableBoundsOffset = CGRectZero;
        [self saveSettings];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *vc = keyWindow.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    [vc presentViewController:alert animated:YES completion:nil];
}

- (void)resetToSafe {
    self.ballByBallMode = YES;
    self.bestShotEnabled = NO;
    self.bankShotsEnabled = NO;
    self.cueLeaveEnabled = NO;
    self.scratchWarningEnabled = YES;
    self.comboChainEnabled = NO;
    self.infoHUDEnabled = NO;
    self.longGuidelinesEnabled = YES;
    self.autoPowerEnabled = YES;
    self.autoPowerAdjustEnabled = NO;
    self.autoShotEnabled = NO;
    self.powerAccuracy = DEFAULT_POWER_ACCURACY;
    self.suggestedPower = DEFAULT_SUGGESTED_POWER;
    self.lineThickness = DEFAULT_LINE_THICKNESS;
    self.humanizationJitter = HUMAN_JITTER_PIXELS;
    self.maxAngle = SAFETY_MAX_ANGLE;
    [self saveSettings];
    [self hide];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅ Safe Mode" message:@"Reset to safest:\n• Ball-by-Ball ON\n• Best Shot OFF\n• Combo OFF\n• Auto Power Suggestion ON (safe)\n• Auto Power Adjust OFF\n• Auto Shot OFF\n• Accuracy 75% (human, NOT 100%)" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        UIViewController *vc = keyWindow.rootViewController;
        while (vc.presentedViewController) vc = vc.presentedViewController;
        [vc presentViewController:alert animated:YES completion:nil];
    });
}

- (void)show { if (IsScreenCaptured()) return; self.hidden = NO; self.visible = YES; self.alpha = 0; [UIView animateWithDuration:0.2 animations:^{ self.alpha = 1; }]; }
- (void)hide { [UIView animateWithDuration:0.2 animations:^{ self.alpha = 0; } completion:^(BOOL finished) { self.hidden = YES; self.visible = NO; }]; }
- (void)toggle { if (self.visible) [self hide]; else [self show]; }
- (BOOL)isVisible { return self.visible && !self.hidden; }
- (void)panicHide { [self hide]; }

- (void)saveSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:self.ballByBallMode forKey:@"stealth_ballByBall"];
    [defaults setBool:self.bestShotEnabled forKey:@"stealth_bestShot"];
    [defaults setBool:self.bankShotsEnabled forKey:@"stealth_bankShots"];
    [defaults setBool:self.cueLeaveEnabled forKey:@"stealth_cueLeave"];
    [defaults setBool:self.scratchWarningEnabled forKey:@"stealth_scratch"];
    [defaults setBool:self.comboChainEnabled forKey:@"stealth_combo"];
    [defaults setBool:self.infoHUDEnabled forKey:@"stealth_hud"];
    [defaults setBool:self.longGuidelinesEnabled forKey:@"stealth_long"];
    [defaults setBool:self.autoPowerEnabled forKey:@"stealth_autoPower"];
    [defaults setBool:self.autoPowerAdjustEnabled forKey:@"stealth_autoAdjust"];
    [defaults setBool:self.autoShotEnabled forKey:@"stealth_autoShot"];
    [defaults setFloat:self.powerAccuracy forKey:@"stealth_accuracy"];
    [defaults setFloat:self.suggestedPower forKey:@"stealth_suggestedPower"];
    [defaults setFloat:self.lineThickness forKey:@"stealth_lineThick"];
    [defaults setFloat:self.humanizationJitter forKey:@"stealth_jitter"];
    [defaults setFloat:self.maxAngle forKey:@"stealth_maxAngle"];
    [defaults synchronize];
}

- (void)loadSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.ballByBallMode = [defaults objectForKey:@"stealth_ballByBall"] ? [defaults boolForKey:@"stealth_ballByBall"] : DEFAULT_BALL_BY_BALL_MODE;
    self.bestShotEnabled = [defaults objectForKey:@"stealth_bestShot"] ? [defaults boolForKey:@"stealth_bestShot"] : DEFAULT_BEST_SHOT_ENABLED;
    self.bankShotsEnabled = [defaults objectForKey:@"stealth_bankShots"] ? [defaults boolForKey:@"stealth_bankShots"] : DEFAULT_BANK_SHOTS_ENABLED;
    self.cueLeaveEnabled = [defaults objectForKey:@"stealth_cueLeave"] ? [defaults boolForKey:@"stealth_cueLeave"] : DEFAULT_CUE_LEAVE_ENABLED;
    self.scratchWarningEnabled = [defaults objectForKey:@"stealth_scratch"] ? [defaults boolForKey:@"stealth_scratch"] : DEFAULT_SCRATCH_WARNING_ENABLED;
    self.comboChainEnabled = [defaults objectForKey:@"stealth_combo"] ? [defaults boolForKey:@"stealth_combo"] : DEFAULT_COMBO_CHAIN_ENABLED;
    self.infoHUDEnabled = [defaults objectForKey:@"stealth_hud"] ? [defaults boolForKey:@"stealth_hud"] : DEFAULT_INFO_HUD_ENABLED;
    self.longGuidelinesEnabled = [defaults objectForKey:@"stealth_long"] ? [defaults boolForKey:@"stealth_long"] : YES;
    self.autoPowerEnabled = [defaults objectForKey:@"stealth_autoPower"] ? [defaults boolForKey:@"stealth_autoPower"] : DEFAULT_AUTO_POWER_ENABLED;
    self.autoPowerAdjustEnabled = [defaults objectForKey:@"stealth_autoAdjust"] ? [defaults boolForKey:@"stealth_autoAdjust"] : DEFAULT_AUTO_POWER_ADJUST_ENABLED;
    self.autoShotEnabled = [defaults objectForKey:@"stealth_autoShot"] ? [defaults boolForKey:@"stealth_autoShot"] : DEFAULT_AUTO_SHOT_ENABLED;
    self.powerAccuracy = [defaults objectForKey:@"stealth_accuracy"] ? [defaults floatForKey:@"stealth_accuracy"] : DEFAULT_POWER_ACCURACY;
    self.suggestedPower = [defaults objectForKey:@"stealth_suggestedPower"] ? [defaults floatForKey:@"stealth_suggestedPower"] : DEFAULT_SUGGESTED_POWER;
    self.lineThickness = [defaults objectForKey:@"stealth_lineThick"] ? [defaults floatForKey:@"stealth_lineThick"] : DEFAULT_LINE_THICKNESS;
    self.humanizationJitter = [defaults objectForKey:@"stealth_jitter"] ? [defaults floatForKey:@"stealth_jitter"] : HUMAN_JITTER_PIXELS;
    self.maxAngle = [defaults objectForKey:@"stealth_maxAngle"] ? [defaults floatForKey:@"stealth_maxAngle"] : SAFETY_MAX_ANGLE;
    self.tableBoundsOffset = CGRectZero;
}

@end
