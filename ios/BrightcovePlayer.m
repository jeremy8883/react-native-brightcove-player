#import "BrightcovePlayer.h"

@interface BrightcovePlayer () <BCOVPlaybackControllerDelegate, BCOVPUIPlayerViewDelegate, IMAAdsLoaderDelegate, IMAAdsManagerDelegate, IMAWebOpenerDelegate>

@end

@implementation BrightcovePlayer

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:_notificationReceipt];
}

- (instancetype)initWithFrame:(CGRect)frame {
    _progressWhenUserPressedPlay = kCMTimeZero;
    _currentProgress = kCMTimeZero;

    if (self = [super initWithFrame:frame]) {
        [self setup];
    }
    return self;
}

- (void)setup {
    _playbackController = [BCOVPlayerSDKManager.sharedManager createPlaybackController];
    _playbackController.delegate = self;
    _playbackController.autoPlay = YES;
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
                // NSLog(@"Test: fetchVideoWithVideoID success");
                self->_currentVideo = video;
                if (![@"NONE" isEqualToString:self->_adRulesUrl]) {
                    [self requestAds];
                    // Don't set the video yet, just play the add, then when it finishes (or fails),
                    // the video will get set then
                } else {
                    [self.playbackController setVideos: @[video]];
                }
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
    [self resetAndPlay: NO];
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
    [self resetAndPlay: NO];
}

- (void)adsManagerDidRequestContentPause:(IMAAdsManager *)adsManager {
    _adIsPlaying = YES;
    // The SDK is going to play ads, so pause the content.
    [_playbackController pause];
}

- (void)adsManagerDidRequestContentResume:(IMAAdsManager *)adsManager {
    _adIsPlaying = NO;
    // The SDK is done playing ads (at least for now), so resume the content.
    [self resetAndPlay: NO];
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

- (void)play {
    if (_playing) return;
    // NSLog(@"Test: [_playbackController play] from user");
    [self resetAndPlay: YES];
}

- (void)resetAndPlay:(BOOL) fromLastPosition {
    BOOL isCurrentProgressZero = CMTimeCompare(_currentProgress, kCMTimeZero) == 0;
    if (fromLastPosition && !_isLive && !isCurrentProgressZero) {
        // Now, after the kBCOVPlaybackSessionLifecycleEventPlay event below, we will
        // automatically go back to the position that the user was at when they pressed
        // play.
        _progressWhenUserPressedPlay = _currentProgress;
    } else {
        _progressWhenUserPressedPlay = kCMTimeZero;
    }

    [_playbackController setVideos: @[_currentVideo]];
}

- (void)pause {
    if (!_playing) return;
    [_playbackController pause];
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

- (void)setIsLive:(BOOL)isLive {
    _isLive = isLive;
}

- (void)refreshVolume {
    if (!_playbackSession) return;
    _playbackSession.player.volume = _targetVolume;
}

- (void)setDisableDefaultControl:(BOOL)disable {
    _playerView.controlsView.hidden = disable;
}

- (void)seekTo:(NSNumber *)time {
    CMTime cmTime = CMTimeMakeWithSeconds([time floatValue], NSEC_PER_SEC);
    _currentProgress = cmTime;
    [_playbackController seekToTime:cmTime completionHandler:^(BOOL finished) {
    }];
}

- (void)playbackController:(id<BCOVPlaybackController>)controller playbackSession:(id<BCOVPlaybackSession>)session didReceiveLifecycleEvent:(BCOVPlaybackSessionLifecycleEvent *)lifecycleEvent {
    // NSLog(@"TEST: didReceiveLifecycleEvent %@", lifecycleEvent.eventType);
    if (lifecycleEvent.eventType == kBCOVPlaybackSessionLifecycleEventReady) {
        if (self.onReady) {
            self.onReady(@{});
        }
    } else if (lifecycleEvent.eventType == kBCOVPlaybackSessionLifecycleEventPlay) {
        _playing = true;

        // Hack fix, when we paused the video, then played it again, it would immediately pause again.
        // Since playback works fine when starting from auto play, we are just reseting the video, then
        // calling a seekTo function to return the user to the last spot.
        BOOL isProgressAtZero = CMTimeCompare(_progressWhenUserPressedPlay, kCMTimeZero) == 0;
        if (!isProgressAtZero) {
            // NSLog(@"TEST: kBCOVPlaybackSessionLifecycleEventPlay seek to");
            [self->_playbackController
             seekToTime:_progressWhenUserPressedPlay
             completionHandler:^(BOOL finished) {}];
        }

        if (self.onPlay) {
            self.onPlay(@{});
        }
    } else if (lifecycleEvent.eventType == kBCOVPlaybackSessionLifecycleEventPause) {
        if (!_adIsPlaying) { // Don't do the pause callback if the ad is playing
            _playing = false;
            if (self.onPause) {
                self.onPause(@{});
            }
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
        _currentProgress = CMTimeMakeWithSeconds(progress, 100000);
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
