#import <UIKit/UIKit.h>
#import <BrightcovePlayerSDK/BCOVPlayerSDKManager.h>
#import <BrightcovePlayerSDK/BCOVPlaybackController.h>
#import <BrightcovePlayerSDK/BCOVPlaybackService.h>
#import <BrightcovePlayerSDK/BCOVPUIPlayerView.h>
#import <BrightcovePlayerSDK/BCOVBasicSessionProvider.h>
#import <BrightcovePlayerSDK/BCOVPlayerSDKManager.h>
#import <BrightcovePlayerSDK/BCOVPUIBasicControlView.h>
#import <BrightcovePlayerSDK/BCOVPlaybackSession.h>
#import <BrightcovePlayerSDK/BCOVPUISlider.h>
#import <GoogleInteractiveMediaAds/IMASettings.h>
#import <GoogleInteractiveMediaAds/IMAAdsRenderingSettings.h>
#import <React/RCTBridge.h>
#import <React/UIView+React.h>

@interface BrightcovePlayer : UIView

@property (nonatomic) BCOVPlaybackService *playbackService;
@property (nonatomic) id<BCOVPlaybackController> playbackController;
@property (nonatomic) id<BCOVPlaybackSession> playbackSession;
@property (nonatomic) BCOVPUIPlayerView *playerView;
@property (nonatomic) BOOL playing;
@property (nonatomic) float lastBufferProgress;
@property (nonatomic) float targetVolume;

@property (nonatomic, copy) NSString *referenceId;
@property (nonatomic, copy) NSString *videoId;
@property (nonatomic, copy) NSString *accountId;
@property (nonatomic, copy) NSString *policyKey;
@property (nonatomic, copy) NSString *adRulesUrl;
@property (nonatomic, copy) RCTDirectEventBlock onReady;
@property (nonatomic, copy) RCTDirectEventBlock onPlay;
@property (nonatomic, copy) RCTDirectEventBlock onPause;
@property (nonatomic, copy) RCTDirectEventBlock onEnd;
@property (nonatomic, copy) RCTDirectEventBlock onProgress;
@property (nonatomic, copy) RCTDirectEventBlock onError;
@property (nonatomic, copy) RCTDirectEventBlock onChangeDuration;
@property (nonatomic, copy) RCTDirectEventBlock onUpdateBufferProgress;
@property (nonatomic, copy) RCTDirectEventBlock onEnterFullscreen;
@property (nonatomic, copy) RCTDirectEventBlock onExitFullscreen;
@property (nonatomic, copy) RCTDirectEventBlock onAdStarted;
@property (nonatomic, copy) RCTDirectEventBlock onAdCompleted;
@property (nonatomic, copy) RCTDirectEventBlock onAdError;

-(void) seekTo:(NSNumber *)time;

@property (nonatomic, assign) BOOL adIsPlaying;
@property (nonatomic, strong) id<NSObject> notificationReceipt;

// - Google Interactive Media Ads (IMA) SDK -
// Getting started docs here:
//    https://developers.google.com/interactive-media-ads/docs/sdks/ios/

// Entry point for the SDK. Used to make ad requests.
// Note, mid and post-rolls have not been implemented, only pre-rolls. You'll have to do this yourself if you need them.
@property(nonatomic, strong) IMAAdsLoader *adsLoader;
// Main point of interaction with the SDK. Created by the SDK as the result of an ad request.
@property(nonatomic, strong) IMAAdsManager *adsManager;

@end
