#import "BHTLiveRecorder.h"
#import "BHIManager.h"
#import "TikTokHeaders.h"
#import <ReplayKit/ReplayKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import "JGProgressHUD/JGProgressHUD.h"
#import <Photos/Photos.h>

// ============================================================================
// BHTSecureTextField: Kayıt esnasında Sayaç, Duraklat ve Durdur butonlarını
// ReplayKit video çıktısından tamamen gizlemek için kullanılır.
// canBecomeFirstResponder = NO sayesinde klavye ve autofill kesinlikle açılmaz.
// ============================================================================
@interface BHTSecureTextField : UITextField
@end

@implementation BHTSecureTextField

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.clipsToBounds = NO;
        self.secureTextEntry = YES;
        self.userInteractionEnabled = YES;
        self.autocorrectionType = UITextAutocorrectionTypeNo;
        self.spellCheckingType = UITextSpellCheckingTypeNo;
        if (@available(iOS 10.0, *)) {
            self.textContentType = @"";
        }
    }
    return self;
}

- (BOOL)canBecomeFirstResponder {
    return NO;
}

- (BOOL)becomeFirstResponder {
    return NO;
}

- (BOOL)canResignFirstResponder {
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    return NO;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self) {
        return nil;
    }
    return hit;
}

@end

// ============================================================================
// BHTLiveRecorder Implementation
// ============================================================================
@interface BHTLiveRecorder ()
@property (nonatomic, assign, readwrite) BOOL isRecording;
@property (nonatomic, assign, readwrite) BOOL isPaused;
@property (nonatomic, assign) BOOL isSessionStarted;

// Boşta duran normal kapsayıcı ve Kaydet butonu
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIButton *recordButton;

// Kayıt esnasında ReplayKit'ten gizlenen güvenli canvas içindeki elemanlar
@property (nonatomic, strong) BHTSecureTextField *secureField;
@property (nonatomic, strong) UIView *timerContainer;
@property (nonatomic, strong) UIView *timerDot;
@property (nonatomic, strong) UILabel *timerLabel;
@property (nonatomic, strong) UIButton *pauseButton;
@property (nonatomic, strong) UIButton *stopButton;

// Canlı Sayaç Yönetimi
@property (nonatomic, strong) NSTimer *recordingTimer;
@property (nonatomic, assign) NSInteger elapsedSeconds;

// Canlı Yayındaki Yorum ve Butonları Gizleme / Geri Getirme
@property (nonatomic, strong) NSHashTable<UIView *> *hiddenOverlays;

// Video & Ses Yazıcı
@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *videoInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *adaptor;
@property (nonatomic, strong) AVAssetWriterInput *audioInput;
@property (nonatomic, strong) NSURL *outputURL;

@property (nonatomic, assign) CMTime firstFramePTS;
@property (nonatomic, assign) CFTimeInterval pauseStartPTS;
@property (nonatomic, assign) CMTime totalPausedTime;
@property (nonatomic, assign) NSInteger videoWidth;
@property (nonatomic, assign) NSInteger videoHeight;
@property (nonatomic, strong) JGProgressHUD *hud;
@end

@implementation BHTLiveRecorder

+ (instancetype)shared {
    static BHTLiveRecorder *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BHTLiveRecorder alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isRecording = NO;
        _isPaused = NO;
        _isSessionStarted = NO;
        _firstFramePTS = kCMTimeZero;
        _totalPausedTime = kCMTimeZero;
        _elapsedSeconds = 0;
        _hiddenOverlays = [NSHashTable weakObjectsHashTable];
    }
    return self;
}

#pragma mark - Attachment & Sizing

- (void)attachToViewController:(UIViewController *)vc {
    if (!vc || !vc.view) return;
    if (![BHIManager liveRecordButton]) {
        [self.containerView removeFromSuperview];
        [self.secureField removeFromSuperview];
        self.currentLiveVC = nil;
        return;
    }

    if (self.currentLiveVC == vc && self.containerView.superview == vc.view) {
        return;
    }

    self.currentLiveVC = vc;
    [self setupUIInView:vc.view];

    CGFloat screenW = vc.view.bounds.size.width > 0 ? vc.view.bounds.size.width : [UIScreen mainScreen].bounds.size.width;
    CGFloat topInset = 47.0;
    if (@available(iOS 11.0, *)) {
        if (vc.view.safeAreaInsets.top > 0) {
            topInset = vc.view.safeAreaInsets.top;
        }
    }

    // Kompakt 56x26 pt buton (sola taşmayan tam oturan kapsül)
    CGFloat btnW = 56.0;
    CGFloat btnH = 26.0;
    CGFloat btnX = screenW - btnW - 12.0;
    CGFloat btnY = topInset + 75.0;

    self.containerView.frame = CGRectMake(btnX, btnY, btnW, btnH);
    self.recordButton.frame = CGRectMake(0, 0, btnW, btnH);

    if (self.containerView.superview != vc.view) {
        [vc.view addSubview:self.containerView];
    }
    [vc.view bringSubviewToFront:self.containerView];
}

- (void)detachFromViewController:(UIViewController *)vc {
    if (self.currentLiveVC == vc) {
        if (self.isRecording) {
            [self stopRecording];
        }
        [self stopTimer];
        [self restoreLiveOverlaysSafely];
        [self.containerView removeFromSuperview];
        [self.secureField removeFromSuperview];
        self.currentLiveVC = nil;
    }
}

