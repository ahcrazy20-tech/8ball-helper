#import <UIKit/UIKit.h>
#import "Config.h"

#if USE_INNOCENT_CLASS_NAMES
#define ModMenu _UIFeedbackMenu
#endif

@interface ModMenu : UIView

+ (instancetype)sharedMenu;
- (void)show;
- (void)hide;
- (void)toggle;
- (BOOL)isVisible;

@property (nonatomic, assign) BOOL ballByBallMode;
@property (nonatomic, assign) BOOL bestShotEnabled;
@property (nonatomic, assign) BOOL bankShotsEnabled;
@property (nonatomic, assign) BOOL cueLeaveEnabled;
@property (nonatomic, assign) BOOL scratchWarningEnabled;
@property (nonatomic, assign) BOOL comboChainEnabled;
@property (nonatomic, assign) BOOL infoHUDEnabled;
@property (nonatomic, assign) BOOL longGuidelinesEnabled;

// Auto power suggestion (safer auto shot)
@property (nonatomic, assign) BOOL autoPowerEnabled;        // Show suggested power (safe, ON by default)
@property (nonatomic, assign) BOOL autoPowerAdjustEnabled;  // Auto-adjust power slider (OFF by default, risky)
@property (nonatomic, assign) BOOL autoShotEnabled;         // Auto shot assist (OFF by default, most risky)
@property (nonatomic, assign) float powerAccuracy;          // 50-85% (not 100%), human-like
@property (nonatomic, assign) float suggestedPower;         // 1-14

@property (nonatomic, assign) float lineThickness;
@property (nonatomic, assign) float ballRadius;
@property (nonatomic, assign) float humanizationJitter;
@property (nonatomic, assign) float maxAngle;

@property (nonatomic, assign) CGRect tableBoundsOffset;

- (void)saveSettings;
- (void)loadSettings;

@end

@interface _UIFeedbackMenu : ModMenu
@end
