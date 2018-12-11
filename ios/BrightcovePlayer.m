#import "BrightcovePlayer.h"

@interface BrightcovePlayer () <BCOVPlaybackControllerDelegate, BCOVPUIPlayerViewDelegate, IMAWebOpenerDelegate>

@end

@implementation BrightcovePlayer

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:_notificationReceipt];
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setup];
    }
    return self;
}

- (void)setup {
    _playerView = [[BCOVPUIPlayerView alloc] initWithPlaybackController:self.playbackController options:nil controlsView:[BCOVPUIBasicControlView basicControlViewWithVODLayout] ];
    _playerView.delegate = self;
    _playerView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    _playerView.backgroundColor = UIColor.blackColor;

    _targetVolume = 1.0;

    [self addSubview:_playerView];
}

- (void)setupService {
    if (!_playbackService && _accountId && _policyKey && _adRulesUrl) {
        BCOVPlayerSDKManager *manager = [BCOVPlayerSDKManager sharedManager];

        IMASettings *imaSettings = [[IMASettings alloc] init];
        //    imaSettings.ppid = @"insertyourpidhere"; // ?
        imaSettings.language = @"en";

        IMAAdsRenderingSettings *renderSettings = [[IMAAdsRenderingSettings alloc] init];
        renderSettings.webOpenerDelegate = self;

        // BCOVIMAAdsRequestPolicy provides methods to specify VAST or VMAP/Server Side Ad Rules. Select the appropriate method to select your ads policy.
        BCOVIMAAdsRequestPolicy *adsRequestPolicy = [BCOVIMAAdsRequestPolicy videoPropertiesVMAPAdTagUrlAdsRequestPolicy];

        // BCOVIMAPlaybackSessionDelegate defines -willCallIMAAdsLoaderRequestAdsWithRequest:forPosition: which allows us to modify the IMAAdsRequest object
        // before it is used to load ads.
        NSDictionary *imaPlaybackSessionOptions = @{ kBCOVIMAOptionIMAPlaybackSessionDelegateKey: self };

        self.playbackController = [manager createIMAPlaybackControllerWithSettings:imaSettings
                                                              adsRenderingSettings:renderSettings
                                                                  adsRequestPolicy:adsRequestPolicy
                                                                       adContainer:self.playerView.contentOverlayView
                                                                    companionSlots:nil
                                                                      viewStrategy:nil
                                                                           options:imaPlaybackSessionOptions];
        _playbackController.delegate = self;
        _playbackController.autoPlay = YES;
        _playbackController.autoAdvance = YES;

        _playbackService = [[BCOVPlaybackService alloc] initWithAccountId:_accountId policyKey:_policyKey];

        [self resumeAdAfterForeground];
    }
}

- (void)resumeAdAfterForeground
{
    // When the app goes to the background, the Google IMA library will pause
    // the ad. This code demonstrates how you would resume the ad when entering
    // the foreground.

    BrightcovePlayer * __weak weakSelf = self;

    self.notificationReceipt = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:nil usingBlock:^(NSNotification *note) {

        BrightcovePlayer *strongSelf = weakSelf;

        if (strongSelf.adIsPlaying)
        {
            [strongSelf.playbackController resumeAd];
        }
    }];
}

- (void)loadMovie {
    if (!_playbackService) return;
    if (_videoId) {
        [_playbackService findVideoWithVideoID:_videoId parameters:nil completion:^(BCOVVideo *video, NSDictionary *jsonResponse, NSError *error) {
            if (video) {
                BCOVVideo *fixedVideo = [BrightcovePlayer updateVideoWithVMAPTag:video : self->_adRulesUrl];
                [self.playbackController setVideos: @[fixedVideo]];
            } else {
                [self emitError:error];
            }
        }];
    } else if (_referenceId) {
        [_playbackService findVideoWithReferenceID:_referenceId parameters:nil completion:^(BCOVVideo *video, NSDictionary *jsonResponse, NSError *error) {
            if (video) {
                [self.playbackController setVideos: @[ video ]];
            } else {
                [self emitError:error];
            }
        }];
    }
}

+ (BCOVVideo *)updateVideoWithVMAPTag:(BCOVVideo *)video :(NSString *)adRulesUrl
{
    // Update each video to add the tag.
    return [video update:^(id<BCOVMutableVideo> mutableVideo) {

        // The BCOVIMA plugin will look for the presence of kBCOVIMAAdTag in
        // the video's properties when using server side ad rules. This URL returns
        // a VMAP response that is handled by the Google IMA library.
        NSDictionary *adProperties = @{ kBCOVIMAAdTag : adRulesUrl };

        NSMutableDictionary *propertiesToUpdate = [mutableVideo.properties mutableCopy];
        [propertiesToUpdate addEntriesFromDictionary:adProperties];
        mutableVideo.properties = propertiesToUpdate;

    }];
}

- (void)emitError:(NSError *)error {
    if (!self.onError) {
        return;
    }

    NSString *code = [NSString stringWithFormat:@"%ld", (long)[error code]];

    self.onError(@{@"error_code": code, @"message": [error localizedDescription]});
}