- (void)updateButtonFrameForViewController:(UIViewController *)vc {
    if (!vc || !vc.view) return;
    if (self.currentLiveVC != vc) return;

    CGFloat screenW = vc.view.bounds.size.width;
    if (screenW <= 0) return;

    CGFloat topInset = 47.0;
    if (@available(iOS 11.0, *)) {
        if (vc.view.safeAreaInsets.top > 0) {
            topInset = vc.view.safeAreaInsets.top;
        }
    }

    CGFloat btnW = 56.0;
    CGFloat btnH = 26.0;
    CGFloat timerH = 20.0;
    CGFloat spacing = 4.0;
    CGFloat btnX = screenW - btnW - 12.0;
    CGFloat btnY = topInset + 75.0;

    if (self.isRecording && self.secureField) {
        CGFloat secureH = timerH + spacing + (btnH * 2.0) + spacing;
        CGRect targetFrame = CGRectMake(btnX, btnY, btnW, secureH);
        if (!CGRectEqualToRect(self.secureField.frame, targetFrame)) {
            self.secureField.frame = targetFrame;
            UIView *canvas = [self secureCanvasView];
            if (canvas) canvas.frame = self.secureField.bounds;
        }
    } else if (self.containerView) {
        CGRect targetFrame = CGRectMake(btnX, btnY, btnW, btnH);
        if (!CGRectEqualToRect(self.containerView.frame, targetFrame)) {
            self.containerView.frame = targetFrame;
            self.recordButton.frame = CGRectMake(0, 0, btnW, btnH);
        }
    }
}

#pragma mark - UI Setup & Styling

