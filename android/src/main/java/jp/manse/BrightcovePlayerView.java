package jp.manse;

import android.graphics.Color;
import android.support.v4.view.ViewCompat;
import android.util.AttributeSet;
import android.util.Log;
import android.view.SurfaceView;
import android.widget.RelativeLayout;

import com.brightcove.ima.GoogleIMAComponent;
import com.brightcove.ima.GoogleIMAEventType;
import com.brightcove.player.edge.Catalog;
import com.brightcove.player.edge.VideoListener;
import com.brightcove.player.event.Event;
import com.brightcove.player.event.EventEmitter;
import com.brightcove.player.event.EventListener;
import com.brightcove.player.event.EventType;
import com.brightcove.player.mediacontroller.BrightcoveMediaController;
import com.brightcove.player.model.Video;
import com.brightcove.player.view.BrightcoveExoPlayerVideoView;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactContext;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.events.RCTEventEmitter;
import com.google.ads.interactivemedia.v3.api.AdDisplayContainer;
import com.google.ads.interactivemedia.v3.api.AdsRequest;
import com.google.ads.interactivemedia.v3.api.ImaSdkFactory;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

public class BrightcovePlayerView extends RelativeLayout {
    private boolean playerVideoViewWasAdded = false;

    private ThemedReactContext context;
    private BrightcoveExoPlayerVideoView playerVideoView;
    private BrightcoveMediaController mediaController;
    private String policyKey;
    private String accountId;
    private String videoId;
    private String referenceId;
    private Catalog catalog;
    private boolean autoPlay = true;
    private boolean playing = false;
    private boolean fullscreen = false;

    private GoogleIMAComponent googleIMAComponent;
    private String adRulesURL = "https://pubads.g.doubleclick.net/gampad/ads?sz=640x480&iu=/124319096/external/single_ad_samples&ciu_szs=300x250&impl=s&gdfp_req=1&env=vp&output=vast&unviewed_position_start=1&cust_params=deployment%3Ddevsite%26sample_ct%3Dskippablelinear&correlator=";

    public BrightcovePlayerView(ThemedReactContext context) {
        this(context, null);
    }

    public BrightcovePlayerView(ThemedReactContext context, AttributeSet attrs) {
        super(context, attrs);
        this.context = context;
        this.setBackgroundColor(Color.BLACK);

        this.playerVideoView = new BrightcoveExoPlayerVideoView(this.context);
        this.playerVideoView.setLayoutParams(new RelativeLayout.LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT));
        this.playerVideoView.finishInitialization();
        this.mediaController = new BrightcoveMediaController(this.playerVideoView);
        this.playerVideoView.setMediaController(this.mediaController);
        this.requestLayout();
        ViewCompat.setTranslationZ(this, 9999);

