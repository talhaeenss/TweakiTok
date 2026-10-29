#import "BHTLiveRecorder.h"
#import "BHIManager.h"
#import "TikTokHeaders.h"
#import <ReplayKit/ReplayKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import "JGProgressHUD/JGProgressHUD.h"
#import <Photos/Photos.h>

// ============================================================================
// BHTSecureTextField: Sadece kayıt esnasında Duraklat/Durdur butonlarını
// ReplayKit video çıktısından gizlemek için kullanılır.
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

// Kayıt esnasında ReplayKit'ten gizlenen butonlar (Ekranda görünür, videoda görünmez)
@property (nonatomic, strong) BHTSecureTextField *secureField;
@property (nonatomic, strong) UIButton *pauseButton;
@property (nonatomic, strong) UIButton *stopButton;

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
    }
    return self;
}

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

    CGFloat btnW = 86.0;
    CGFloat btnH = 32.0;
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
        [self.containerView removeFromSuperview];
        [self.secureField removeFromSuperview];
        self.currentLiveVC = nil;
    }
}

#pragma mark - UI Setup & Styling

- (void)setupUIInView:(UIView *)parentView {
    if (!parentView) return;

    if (!self.containerView) {
        self.containerView = [[UIView alloc] initWithFrame:CGRectZero];
        self.containerView.tag = 8881;
        self.containerView.backgroundColor = [UIColor clearColor];
        self.containerView.clipsToBounds = NO;
        self.containerView.userInteractionEnabled = YES;

        // 1. Kaydet Butonu ("Kaydet" / "Record")
        self.recordButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.recordButton.tag = 8882;
        self.recordButton.layer.cornerRadius = 16.0;
        self.recordButton.layer.masksToBounds = YES;
        self.recordButton.layer.borderWidth = 0.5;
        self.recordButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
        if (@available(iOS 13.0, *)) {
            self.recordButton.layer.cornerCurve = kCACornerCurveContinuous;
        }

        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.frame = CGRectMake(0, 0, 86.0, 32.0);
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurView.userInteractionEnabled = NO;
        blurView.layer.cornerRadius = 16.0;
        blurView.layer.masksToBounds = YES;
        [self.recordButton insertSubview:blurView atIndex:0];

        self.recordButton.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.4];
        self.recordButton.titleLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightSemibold];
        [self.recordButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.recordButton setTitle:[BHIManager isTurkish] ? @"Kaydet" : @"Record" forState:UIControlStateNormal];

        UIImage *recImg = nil;
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:8.0 weight:UIImageSymbolWeightBold];
            recImg = [[UIImage systemImageNamed:@"circle.fill"] imageWithConfiguration:config];
        }
        if (recImg) {
            [self.recordButton setImage:recImg forState:UIControlStateNormal];
            self.recordButton.tintColor = [UIColor colorWithRed:1.0 green:0.22 blue:0.22 alpha:1.0];
            self.recordButton.imageEdgeInsets = UIEdgeInsetsMake(0, -3, 0, 3);
            self.recordButton.titleEdgeInsets = UIEdgeInsetsMake(0, 3, 0, -3);
        }

        [self.recordButton addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
        [self.recordButton addTarget:self action:@selector(buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        [self.recordButton addTarget:self action:@selector(startRecording) forControlEvents:UIControlEventTouchUpInside];
        [self.containerView addSubview:self.recordButton];

        // 2. Duraklat / Devam Et Butonu
        self.pauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.pauseButton.tag = 8883;
        self.pauseButton.layer.cornerRadius = 16.0;
        self.pauseButton.layer.masksToBounds = YES;
        self.pauseButton.layer.borderWidth = 0.5;
        self.pauseButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
        if (@available(iOS 13.0, *)) {
            self.pauseButton.layer.cornerCurve = kCACornerCurveContinuous;
        }

        UIBlurEffect *pauseBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *pauseBlurView = [[UIVisualEffectView alloc] initWithEffect:pauseBlur];
        pauseBlurView.frame = CGRectMake(0, 0, 86.0, 32.0);
        pauseBlurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        pauseBlurView.userInteractionEnabled = NO;
        pauseBlurView.layer.cornerRadius = 16.0;
        pauseBlurView.layer.masksToBounds = YES;
        [self.pauseButton insertSubview:pauseBlurView atIndex:0];

        self.pauseButton.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.5];
        self.pauseButton.titleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold];
        [self.pauseButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.pauseButton setTitle:[BHIManager isTurkish] ? @"Duraklat" : @"Pause" forState:UIControlStateNormal];

        UIImage *pauseImg = nil;
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *pConfig = [UIImageSymbolConfiguration configurationWithPointSize:9.0 weight:UIImageSymbolWeightBold];
            pauseImg = [[UIImage systemImageNamed:@"pause.fill"] imageWithConfiguration:pConfig];
        }
        if (pauseImg) {
            [self.pauseButton setImage:pauseImg forState:UIControlStateNormal];
            self.pauseButton.tintColor = [UIColor colorWithRed:1.0 green:0.80 blue:0.1 alpha:1.0];
            self.pauseButton.imageEdgeInsets = UIEdgeInsetsMake(0, -3, 0, 3);
            self.pauseButton.titleEdgeInsets = UIEdgeInsetsMake(0, 3, 0, -3);
        }

        [self.pauseButton addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown];
        [self.pauseButton addTarget:self action:@selector(buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
        [self.pauseButton addTarget:self action:@selector(togglePauseResume) forControlEvents:UIControlEventTouchUpInside];
        self.pauseButton.hidden = YES;

        // 3. Durdur Butonu
        self.stopButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.stopButton.tag = 8884;
        self.stopButton.backgroundColor = [UIColor colorWithRed:0.92 green:0.20 blue:0.24 alpha:0.92];
        self.stopButton.layer.cornerRadius = 16.0;
        self.stopButton.layer.masksToBounds = YES;
        self.stopButton.layer.borderWidth = 0.5;
        self.stopButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.25].CGColor;
        if (@available(iOS 13.0, *)) {
            self.stopButton.layer.cornerCurve = kCACornerCurveContinuous;
        }

        self.stopButton.titleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold];
        [self.stopButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.stopButton setTitle:[BHIManager isTurkish] ? @"Durdur" : @"Stop" forState:UIControlStateNormal];

        UIImage *stopImg = nil;
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *sConfig = [UIImageSymbolConfiguration configurationWithPointSize:8.5 weight:UIImageSymbolWeightBold];
            stopImg = [[UIImage systemImageNamed:@"stop.fill"] imageWithConfiguration:sConfig];
        }
        if (stopImg) {
            [self.stopButton setImage:stopImg forState:UIControlStateNormal];
            self.stopButton.tintColor = [UIColor whiteColor];
            self.stopButton.imageEdgeInsets = UIEdgeInsetsMake(0, -3, 0, 3);
            self.stopButton.titleEdgeInsets = UIEdgeInsetsMake(0, 3, 0, -3);
        }

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

    CGFloat btnW = 86.0;
    CGFloat btnH = 32.0;
    CGFloat btnX = screenW - btnW - 12.0;
    CGFloat btnY = topInset + 75.0;

    if (self.isRecording && self.secureField) {
        CGRect targetFrame = CGRectMake(btnX, btnY, btnW, (btnH * 2.0) + 6.0);
        if (!CGRectEqualToRect(self.secureField.frame, targetFrame)) {
            self.secureField.frame = targetFrame;
            UIView *canvas = [self secureCanvasView];
            if (canvas) canvas.frame = self.secureField.bounds;
        }
    } else if (self.containerView) {
        CGRect targetFrame = CGRectMake(btnX, btnY, btnW, btnH);
        if (!CGRectEqualToRect(self.containerView.frame, targetFrame)) {
            self.containerView.frame = targetFrame;
        }
    }
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

    // Duraklat ve Durdur butonlarını güvenli canvas içine alarak
    // ekranda kullanıcıya görünür ve tıklanabilir kılarken, REPLAYKIT VİDEO KAYDINDA GİZLİYORUZ!
    CGFloat screenW = self.currentLiveVC.view.bounds.size.width > 0 ? self.currentLiveVC.view.bounds.size.width : [UIScreen mainScreen].bounds.size.width;
    CGFloat topInset = 47.0;
    if (@available(iOS 11.0, *)) {
        if (self.currentLiveVC.view.safeAreaInsets.top > 0) {
            topInset = self.currentLiveVC.view.safeAreaInsets.top;
        }
    }
    CGFloat btnW = 86.0;
    CGFloat btnH = 32.0;
    CGFloat btnX = screenW - btnW - 12.0;
    CGFloat btnY = topInset + 75.0;

    if (!self.secureField) {
        self.secureField = [[BHTSecureTextField alloc] initWithFrame:CGRectZero];
        self.secureField.tag = 8880;
    }
    self.secureField.frame = CGRectMake(btnX, btnY, btnW, (btnH * 2.0) + 6.0);
    if (self.secureField.superview != self.currentLiveVC.view) {
        [self.currentLiveVC.view addSubview:self.secureField];
    }
    [self.secureField layoutIfNeeded];

    UIView *canvas = [self secureCanvasView];
    if (canvas) {
        canvas.frame = self.secureField.bounds;
        canvas.clipsToBounds = NO;
        canvas.userInteractionEnabled = YES;
        if (self.pauseButton.superview != canvas) {
            [self.pauseButton removeFromSuperview];
            [canvas addSubview:self.pauseButton];
        }
        if (self.stopButton.superview != canvas) {
            [self.stopButton removeFromSuperview];
            [canvas addSubview:self.stopButton];
        }
    }

    self.pauseButton.frame = CGRectMake(0, 0, btnW, btnH);
    self.stopButton.frame = CGRectMake(0, btnH + 6.0, btnW, btnH);

    self.containerView.hidden = YES;
    self.recordButton.hidden = YES;
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

    [self.pauseButton setTitle:[BHIManager isTurkish] ? @"Devam Et" : @"Resume" forState:UIControlStateNormal];
    self.pauseButton.backgroundColor = [UIColor colorWithRed:0.16 green:0.68 blue:0.36 alpha:0.9];

    UIImage *playImg = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *pConfig = [UIImageSymbolConfiguration configurationWithPointSize:9.0 weight:UIImageSymbolWeightBold];
        playImg = [[UIImage systemImageNamed:@"play.fill"] imageWithConfiguration:pConfig];
    }
    if (playImg) {
        [self.pauseButton setImage:playImg forState:UIControlStateNormal];
        self.pauseButton.tintColor = [UIColor whiteColor];
    }
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
    [self.pauseButton setTitle:[BHIManager isTurkish] ? @"Duraklat" : @"Pause" forState:UIControlStateNormal];
    self.pauseButton.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.5];

    UIImage *pauseImg = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *pConfig = [UIImageSymbolConfiguration configurationWithPointSize:9.0 weight:UIImageSymbolWeightBold];
        pauseImg = [[UIImage systemImageNamed:@"pause.fill"] imageWithConfiguration:pConfig];
    }
    if (pauseImg) {
        [self.pauseButton setImage:pauseImg forState:UIControlStateNormal];
        self.pauseButton.tintColor = [UIColor colorWithRed:1.0 green:0.80 blue:0.1 alpha:1.0];
    }
}

- (void)stopRecording {
    if (!self.isRecording) return;

    self.isRecording = NO;
    self.isPaused = NO;
    self.isSessionStarted = NO;

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
        CGFloat btnW = 86.0;
        CGFloat btnH = 32.0;
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
    self.pauseButton.hidden = YES;
    self.stopButton.hidden = YES;

    [self.pauseButton setTitle:[BHIManager isTurkish] ? @"Duraklat" : @"Pause" forState:UIControlStateNormal];
    self.pauseButton.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.5];

    UIImage *pauseImg = nil;
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *pConfig = [UIImageSymbolConfiguration configurationWithPointSize:9.0 weight:UIImageSymbolWeightBold];
        pauseImg = [[UIImage systemImageNamed:@"pause.fill"] imageWithConfiguration:pConfig];
    }
    if (pauseImg) {
        [self.pauseButton setImage:pauseImg forState:UIControlStateNormal];
        self.pauseButton.tintColor = [UIColor colorWithRed:1.0 green:0.80 blue:0.1 alpha:1.0];
    }
}

@end