- (void)setupUIInView:(UIView *)parentView {
    if (!parentView) return;

    CGFloat btnW = 56.0;
    CGFloat btnH = 26.0;
    CGFloat timerH = 20.0;
    CGFloat spacing = 4.0;

    if (!self.containerView) {
        self.containerView = [[UIView alloc] initWithFrame:CGRectZero];
        self.containerView.tag = 8881;
        self.containerView.backgroundColor = [UIColor clearColor];
        self.containerView.clipsToBounds = NO;
        self.containerView.userInteractionEnabled = YES;

        // 1. Kaydet Butonu ("Kaydet" / "Record") - 56x26 pt kompakt kapsül
        self.recordButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.recordButton.tag = 8882;
        self.recordButton.layer.cornerRadius = 13.0;
        self.recordButton.layer.masksToBounds = YES;
        self.recordButton.layer.borderWidth = 0.5;
        self.recordButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
        if (@available(iOS 13.0, *)) {
            self.recordButton.layer.cornerCurve = kCACornerCurveContinuous;
        }

        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.frame = CGRectMake(0, 0, btnW, btnH);
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurView.userInteractionEnabled = NO;
        blurView.layer.cornerRadius = 13.0;
        blurView.layer.masksToBounds = YES;
        [self.recordButton insertSubview:blurView atIndex:0];

        self.recordButton.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.4];
        self.recordButton.titleLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium];
        [self.recordButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.recordButton setTitle:[BHIManager isTurkish] ? @"Kaydet" : @"Record" forState:UIControlStateNormal];

        [self.recordButton addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
        [self.recordButton addTarget:self action:@selector(buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        [self.recordButton addTarget:self action:@selector(startRecording) forControlEvents:UIControlEventTouchUpInside];
        [self.containerView addSubview:self.recordButton];
    }

    if (!self.timerContainer) {
        // 2. Canlı Sayaç Kapsülü (Timer: 56x20 pt)
        self.timerContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, btnW, timerH)];
        self.timerContainer.tag = 8885;
        self.timerContainer.layer.cornerRadius = 10.0;
        self.timerContainer.layer.masksToBounds = YES;
        self.timerContainer.layer.borderWidth = 0.5;
        self.timerContainer.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
        if (@available(iOS 13.0, *)) {
            self.timerContainer.layer.cornerCurve = kCACornerCurveContinuous;
        }
        self.timerContainer.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.45];

        UIBlurEffect *timerBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *timerBlurView = [[UIVisualEffectView alloc] initWithEffect:timerBlur];
        timerBlurView.frame = self.timerContainer.bounds;
        timerBlurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        timerBlurView.userInteractionEnabled = NO;
        timerBlurView.layer.cornerRadius = 10.0;
        timerBlurView.layer.masksToBounds = YES;
        [self.timerContainer insertSubview:timerBlurView atIndex:0];

        self.timerDot = [[UIView alloc] initWithFrame:CGRectMake(7.0, 7.5, 5.0, 5.0)];
        self.timerDot.backgroundColor = [UIColor colorWithRed:1.0 green:0.22 blue:0.22 alpha:1.0];
        self.timerDot.layer.cornerRadius = 2.5;
        self.timerDot.layer.masksToBounds = YES;
        [self.timerContainer addSubview:self.timerDot];

        self.timerLabel = [[UILabel alloc] initWithFrame:CGRectMake(15.0, 0, btnW - 17.0, timerH)];
        if (@available(iOS 13.0, *)) {
            self.timerLabel.font = [UIFont monospacedDigitSystemFontOfSize:10.5 weight:UIFontWeightBold];
        } else {
            self.timerLabel.font = [UIFont boldSystemFontOfSize:10.5];
        }
        self.timerLabel.textColor = [UIColor whiteColor];
        self.timerLabel.textAlignment = NSTextAlignmentLeft;
        self.timerLabel.text = @"00:00";
        [self.timerContainer addSubview:self.timerLabel];
    }

    if (!self.pauseButton) {
        // 3. Duraklat / Devam Et Butonu - 56x26 pt
        self.pauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.pauseButton.tag = 8883;
        self.pauseButton.layer.cornerRadius = 13.0;
        self.pauseButton.layer.masksToBounds = YES;
        self.pauseButton.layer.borderWidth = 0.5;
        self.pauseButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
        if (@available(iOS 13.0, *)) {
            self.pauseButton.layer.cornerCurve = kCACornerCurveContinuous;
        }

        UIBlurEffect *pauseBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *pauseBlurView = [[UIVisualEffectView alloc] initWithEffect:pauseBlur];
        pauseBlurView.frame = CGRectMake(0, 0, btnW, btnH);
        pauseBlurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        pauseBlurView.userInteractionEnabled = NO;
        pauseBlurView.layer.cornerRadius = 13.0;
        pauseBlurView.layer.masksToBounds = YES;
        [self.pauseButton insertSubview:pauseBlurView atIndex:0];

        self.pauseButton.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.5];
        self.pauseButton.titleLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
        [self.pauseButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.pauseButton setTitle:[BHIManager isTurkish] ? @"Duraklat" : @"Pause" forState:UIControlStateNormal];

        [self.pauseButton addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
        [self.pauseButton addTarget:self action:@selector(buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        [self.pauseButton addTarget:self action:@selector(togglePauseResume) forControlEvents:UIControlEventTouchUpInside];
        self.pauseButton.hidden = YES;
    }

    if (!self.stopButton) {
        // 4. Durdur Butonu - 56x26 pt
        self.stopButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.stopButton.tag = 8884;
        self.stopButton.backgroundColor = [UIColor colorWithRed:0.92 green:0.20 blue:0.24 alpha:0.92];
        self.stopButton.layer.cornerRadius = 13.0;
        self.stopButton.layer.masksToBounds = YES;
        self.stopButton.layer.borderWidth = 0.5;
        self.stopButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.25].CGColor;
        if (@available(iOS 13.0, *)) {
            self.stopButton.layer.cornerCurve = kCACornerCurveContinuous;
        }

        self.stopButton.titleLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
        [self.stopButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.stopButton setTitle:[BHIManager isTurkish] ? @"Durdur" : @"Stop" forState:UIControlStateNormal];

        [self.stopButton addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
        [self.stopButton addTarget:self action:@selector(buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        [self.stopButton addTarget:self action:@selector(stopRecording) forControlEvents:UIControlEventTouchUpInside];
        self.stopButton.hidden = YES;
    }
}

- (UIView *)secureCanvasView {
    if (!self.secureField) return nil;
    for (UIView *sub in self.secureField.subviews) {
        if ([NSStringFromClass([sub class]) containsString:@"Canvas"]) {
            return sub;
        }
    }
    return self.secureField.subviews.firstObject ?: self.secureField;
}

- (void)buttonTouchDown:(UIButton *)sender {
    [UIView animateWithDuration:0.1 animations:^{
        sender.transform = CGAffineTransformMakeScale(0.94, 0.94);
        sender.alpha = 0.82;
    }];
}

- (void)buttonTouchUp:(UIButton *)sender {
    [UIView animateWithDuration:0.15 animations:^{
        sender.transform = CGAffineTransformIdentity;
        sender.alpha = 1.0;
    }];
}

#pragma mark - Timer Logic

- (void)startTimer {
    @try {
        [self stopTimer];
        self.elapsedSeconds = 0;
        self.timerLabel.text = @"00:00";
        self.timerLabel.textColor = [UIColor whiteColor];
        self.timerDot.backgroundColor = [UIColor colorWithRed:1.0 green:0.22 blue:0.22 alpha:1.0];
        self.timerDot.alpha = 1.0;

        self.recordingTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(timerTick) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.recordingTimer forMode:NSRunLoopCommonModes];
    } @catch (__unused NSException *e) {}
}

- (void)timerTick {
    if (!self.isRecording || self.isPaused) return;
    self.elapsedSeconds++;
    self.timerLabel.text = [self formattedTimeString:self.elapsedSeconds];

    // Canlı yayın esnasında sonradan beliren veya güncellenen katmanları (yeni hediye, sıralama, izleyici vb.) periyodik gizle
    if (self.elapsedSeconds % 2 == 0) {
        [self hideLiveOverlaysSafely];
    }

    [UIView animateWithDuration:0.4 animations:^{
        self.timerDot.alpha = (self.timerDot.alpha > 0.5) ? 0.3 : 1.0;
    }];
}

- (void)pauseTimer {
    @try {
        self.timerLabel.textColor = [UIColor colorWithRed:1.0 green:0.80 blue:0.1 alpha:1.0];
        self.timerDot.backgroundColor = [UIColor colorWithRed:1.0 green:0.80 blue:0.1 alpha:1.0];
        self.timerDot.alpha = 1.0;
    } @catch (__unused NSException *e) {}
}

- (void)resumeTimer {
    @try {
        self.timerLabel.textColor = [UIColor whiteColor];
        self.timerDot.backgroundColor = [UIColor colorWithRed:1.0 green:0.22 blue:0.22 alpha:1.0];
        self.timerDot.alpha = 1.0;
    } @catch (__unused NSException *e) {}
}

- (void)stopTimer {
    @try {
        if (self.recordingTimer) {
            [self.recordingTimer invalidate];
            self.recordingTimer = nil;
        }
        self.elapsedSeconds = 0;
        self.timerDot.alpha = 1.0;
    } @catch (__unused NSException *e) {}
}

- (NSString *)formattedTimeString:(NSInteger)totalSecs {
    NSInteger hrs = totalSecs / 3600;
    NSInteger mins = (totalSecs % 3600) / 60;
    NSInteger secs = totalSecs % 60;
    if (hrs > 0) {
        return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)hrs, (long)mins, (long)secs];
    }
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)mins, (long)secs];
}