        EventEmitter eventEmitter = this.playerVideoView.getEventEmitter();
        eventEmitter.on(EventType.VIDEO_SIZE_KNOWN, new EventListener() {
            @Override
            public void processEvent(Event e) {
                fixVideoLayout();
            }
        });
        eventEmitter.on(EventType.READY_TO_PLAY, new EventListener() {
            @Override
            public void processEvent(Event e) {
                WritableMap event = Arguments.createMap();
                ReactContext reactContext = (ReactContext) BrightcovePlayerView.this.getContext();
                reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(BrightcovePlayerView.this.getId(), BrightcovePlayerManager.EVENT_READY, event);
            }
        });
        eventEmitter.on(EventType.DID_PLAY, new EventListener() {
            @Override
            public void processEvent(Event e) {
                BrightcovePlayerView.this.playing = true;
                WritableMap event = Arguments.createMap();
                ReactContext reactContext = (ReactContext) BrightcovePlayerView.this.getContext();
                reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(BrightcovePlayerView.this.getId(), BrightcovePlayerManager.EVENT_PLAY, event);
            }
        });
        eventEmitter.on(EventType.DID_PAUSE, new EventListener() {
            @Override
            public void processEvent(Event e) {
                BrightcovePlayerView.this.playing = false;
                WritableMap event = Arguments.createMap();
                ReactContext reactContext = (ReactContext) BrightcovePlayerView.this.getContext();
                reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(BrightcovePlayerView.this.getId(), BrightcovePlayerManager.EVENT_PAUSE, event);
            }
        });
        eventEmitter.on(EventType.COMPLETED, new EventListener() {
            @Override
            public void processEvent(Event e) {
                WritableMap event = Arguments.createMap();
                ReactContext reactContext = (ReactContext) BrightcovePlayerView.this.getContext();
                reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(BrightcovePlayerView.this.getId(), BrightcovePlayerManager.EVENT_END, event);
            }
        });
        eventEmitter.on(EventType.PROGRESS, new EventListener() {
            @Override
            public void processEvent(Event e) {
                WritableMap event = Arguments.createMap();
                Long playhead = (Long)e.properties.get(Event.PLAYHEAD_POSITION);
                event.putDouble("currentTime", playhead / 1000d);
                ReactContext reactContext = (ReactContext) BrightcovePlayerView.this.getContext();
                reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(BrightcovePlayerView.this.getId(), BrightcovePlayerManager.EVENT_PROGRESS, event);
            }
        });
        eventEmitter.on(EventType.ENTER_FULL_SCREEN, new EventListener() {
            @Override
            public void processEvent(Event e) {
                mediaController.show();
                WritableMap event = Arguments.createMap();
                ReactContext reactContext = (ReactContext) BrightcovePlayerView.this.getContext();
                reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(BrightcovePlayerView.this.getId(), BrightcovePlayerManager.EVENT_TOGGLE_ANDROID_FULLSCREEN, event);
            }
        });
        eventEmitter.on(EventType.EXIT_FULL_SCREEN, new EventListener() {
            @Override
            public void processEvent(Event e) {
                mediaController.show();
                WritableMap event = Arguments.createMap();
                ReactContext reactContext = (ReactContext) BrightcovePlayerView.this.getContext();
                reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(BrightcovePlayerView.this.getId(), BrightcovePlayerManager.EVENT_TOGGLE_ANDROID_FULLSCREEN, event);
            }
        });
        eventEmitter.on(EventType.VIDEO_DURATION_CHANGED, new EventListener() {
            @Override
            public void processEvent(Event e) {
                Integer duration = (Integer)e.properties.get(Event.VIDEO_DURATION);
                WritableMap event = Arguments.createMap();
                event.putDouble("duration", duration / 1000d);
                ReactContext reactContext = (ReactContext) BrightcovePlayerView.this.getContext();
                reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(BrightcovePlayerView.this.getId(), BrightcovePlayerManager.EVENT_CHANGE_DURATION, event);
            }
        });
        eventEmitter.on(EventType.BUFFERED_UPDATE, new EventListener() {
            @Override
            public void processEvent(Event e) {
                Integer percentComplete = (Integer)e.properties.get(Event.PERCENT_COMPLETE);
                WritableMap event = Arguments.createMap();
                event.putDouble("bufferProgress", percentComplete / 100d);
                ReactContext reactContext = (ReactContext) BrightcovePlayerView.this.getContext();
                reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(BrightcovePlayerView.this.getId(), BrightcovePlayerManager.EVENT_UPDATE_BUFFER_PROGRESS, event);
            }
        });
        eventEmitter.on(EventType.ERROR, new EventListener() {
            @Override
            public void processEvent(Event e) {
                WritableMap error = mapToRnWritableMap(e.properties);
                emitEvent(BrightcovePlayerManager.EVENT_ERROR, error);
            }
        });
        eventEmitter.on(EventType.BUFFERING_STARTED, new EventListener() {
            @Override
            public void processEvent(Event e) {
                WritableMap event = Arguments.createMap();
                ReactContext reactContext = (ReactContext) BrightcovePlayerView.this.getContext();
                reactContext
                        .getJSModule(RCTEventEmitter.class)
                        .receiveEvent(BrightcovePlayerView.this.getId(), BrightcovePlayerManager.EVENT_BUFFERING_STARTED, event);
            }
        });
        eventEmitter.on(EventType.BUFFERING_COMPLETED, new EventListener() {
            @Override
            public void processEvent(Event e) {
                WritableMap event = Arguments.createMap();
                ReactContext reactContext = (ReactContext) BrightcovePlayerView.this.getContext();
                reactContext
                        .getJSModule(RCTEventEmitter.class)
                        .receiveEvent(BrightcovePlayerView.this.getId(), BrightcovePlayerManager.EVENT_BUFFERING_COMPLETED, event);
            }
        });

