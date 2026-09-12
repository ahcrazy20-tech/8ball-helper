#import <UIKit/UIKit.h>
#import "Config.h"

// Innocent name for stealth
#if USE_INNOCENT_CLASS_NAMES
#define ModMenu _UIFeedbackMenu
#endif

@interface ModMenu : UIView

+ (instancetype)sharedMenu;
- (void)show;
- (void)hide;
- (void)toggle;
- (BOOL)isVisible;

// Settings that can be toggled
@property (nonatomic, assign) BOOL ballByBallMode;          // Safety: ball by ball, not 3-ball combo
@property (nonatomic, assign) BOOL bestShotEnabled;
@property (nonatomic, assign) BOOL bankShotsEnabled;
@property (nonatomic, assign) BOOL cueLeaveEnabled;
@property (nonatomic, assign) BOOL scratchWarningEnabled;
@property (nonatomic, assign) BOOL comboChainEnabled;       // 3-ball chain - OFF by default for safety
@property (nonatomic, assign) BOOL infoHUDEnabled;
@property (nonatomic, assign) BOOL longGuidelinesEnabled;

@property (nonatomic, assign) float lineThickness;
@property (nonatomic, assign) float ballRadius;
@property (nonatomic, assign) float humanizationJitter;
@property (nonatomic, assign) float maxAngle;

// Table calibration
@property (nonatomic, assign) CGRect tableBoundsOffset; // manual offset for newest version support

- (void)saveSettings;
- (void)loadSettings;

@end

@interface _UIFeedbackMenu : ModMenu
@end