#pragma mark - Safe Live Overlay Management (Clean Feed Recording)

static inline BOOL isLiveVideoOrPlayerView(UIView *view) {
    if (!view) return NO;
    NSString *cls = NSStringFromClass([view class]);
    if ([cls containsString:@"Player"] ||
        [cls containsString:@"VideoEngine"] ||
        [cls containsString:@"TVL"] ||
        [cls containsString:@"Metal"] ||
        [cls containsString:@"OpenGL"] ||
        [cls containsString:@"GLKView"]) {
        return YES;
    }
    CALayer *layer = view.layer;
    if ([layer isKindOfClass:NSClassFromString(@"CAMetalLayer")] ||
        [layer isKindOfClass:NSClassFromString(@"AVPlayerLayer")]) {
        return YES;
    }
    return NO;
}

static inline BOOL isLiveOverlayContainerView(UIView *view) {
    if (!view) return NO;
    NSString *cls = NSStringFromClass([view class]);
    
    // Canlı yayın arayüzü, üst bar, sıralama, galeri, izleyici ve alt araç çubuğu bileşenleri
    if ([cls containsString:@"PluginLayout"] ||
        [cls containsString:@"MessageList"] ||
        [cls containsString:@"Comment"] ||
        [cls containsString:@"Toolbar"] ||
        [cls containsString:@"PublicScreen"] ||
        [cls containsString:@"Profile"] ||
        [cls containsString:@"BottomView"] ||
        [cls containsString:@"TopView"] ||
        [cls containsString:@"TopBar"] ||
        [cls containsString:@"TopContainer"] ||
        [cls containsString:@"Header"] ||
        [cls containsString:@"NavBar"] ||
        [cls containsString:@"NavigationBar"] ||
        [cls containsString:@"NavView"] ||
        [cls containsString:@"Rank"] ||
        [cls containsString:@"Ranking"] ||
        [cls containsString:@"Gallery"] ||
        [cls containsString:@"AudienceList"] ||
        [cls containsString:@"AudienceEntrance"] ||
        [cls containsString:@"UserList"] ||
        [cls containsString:@"Viewer"] ||
        [cls containsString:@"Close"] ||
        [cls containsString:@"Gift"] ||
        [cls containsString:@"Digg"] ||
        [cls containsString:@"Sticker"] ||
        [cls containsString:@"Barrage"] ||
        [cls containsString:@"Pendant"] ||
        [cls containsString:@"Interaction"] ||
        [cls containsString:@"FollowGuide"] ||
        [cls containsString:@"AnchorInfo"] ||
        [cls containsString:@"Badge"] ||
        [cls containsString:@"Level"] ||
        [cls containsString:@"Lynx"] ||
        [cls containsString:@"Anole"] ||
        [cls containsString:@"Slot"] ||
        [cls containsString:@"Banner"] ||
        [cls containsString:@"Activity"] ||
        [cls containsString:@"Campaign"] ||
        [cls containsString:@"Notice"] ||
        [cls containsString:@"Task"] ||
        [cls containsString:@"Capsule"] ||
        [cls containsString:@"Drawer"] ||
        [cls containsString:@"Battle"] ||
        [cls containsString:@"Match"] ||
        [cls containsString:@"ScoreBar"] ||
        [cls containsString:@"Enigma"] ||
        [cls containsString:@"PK"] ||
        [cls containsString:@"GoodyBag"] ||
        [cls containsString:@"Treasure"] ||
        [cls containsString:@"LuckyBox"] ||
        [cls containsString:@"RedPacket"] ||
        [cls containsString:@"Coin"] ||
        [cls containsString:@"Topic"] ||
        [cls containsString:@"Mic"] ||
        [cls containsString:@"LinkMic"] ||
        [cls containsString:@"MultiGuest"] ||
        [cls containsString:@"Cohost"] ||
        [cls containsString:@"Goal"] ||
        [cls containsString:@"StarComment"] ||
        [cls containsString:@"Vote"] ||
        [cls containsString:@"Poll"] ||
        [cls containsString:@"Cart"] ||
        [cls containsString:@"Shop"] ||
        [cls containsString:@"ECom"] ||
        [cls containsString:@"HotLive"] ||
        [cls containsString:@"Popular"] ||
        [cls containsString:@"Event"] ||
        [cls containsString:@"Mission"] ||
        [cls containsString:@"Wish"] ||
        [cls containsString:@"Drops"] ||
        [cls containsString:@"Tag"]) {
        return YES;
    }
    
    return NO;
}

