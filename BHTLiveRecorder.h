#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <ReplayKit/ReplayKit.h>

@interface BHTLiveRecorder : NSObject
@property (nonatomic, assign, readonly) BOOL isRecording;
@property (nonatomic, assign, readonly) BOOL isPaused;
@property (nonatomic, weak) UIViewController *currentLiveVC;
@property (nonatomic, copy) NSString *currentStreamURL;

+ (instancetype)shared;
- (void)attachToViewController:(UIViewController *)vc;
- (void)detachFromViewController:(UIViewController *)vc;
- (void)updateButtonFrameForViewController:(UIViewController *)vc;
- (void)startRecording;
- (void)pauseRecording;
- (void)resumeRecording;
- (void)stopRecording;
- (void)resetUI;
- (void)triggerNativeCleanScreen:(BOOL)clean;
@end