- (id<BCOVPlaybackController>)createPlaybackController {
    BCOVBasicSessionProviderOptions *options = [BCOVBasicSessionProviderOptions alloc];
    BCOVBasicSessionProvider *provider = [[BCOVPlayerSDKManager sharedManager] createBasicSessionProviderWithOptions:options];
    return [BCOVPlayerSDKManager.sharedManager createPlaybackControllerWithSessionProvider:provider viewStrategy:nil];
}

- (void)setReferenceId:(NSString *)referenceId {
    _referenceId = referenceId;
    _videoId = NULL;
    [self setupService];
    [self loadMovie];
}

- (void)setVideoId:(NSString *)videoId {
    _videoId = videoId;
    _referenceId = NULL;
    [self setupService];
    [self loadMovie];
}

- (void)setAccountId:(NSString *)accountId {
    _accountId = accountId;
    [self setupService];
    [self loadMovie];
}

- (void)setPolicyKey:(NSString *)policyKey {
    _policyKey = policyKey;
    [self setupService];
    [self loadMovie];
}

- (void)setAdRulesUrl:(NSString *)adRulesUrl {
    _adRulesUrl = adRulesUrl;
    [self setupService];
    [self loadMovie];
}

- (void)setAutoPlay:(BOOL)autoPlay {
    _playbackController.autoPlay = autoPlay;
}

- (void)setPlay:(BOOL)play {
    if (_playing == play) return;
    if (play) {
        [_playbackController play];
    } else {
        [_playbackController pause];
    }
}

- (void)setFullscreen:(BOOL)fullscreen {
    if (fullscreen) {
        [_playerView performScreenTransitionWithScreenMode:BCOVPUIScreenModeFull];
    } else {
        [_playerView performScreenTransitionWithScreenMode:BCOVPUIScreenModeNormal];
    }
}

- (void)setVolume:(NSNumber*)volume {
    _targetVolume = volume.doubleValue;
    [self refreshVolume];
}

- (void)refreshVolume {
    if (!_playbackSession) return;
    _playbackSession.player.volume = _targetVolume;
}

- (void)setDisableDefaultControl:(BOOL)disable {
    _playerView.controlsView.hidden = disable;
}

- (void)seekTo:(NSNumber *)time {
    [_playbackController seekToTime:CMTimeMakeWithSeconds([time floatValue], NSEC_PER_SEC) completionHandler:^(BOOL finished) {
    }];
}

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didReceiveLifecycleEvent:(BCOVPlaybackSessionLifecycleEvent *)lifecycleEvent {
    if (lifecycleEvent.eventType == kBCOVPlaybackSessionLifecycleEventReady) {
        if (self.onReady) {
            self.onReady(@{});
        }
    } else if (lifecycleEvent.eventType == kBCOVPlaybackSessionLifecycleEventPlay) {
        _playing = true;
        if (self.onPlay) {
            self.onPlay(@{});
        }
    } else if (lifecycleEvent.eventType == kBCOVPlaybackSessionLifecycleEventPause) {
        _playing = false;
        if (self.onPause) {
            self.onPause(@{});
        }
    } else if (lifecycleEvent.eventType == kBCOVPlaybackSessionLifecycleEventEnd) {
        if (self.onEnd) {
            self.onEnd(@{});
        }
    }
}

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didChangeDuration:(NSTimeInterval)duration {
    if (self.onChangeDuration) {
        self.onChangeDuration(@{
                                @"duration": @(duration)
                                });
    }
}

-(void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didProgressTo:(NSTimeInterval)progress {
    if (self.onProgress && progress > 0 && progress != INFINITY) {
        self.onProgress(@{
                          @"currentTime": @(progress)
                          });
    }
    float bufferProgress = _playerView.controlsView.progressSlider.bufferProgress;
    if (_lastBufferProgress != bufferProgress) {
        _lastBufferProgress = bufferProgress;
        self.onUpdateBufferProgress(@{
                                      @"bufferProgress": @(bufferProgress),
                                      });
    }
}

- (void)playbackController:(id<BCOVPlaybackController>)controller didAdvanceToPlaybackSession:(id<BCOVPlaybackSession>)session {
    _playbackSession = session;
    [self refreshVolume];
}

-(void)playerView:(BCOVPUIPlayerView *)playerView didTransitionToScreenMode:(BCOVPUIScreenMode)screenMode {
    if (screenMode == BCOVPUIScreenModeNormal) {
        if (self.onExitFullscreen) {
            self.onExitFullscreen(@{});
        }
    } else if (screenMode == BCOVPUIScreenModeFull) {
        if (self.onEnterFullscreen) {
            self.onEnterFullscreen(@{});
        }
    }
}

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didEnterAdSequence:(BCOVAdSequence *)adSequence
{
    self.adIsPlaying = YES;
    self.onAdStarted(@{});
}

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didExitAdSequence:(BCOVAdSequence *)adSequence
{
    self.adIsPlaying = NO;
    self.onAdCompleted(@{});
}

#pragma mark - IMAWebOpenerDelegate Methods

- (void)webOpenerDidCloseInAppBrowser:(NSObject *)webOpener
{
    // Called when the in-app browser has closed.
    [self.playbackController resumeAd];
}

@end