static inline BOOL viewOrSubviewsContainLiveOverlayText(UIView *view) {
    if (!view) return NO;
    if ([view isKindOfClass:[UILabel class]]) {
        NSString *text = [(UILabel *)view text];
        if (text.length > 0 && ([text containsString:@"Sıralama"] || 
                                [text containsString:@"Rank"] || 
                                [text containsString:@"Galeri"] || 
                                [text containsString:@"Gallery"] ||
                                [text containsString:@"Popüler"] ||
                                [text containsString:@"Popular"] ||
                                [text containsString:@"CANLI"] ||
                                [text containsString:@"Hedef"] ||
                                [text containsString:@"Goal"] ||
                                [text containsString:@"Giriş"] ||
                                [text containsString:@"Patiler"])) {
            return YES;
        }
    }
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UILabel class]]) {
            NSString *text = [(UILabel *)sub text];
            if (text.length > 0 && ([text containsString:@"Sıralama"] || 
                                    [text containsString:@"Rank"] || 
                                    [text containsString:@"Galeri"] || 
                                    [text containsString:@"Gallery"] ||
                                    [text containsString:@"Popüler"] ||
                                    [text containsString:@"Popular"] ||
                                    [text containsString:@"CANLI"] ||
                                    [text containsString:@"Hedef"] ||
                                    [text containsString:@"Goal"] ||
                                    [text containsString:@"Giriş"] ||
                                    [text containsString:@"Patiler"])) {
                return YES;
            }
        }
    }
    return NO;
}

- (void)hideLiveOverlaysSafely {
    @try {
        if (!self.currentLiveVC || !self.currentLiveVC.view) return;
        if (!self.hiddenOverlays) {
            self.hiddenOverlays = [NSHashTable weakObjectsHashTable];
        }

        // Tüm aktif pencereleri tara (üst katmanlar veya overlay pencereleri kaçmasın)
        NSMutableArray<UIView *> *queue = [NSMutableArray array];
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *winScene = (UIWindowScene *)scene;
                    for (UIWindow *win in winScene.windows) {
                        if (win && !win.hidden && win != self.secureField.window) {
                            [queue addObject:win];
                        }
                    }
                }
            }
        }
        if (queue.count == 0) {
            for (UIWindow *win in [UIApplication sharedApplication].windows) {
                if (win && !win.hidden) {
                    [queue addObject:win];
                }
            }
        }
        if (queue.count == 0 && self.currentLiveVC && self.currentLiveVC.view) {
            UIView *rootView = self.currentLiveVC.view.window ?: self.currentLiveVC.view;
            [queue addObject:rootView];
        }

        NSInteger safetyCounter = 0;
        while (queue.count > 0 && safetyCounter < 1500) {
            safetyCounter++;
            UIView *current = queue.firstObject;
            [queue removeObjectAtIndex:0];

            // Pencere ve ana controller görünümünü asla gizleme, alt elemanlarına in
            if ([current isKindOfClass:[UIWindow class]] || current == self.currentLiveVC.view) {
                for (UIView *sub in current.subviews) {
                    [queue addObject:sub];
                }
                continue;
            }

            // Tweak'in kendi kontrol paneli (Sayaç, Durdur butonu vs.) dokunulmaz
            if (current.tag == 8880 || current.tag == 8881 || current.tag == 8882 || current.tag == 8883 || current.tag == 8884 || current.tag == 8885 ||
                current == self.containerView || current == self.secureField) {
                continue;
            }

            if ([current isDescendantOfView:self.secureField] || [current isDescendantOfView:self.containerView]) {
                continue;
            }

            NSString *cls = NSStringFromClass([current class]);

            // Ana oda container/root görünümleri gizlenmez, alt dallarına inilir
            if ([cls isEqualToString:@"IESLiveMTAudienceView"] ||
                [cls isEqualToString:@"IESLiveAudienceView"] ||
                [cls containsString:@"AudienceViewController"]) {
                for (UIView *sub in current.subviews) {
                    [queue addObject:sub];
                }
                continue;
            }

            // Video oynatıcı (Metal / Player / VideoEngine / TVL) katmanlarına kesinlikle dokunulmaz!
            if (isLiveVideoOrPlayerView(current)) {
                continue;
            }

            // Canlı yayın arayüz katmanını sınıf adı veya metin içeriğine göre tespit et
            BOOL isOverlay = isLiveOverlayContainerView(current);
            if (!isOverlay && viewOrSubviewsContainLiveOverlayText(current)) {
                isOverlay = YES;
            }

            if (isOverlay) {
                if (!current.hidden && current.alpha > 0.01) {
                    current.hidden = YES;
                    [self.hiddenOverlays addObject:current];
                }
                // Gizlenen arayüz konteynerinin alt elemanlarına inmeye gerek yok
                continue;
            }

            for (UIView *sub in current.subviews) {
                [queue addObject:sub];
            }
        }
    } @catch (__unused NSException *e) {}
}