        setupGoogleIMA(eventEmitter);

        // Because nothing is easy, we don't add the `playerVideoView` yet.
        // We wait until after the layout request (see `requestLayout` below).
    }


    @Override
    public void requestLayout() {
        super.requestLayout();
        post(new Runnable() {
            @Override
            public void run() {
                // Advertisements wouldn't run unless we waited for a layout before intializing it.
                // This issue only seemed to happen when run inside a react native component.
                if (!playerVideoViewWasAdded) {
                    addView(playerVideoView);
                    playerVideoViewWasAdded = true;
                }

                // This was needed to allow for `addView` to work asynchronously in react native.
                // Taken from the second solution in this comment:
                //   https://github.com/facebook/react-native/issues/11829#issuecomment-290300921
                measure(
                        MeasureSpec.makeMeasureSpec(getWidth(), MeasureSpec.EXACTLY),
                        MeasureSpec.makeMeasureSpec(getHeight(), MeasureSpec.EXACTLY));
                layout(getLeft(), getTop(), getRight(), getBottom());
            }
        });
    }

    private void setupGoogleIMA(final EventEmitter eventEmitter) {
        // Establish the Google IMA SDK factory instance.
        final ImaSdkFactory sdkFactory = ImaSdkFactory.getInstance();

        // Enable logging up ad start.
        eventEmitter.on(EventType.AD_STARTED, new EventListener() {
            @Override
            public void processEvent(Event e) {
                emitEvent(BrightcovePlayerManager.EVENT_AD_STARTED, null);
            }
        });

        // Enable logging any failed attempts to play an ad.
        eventEmitter.on(GoogleIMAEventType.DID_FAIL_TO_PLAY_AD, new EventListener() {
            @Override
            public void processEvent(Event event) {
                emitEvent(BrightcovePlayerManager.EVENT_AD_ERROR, null);
            }
        });

        // Enable Logging upon ad completion.
        eventEmitter.on(EventType.AD_COMPLETED, new EventListener() {
            @Override
            public void processEvent(Event event) {
                WritableMap error = mapToRnWritableMap(event.properties);
                emitEvent(BrightcovePlayerManager.EVENT_AD_ERROR, error);
            }
        });

        // Set up a listener for initializing AdsRequests. The Google
        // IMA plugin emits an ad request event as a result of
        // initializeAdsRequests() being called.
        eventEmitter.on(GoogleIMAEventType.ADS_REQUEST_FOR_VIDEO, new EventListener() {
            @Override
            public void processEvent(Event event) {
                // Create a container object for the ads to be presented.
                AdDisplayContainer container = sdkFactory.createAdDisplayContainer();
                container.setPlayer(googleIMAComponent.getVideoAdPlayer());
                container.setAdContainer(playerVideoView);

                // Build an ads request object and point it to the ad
                // display container created above.
                AdsRequest adsRequest = sdkFactory.createAdsRequest();
                adsRequest.setAdTagUrl(adRulesURL);
                adsRequest.setAdDisplayContainer(container);

                ArrayList<AdsRequest> adsRequests = new ArrayList<AdsRequest>(1);
                adsRequests.add(adsRequest);

                // Respond to the event with the new ad requests.
                event.properties.put(GoogleIMAComponent.ADS_REQUESTS, adsRequests);
                eventEmitter.respond(event);
            }
        });

        // Create the Brightcove IMA Plugin and pass in the event
        // emitter so that the plugin can integrate with the SDK.
        googleIMAComponent = new GoogleIMAComponent(playerVideoView, eventEmitter, true);
    }

    private void emitEvent(String type, WritableMap data) {
        if (data == null) {
            data = Arguments.createMap();
        }
        ReactContext reactContext = (ReactContext) BrightcovePlayerView.this.getContext();
        reactContext
                .getJSModule(RCTEventEmitter.class)
                .receiveEvent(BrightcovePlayerView.this.getId(), type, data);
    }

    // Warning, I've only tested this function for strings.
    // Also, doesn't work with recursive maps or arrays
    private WritableMap mapToRnWritableMap(Map<String, Object> map) {
        WritableMap writableMap = Arguments.createMap();
        for (String key : map.keySet()) {
            Object val = map.get(key);

            if (val instanceof String) {
                writableMap.putString(key, (String)val);
            } else if (val instanceof Integer) {
                writableMap.putInt(key, (Integer)val);
            } else if (val instanceof Boolean) {
                writableMap.putBoolean(key, (Boolean)val);
            } else if (val instanceof Double) {
                writableMap.putDouble(key, (Double)val);
            }
        }

        return writableMap;
    }

    public void setPolicyKey(String policyKey) {
        this.policyKey = policyKey;
        this.setupCatalog();
        this.loadMovie();
    }

    public void setAccountId(String accountId) {
        this.accountId = accountId;
        this.setupCatalog();
        this.loadMovie();
    }

    public void setVideoId(String videoId) {
        this.videoId = videoId;
        this.referenceId = null;
        this.setupCatalog();
        this.loadMovie();
    }

    public void setReferenceId(String referenceId) {
        this.referenceId = referenceId;
        this.videoId = null;
        this.setupCatalog();
        this.loadMovie();
    }

    public void setAutoPlay(boolean autoPlay) {
        this.autoPlay = autoPlay;
    }

    public void setPlay(boolean play) {
        if (this.playing == play) return;
        if (play) {
            this.playerVideoView.start();
        } else {
            this.playerVideoView.pause();
        }
    }

    public void setDefaultControlDisabled(boolean disabled) {
        this.mediaController.hide();
        this.mediaController.setShowHideTimeout(disabled ? 1 : 4000);
    }

    public void setFullscreen(boolean fullscreen) {
        this.mediaController.show();
        WritableMap event = Arguments.createMap();
        event.putBoolean("fullscreen", fullscreen);
        ReactContext reactContext = (ReactContext) BrightcovePlayerView.this.getContext();
        reactContext.getJSModule(RCTEventEmitter.class).receiveEvent(BrightcovePlayerView.this.getId(), BrightcovePlayerManager.EVENT_TOGGLE_ANDROID_FULLSCREEN, event);
    }

    public void setVolume(float volume) {
        Map<String, Object> details = new HashMap<>();
        details.put(Event.VOLUME, volume);
        this.playerVideoView.getEventEmitter().emit(EventType.SET_VOLUME, details);
    }

    public void seekTo(int time) {
        this.playerVideoView.seekTo(time);
    }

    private void setupCatalog() {
        if (this.catalog != null || this.policyKey == null || this.accountId == null || !playerVideoViewWasAdded) return;
        this.catalog = new Catalog(this.playerVideoView.getEventEmitter(), this.accountId, this.policyKey);
    }

    private void loadMovie() {
        if (this.catalog == null || !playerVideoViewWasAdded) return;
        VideoListener listener = new VideoListener() {

            @Override
            public void onVideo(Video video) {
                BrightcovePlayerView.this.playerVideoView.clear();
                BrightcovePlayerView.this.playerVideoView.add(video);
                if (BrightcovePlayerView.this.autoPlay) {
                    BrightcovePlayerView.this.playerVideoView.start();
                }
            }

            @Override
            public void onError(String s) {
                WritableMap error = Arguments.createMap();
                error.putString("error_code", "CATALOG_FETCH_ERROR");
                error.putString("message", s);
                emitEvent(BrightcovePlayerManager.EVENT_ERROR, error);
            }
        };
        if (this.videoId != null) {
            this.catalog.findVideoByID(this.videoId, listener);
        } else if (this.referenceId != null) {
            this.catalog.findVideoByReferenceID(this.referenceId, listener);
        }
    }

    private void fixVideoLayout() {
        int viewWidth = this.getMeasuredWidth();
        int viewHeight = this.getMeasuredHeight();
        SurfaceView surfaceView = (SurfaceView) this.playerVideoView.getRenderView();
        surfaceView.measure(viewWidth, viewHeight);
        int surfaceWidth = surfaceView.getMeasuredWidth();
        int surfaceHeight = surfaceView.getMeasuredHeight();
        int leftOffset = (viewWidth - surfaceWidth) / 2;
        int topOffset = (viewHeight - surfaceHeight) / 2;
        surfaceView.layout(leftOffset, topOffset, leftOffset + surfaceWidth, topOffset + surfaceHeight);
    }

    private void printKeys(Map<String, Object> map) {
        Log.d("debug", "-----------");
        for(Map.Entry<String, Object> entry : map.entrySet()) {
            Log.d("debug", entry.getKey());
        }
    }
}
