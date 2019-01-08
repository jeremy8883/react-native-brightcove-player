#import "BrightcovePlayer.h"

@interface BrightcovePlayer () <BCOVPlaybackControllerDelegate, BCOVPUIPlayerViewDelegate, IMAAdsLoaderDelegate, IMAAdsManagerDelegate, IMAWebOpenerDelegate>

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
    _playbackController = [BCOVPlayerSDKManager.sharedManager createPlaybackController];
    _playbackController.delegate = self;
    _playbackController.autoPlay = NO;
    _playbackController.autoAdvance = NO;

    _playerView = [[BCOVPUIPlayerView alloc] initWithPlaybackController:nil options:nil controlsView:[BCOVPUIBasicControlView basicControlViewWithVODLayout] ];
    _playerView.delegate = self;
    _playerView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    _playerView.backgroundColor = UIColor.blackColor;

    _playerView.playbackController = self.playbackController;

    [self addSubview:_playerView];

    _targetVolume = 1.0;
}

- (void)setupService {
    if (!_playbackService && _accountId && _policyKey && _adRulesUrl) {
        if (![@"NONE" isEqualToString:_adRulesUrl]) {
            [self setupAdsLoader];
        }

        _playbackService = [[BCOVPlaybackService alloc] initWithAccountId:_accountId policyKey:_policyKey];

        [self resumeAdAfterForeground];
    }
}

- (void)loadMovie {
    if (!_playbackService) return;
    if (_videoId) {
        [_playbackService findVideoWithVideoID:_videoId parameters:nil completion:^(BCOVVideo *video, NSDictionary *jsonResponse, NSError *error) {
            if (video) {
                if (![@"NONE" isEqualToString:self->_adRulesUrl]) {
                    [self requestAds];
                }
                [self.playbackController setVideos: @[video]];
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

#pragma mark Google Interactive Media Ads (IMA) SDK Setup

- (void)setupAdsLoader {
    self.adsLoader = [[IMAAdsLoader alloc] initWithSettings:nil];
    self.adsLoader.delegate = self;
}

- (void)requestAds {
    // Create an ad display container for ad rendering.
    IMAAdDisplayContainer *adDisplayContainer =
    [[IMAAdDisplayContainer alloc] initWithAdContainer:_playerView companionSlots:nil];
    // Create an ad request with our ad tag, display container, and optional user context.
    IMAAdsRequest *request = [[IMAAdsRequest alloc] initWithAdTagUrl:_adRulesUrl
                                                  adDisplayContainer:adDisplayContainer
                              // contentPlayhead are required for mid-rolls. You'll need to implement yourself if you need this funcationality.
                                                         contentPlayhead:nil
                                                         userContext:nil];
    [self.adsLoader requestAdsWithRequest:request];
}

- (void)resumeAdAfterForeground
{
    // When the app goes to the background, the Google IMA library will pause
    // the ad. This code resumes the ad when enteringthe foreground.
    BrightcovePlayer * __weak weakSelf = self;

    self.notificationReceipt = [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        BrightcovePlayer *strongSelf = weakSelf;

        if (strongSelf.adIsPlaying && strongSelf.adsManager && !strongSelf.isAdBrowserOpen) {
            [strongSelf.adsManager resume];
        }
    }];
}

#pragma mark AdsLoader Delegates

- (void)adsLoader:(IMAAdsLoader *)loader adsLoadedWithData:(IMAAdsLoadedData *)adsLoadedData {
    // Grab the instance of the IMAAdsManager and set ourselves as the delegate.
    self.adsManager = adsLoadedData.adsManager;
    self.adsManager.delegate = self;
    // Reduce ad volume by half. This was code found in the brightcove samples. It
    // was copied over because the ads were playing very loudly compared to the
    // actual video content.
    self.adsManager.volume = self.adsManager.volume / 2.0;
    // Create ads rendering settings to tell the SDK to use the in-app browser.
    IMAAdsRenderingSettings *adsRenderingSettings = [[IMAAdsRenderingSettings alloc] init];
    adsRenderingSettings.webOpenerDelegate = self;
    adsRenderingSettings.webOpenerPresentingController = self.reactViewController;
    // Initialize the ads manager.
    [self.adsManager initializeWithAdsRenderingSettings:adsRenderingSettings];
}

- (void)adsLoader:(IMAAdsLoader *)loader failedWithErrorData:(IMAAdLoadingErrorData *)adErrorData {
    // Something went wrong loading ads.
    NSString *errorCode = [NSString stringWithFormat:@"%ld", (long)adErrorData.adError.code];
    self.onAdError(@{
        @"error_code": errorCode,
        @"message": adErrorData.adError.message,
    });
    [_playbackController play];
}

#pragma mark AdsManager Delegates

- (void)adsManager:(IMAAdsManager *)adsManager didReceiveAdEvent:(IMAAdEvent *)event {
    // When the SDK notified us that ads have been loaded, play them.
    if (event.type == kIMAAdEvent_LOADED) {
        [adsManager start];
    } else if (event.type == kIMAAdEvent_STARTED) {
        self.adIsPlaying = YES;
        self.onAdStarted(@{});
    } else if (event.type == kIMAAdEvent_COMPLETE) {
        self.adIsPlaying = NO;
        self.onAdCompleted(@{});
    }
}

- (void)adsManager:(IMAAdsManager *)adsManager didReceiveAdError:(IMAAdError *)error {
    // Something went wrong with the ads manager after ads were loaded.
    NSString *errorCode = [NSString stringWithFormat:@"%ld", (long)error.code];
    self.onAdError(@{
      @"error_code": errorCode,
      @"message": error.message,
    });
    [_playbackController play];
}

- (void)adsManagerDidRequestContentPause:(IMAAdsManager *)adsManager {
    // The SDK is going to play ads, so pause the content.
    [_playbackController pause];
}

- (void)adsManagerDidRequestContentResume:(IMAAdsManager *)adsManager {
    // The SDK is done playing ads (at least for now), so resume the content.
    [_playbackController play];
}

#pragma mark getters / setters

- (void)emitError:(NSError *)error {
    if (!self.onError) {
        return;
    }

    NSString *code = [NSString stringWithFormat:@"%ld", (long)[error code]];

    self.onError(@{@"error_code": code, @"message": [error localizedDescription]});
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

#pragma mark - IMAWebOpenerDelegate Methods

- (void)webOpenerDidOpenInAppBrowser:(NSObject *)webOpener {
    _isAdBrowserOpen = YES;
    if (self.onAdOpenInBrowser) {
        self.onAdOpenInBrowser(@{});
    }
}

- (void)webOpenerDidCloseInAppBrowser:(NSObject *)webOpener {
    _isAdBrowserOpen = NO;
    if (![@"NONE" isEqualToString:_adRulesUrl]) {
        // Called when the in-app browser has closed.
        [_adsManager resume];
    }
    if (self.onAdReturnFromBrowser) {
        self.onAdReturnFromBrowser(@{});
    }
}

@end