- (void)restoreLiveOverlaysSafely {
    @try {
        for (UIView *view in self.hiddenOverlays) {
            if (view) {
                view.hidden = NO;
            }
        }
        [self.hiddenOverlays removeAllObjects];
    } @catch (__unused NSException *e) {}
}

#pragma mark - Recording Logic

- (void)togglePauseResume {
    if (self.isPaused) {
        [self resumeRecording];
    } else {
        [self pauseRecording];
    }
}

- (void)startRecording {
    if (self.isRecording) return;
    if (!self.currentLiveVC || !self.currentLiveVC.view) {
        self.currentLiveVC = topMostController();
    }
    if (!self.currentLiveVC || !self.currentLiveVC.view) return;

    [self setupUIInView:self.currentLiveVC.view];

    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    CGFloat scale = [UIScreen mainScreen].scale;
    self.videoWidth = ((NSInteger)(screenSize.width * scale)) & ~1;
    self.videoHeight = ((NSInteger)(screenSize.height * scale)) & ~1;

    NSString *fileName = [NSString stringWithFormat:@"live_%@.mp4", [NSUUID UUID].UUIDString];
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
    self.outputURL = [NSURL fileURLWithPath:tempPath];
    [[NSFileManager defaultManager] removeItemAtURL:self.outputURL error:nil];

    NSError *error = nil;
    self.assetWriter = [AVAssetWriter assetWriterWithURL:self.outputURL fileType:AVFileTypeMPEG4 error:&error];
    if (error || !self.assetWriter) {
        Class toastCls = NSClassFromString(@"AWEToast");
        if (toastCls && [toastCls respondsToSelector:@selector(showError:)]) {
            [toastCls performSelector:@selector(showError:) withObject:[BHIManager isTurkish] ? @"Kayıt Başlatılamadı" : @"Recording Failed"];
        }
        return;
    }

    NSDictionary *videoSettings = @{
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoWidthKey: @(self.videoWidth),
        AVVideoHeightKey: @(self.videoHeight),
        AVVideoCompressionPropertiesKey: @{
            AVVideoAverageBitRateKey: @(self.videoWidth * self.videoHeight * 4),
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoExpectedSourceFrameRateKey: @(60)
        }
    };

    self.videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    self.videoInput.expectsMediaDataInRealTime = YES;

    NSDictionary *pixelBufferAttrs = @{
        (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
        (id)kCVPixelBufferWidthKey: @(self.videoWidth),
        (id)kCVPixelBufferHeightKey: @(self.videoHeight)
    };

    self.adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.videoInput sourcePixelBufferAttributes:pixelBufferAttrs];

    if ([self.assetWriter canAddInput:self.videoInput]) {
        [self.assetWriter addInput:self.videoInput];
    }

    AudioChannelLayout acl;
    bzero(&acl, sizeof(acl));
    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Stereo;

    NSDictionary *audioSettings = @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVNumberOfChannelsKey: @(2),
        AVSampleRateKey: @(44100.0),
        AVEncoderBitRateKey: @(128000),
        AVChannelLayoutKey: [NSData dataWithBytes:&acl length:sizeof(acl)]
    };

    self.audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
    self.audioInput.expectsMediaDataInRealTime = YES;
    if ([self.assetWriter canAddInput:self.audioInput]) {
        [self.assetWriter addInput:self.audioInput];
    }

    [self.assetWriter startWriting];

    self.isRecording = YES;
    self.isPaused = NO;
    self.isSessionStarted = NO;
    self.firstFramePTS = kCMTimeZero;
    self.totalPausedTime = kCMTimeZero;

    // Yorum katmanlarını güvenli şekilde gizle (Crash korumalı)
    [self hideLiveOverlaysSafely];

    // Sayaç, Duraklat ve Durdur butonlarını güvenli canvas içine alarak
    // ekranda kullanıcıya gösterirken REPLAYKIT VİDEO KAYDINDAN GİZLİYORUZ!
    CGFloat screenW = self.currentLiveVC.view.bounds.size.width > 0 ? self.currentLiveVC.view.bounds.size.width : [UIScreen mainScreen].bounds.size.width;
    CGFloat topInset = 47.0;
    if (@available(iOS 11.0, *)) {
        if (self.currentLiveVC.view.safeAreaInsets.top > 0) {
            topInset = self.currentLiveVC.view.safeAreaInsets.top;
        }
    }
    CGFloat btnW = 56.0;
    CGFloat btnH = 26.0;
    CGFloat timerH = 20.0;
    CGFloat spacing = 4.0;
    CGFloat btnX = screenW - btnW - 12.0;
    CGFloat btnY = topInset + 75.0;
    CGFloat secureH = timerH + spacing + (btnH * 2.0) + spacing;

    if (!self.secureField) {
        self.secureField = [[BHTSecureTextField alloc] initWithFrame:CGRectZero];
        self.secureField.tag = 8880;
    }
    self.secureField.frame = CGRectMake(btnX, btnY, btnW, secureH);
    if (self.secureField.superview != self.currentLiveVC.view) {
        [self.currentLiveVC.view addSubview:self.secureField];
    }
    [self.secureField layoutIfNeeded];

    UIView *canvas = [self secureCanvasView];
    if (canvas) {
        canvas.frame = self.secureField.bounds;
        canvas.clipsToBounds = NO;
        canvas.userInteractionEnabled = YES;

        if (self.timerContainer.superview != canvas) {
            [self.timerContainer removeFromSuperview];
            [canvas addSubview:self.timerContainer];
        }
        if (self.pauseButton.superview != canvas) {
            [self.pauseButton removeFromSuperview];
            [canvas addSubview:self.pauseButton];
        }
        if (self.stopButton.superview != canvas) {
            [self.stopButton removeFromSuperview];
            [canvas addSubview:self.stopButton];
        }
    }

    self.timerContainer.frame = CGRectMake(0, 0, btnW, timerH);
    self.pauseButton.frame = CGRectMake(0, timerH + spacing, btnW, btnH);
    self.stopButton.frame = CGRectMake(0, timerH + spacing + btnH + spacing, btnW, btnH);

    self.containerView.hidden = YES;
    self.recordButton.hidden = YES;
    self.timerContainer.hidden = NO;
    self.pauseButton.hidden = NO;
    self.stopButton.hidden = NO;
    self.secureField.hidden = NO;
    [self.currentLiveVC.view bringSubviewToFront:self.secureField];

    __weak typeof(self) weakSelf = self;
    if (@available(iOS 11.0, *)) {
        @try {
            [[RPScreenRecorder sharedRecorder] startCaptureWithHandler:^(CMSampleBufferRef sampleBuffer, RPSampleBufferType sampleBufferType, NSError *captureError) {
                if (!weakSelf.isRecording || weakSelf.isPaused) return;

                if (sampleBufferType == RPSampleBufferTypeVideo) {
                    [weakSelf processVideoSampleBuffer:sampleBuffer];
                } else if (sampleBufferType == RPSampleBufferTypeAudioApp) {
                    [weakSelf processAudioSampleBuffer:sampleBuffer];
                }
            } completionHandler:^(NSError * _Nullable captureError) {
                if (captureError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf cancelRecordingCleanup];
                        Class toastCls = NSClassFromString(@"AWEToast");
                        if (toastCls && [toastCls respondsToSelector:@selector(showError:)]) {
                            [toastCls performSelector:@selector(showError:) withObject:[BHIManager isTurkish] ? @"Ekran Kaydı İzni Gerekli" : @"Screen Recording Permission Required"];
                        }
                        [weakSelf resetUI];
                    });
                }
            }];
        } @catch (__unused NSException *e) {}
    }

    Class toastCls = NSClassFromString(@"AWEToast");
    if (toastCls && [toastCls respondsToSelector:@selector(showSuccess:)]) {
        [toastCls performSelector:@selector(showSuccess:) withObject:[BHIManager isTurkish] ? @"Canlı Yayın Kaydı Başladı" : @"Live Recording Started"];
    }
}

- (void)cancelRecordingCleanup {
    [self stopTimer];
    [self restoreLiveOverlaysSafely];
    if (self.assetWriter && self.assetWriter.status == AVAssetWriterStatusWriting) {
        [self.assetWriter cancelWriting];
    }
    self.assetWriter = nil;
    self.videoInput = nil;
    self.audioInput = nil;
    self.adaptor = nil;
    if (self.outputURL) {
        [[NSFileManager defaultManager] removeItemAtURL:self.outputURL error:nil];
        self.outputURL = nil;
    }
}

- (void)processVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (!self.isRecording || self.isPaused) return;
    if (!self.assetWriter || self.assetWriter.status != AVAssetWriterStatusWriting) return;
    if (!self.videoInput.isReadyForMoreMediaData) return;

    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!pixelBuffer) return;

    CMTime originalPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    if (!self.isSessionStarted) {
        self.isSessionStarted = YES;
        self.firstFramePTS = originalPTS;
        [self.assetWriter startSessionAtSourceTime:originalPTS];

        // İlk frame geldiği an sayacı ana iş parçacığında başlat
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf startTimer];
        });
    }

    CMTime adjustedPTS = originalPTS;
    if (CMTIME_IS_VALID(self.totalPausedTime) && self.totalPausedTime.value > 0) {
        adjustedPTS = CMTimeSubtract(adjustedPTS, self.totalPausedTime);
    }
    if (CMTimeCompare(adjustedPTS, self.firstFramePTS) < 0) return;

    [self.adaptor appendPixelBuffer:pixelBuffer withPresentationTime:adjustedPTS];
}

- (void)processAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (!self.isRecording || self.isPaused) return;
    if (!self.isSessionStarted) return;
    if (!self.assetWriter || self.assetWriter.status != AVAssetWriterStatusWriting) return;
    if (!self.audioInput || !self.audioInput.isReadyForMoreMediaData) return;

    CMTime audioPTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    if (CMTimeCompare(audioPTS, self.firstFramePTS) < 0) return;

    if (CMTIME_IS_VALID(self.totalPausedTime) && self.totalPausedTime.value > 0) {
        CMSampleTimingInfo timingInfo;
        CMSampleBufferGetSampleTimingInfo(sampleBuffer, 0, &timingInfo);
        timingInfo.presentationTimeStamp = CMTimeSubtract(timingInfo.presentationTimeStamp, self.totalPausedTime);
        CMSampleBufferRef newBuffer = NULL;
        CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault, sampleBuffer, 1, &timingInfo, &newBuffer);
        if (newBuffer) {
            [self.audioInput appendSampleBuffer:newBuffer];
            CFRelease(newBuffer);
        }
    } else {
        [self.audioInput appendSampleBuffer:sampleBuffer];
    }
}

- (void)pauseRecording {
    if (!self.isRecording || self.isPaused) return;

    self.isPaused = YES;
    self.pauseStartPTS = CACurrentMediaTime();
    [self pauseTimer];

    [self.pauseButton setTitle:[BHIManager isTurkish] ? @"Devam" : @"Resume" forState:UIControlStateNormal];
    self.pauseButton.backgroundColor = [UIColor colorWithRed:0.16 green:0.68 blue:0.36 alpha:0.9];
}

- (void)resumeRecording {
    if (!self.isRecording || !self.isPaused) return;

    CFTimeInterval pauseDuration = CACurrentMediaTime() - self.pauseStartPTS;
    if (pauseDuration > 0) {
        CMTime pauseCMTime = CMTimeMakeWithSeconds(pauseDuration, 600);
        if (!CMTIME_IS_VALID(self.totalPausedTime) || self.totalPausedTime.value == 0) {
            self.totalPausedTime = pauseCMTime;
        } else {
            self.totalPausedTime = CMTimeAdd(self.totalPausedTime, pauseCMTime);
        }
    }

    self.isPaused = NO;
    [self resumeTimer];

    [self.pauseButton setTitle:[BHIManager isTurkish] ? @"Duraklat" : @"Pause" forState:UIControlStateNormal];
    self.pauseButton.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.5];
}

- (void)stopRecording {
    if (!self.isRecording) return;

    self.isRecording = NO;
    self.isPaused = NO;
    self.isSessionStarted = NO;

    [self stopTimer];
    [self restoreLiveOverlaysSafely];

    if (@available(iOS 11.0, *)) {
        @try {
            [[RPScreenRecorder sharedRecorder] stopCaptureWithHandler:nil];
        } @catch (__unused NSException *e) {}
    }

    self.hud = [JGProgressHUD progressHUDWithStyle:JGProgressHUDStyleDark];
    self.hud.textLabel.text = [BHIManager isTurkish] ? @"Kaydediliyor..." : @"Saving...";
    UIViewController *top = topMostController();
    if (top && top.view) {
        [self.hud showInView:top.view];
    }

    [self.videoInput markAsFinished];
    if (self.audioInput) {
        [self.audioInput markAsFinished];
    }

    __weak typeof(self) weakSelf = self;
    [self.assetWriter finishWritingWithCompletionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.hud dismiss];

            if (weakSelf.assetWriter.status == AVAssetWriterStatusCompleted && weakSelf.outputURL) {
                [BHIManager saveMedia:weakSelf.outputURL fileExtension:@"mp4"];
                Class toastCls = NSClassFromString(@"AWEToast");
                if (toastCls && [toastCls respondsToSelector:@selector(showSuccess:)]) {
                    [toastCls performSelector:@selector(showSuccess:) withObject:[BHIManager isTurkish] ? @"Canlı Yayın Galeriye Kaydedildi" : @"Live Recording Saved to Photos"];
                }
            } else {
                Class toastCls = NSClassFromString(@"AWEToast");
                if (toastCls && [toastCls respondsToSelector:@selector(showError:)]) {
                    [toastCls performSelector:@selector(showError:) withObject:[BHIManager isTurkish] ? @"Kayıt Başarısız Oldu" : @"Recording Failed"];
                }
            }

            [weakSelf resetUI];
        });
    }];
}

- (void)resetUI {
    self.isRecording = NO;
    self.isPaused = NO;
    self.isSessionStarted = NO;

    [self stopTimer];
    [self restoreLiveOverlaysSafely];

    if (self.secureField) {
        self.secureField.hidden = YES;
        [self.secureField removeFromSuperview];
    }

    if (self.currentLiveVC && self.currentLiveVC.view) {
        CGFloat screenW = self.currentLiveVC.view.bounds.size.width > 0 ? self.currentLiveVC.view.bounds.size.width : [UIScreen mainScreen].bounds.size.width;
        CGFloat topInset = 47.0;
        if (@available(iOS 11.0, *)) {
            if (self.currentLiveVC.view.safeAreaInsets.top > 0) {
                topInset = self.currentLiveVC.view.safeAreaInsets.top;
            }
        }
        CGFloat btnW = 56.0;
        CGFloat btnH = 26.0;
        CGFloat btnX = screenW - btnW - 12.0;
        CGFloat btnY = topInset + 75.0;

        self.containerView.frame = CGRectMake(btnX, btnY, btnW, btnH);
        self.recordButton.frame = CGRectMake(0, 0, btnW, btnH);

        if (self.containerView.superview != self.currentLiveVC.view) {
            [self.currentLiveVC.view addSubview:self.containerView];
        }
        [self.currentLiveVC.view bringSubviewToFront:self.containerView];
    }

    self.containerView.hidden = NO;
    self.recordButton.hidden = NO;
    self.timerContainer.hidden = YES;
    self.pauseButton.hidden = YES;
    self.stopButton.hidden = YES;

    [self.pauseButton setTitle:[BHIManager isTurkish] ? @"Duraklat" : @"Pause" forState:UIControlStateNormal];
    self.pauseButton.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.5];
}

@end
