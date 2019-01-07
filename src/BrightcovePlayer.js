import React, { Component } from 'react';
import PropTypes from 'prop-types';
import ReactNative, {
  View,
  requireNativeComponent,
  NativeModules,
  ViewPropTypes,
  Platform,
  UIManager
} from 'react-native';

class BrightcovePlayer extends Component {
  state = {
    androidFullscreen: false
  };

  setNativeProps = nativeProps => {
    if (this._root) {
      this._root.setNativeProps(nativeProps);
    }
  };

  render() {
    return (
      <NativeBrightcovePlayer
        ref={e => (this._root = e)}
        {...this.props}
        style={[
          this.props.style,
          this.state.androidFullscreen && {
            position: 'absolute',
            zIndex: 9999,
            top: 0,
            left: 0,
            width: '100%',
            height: '100%'
          }
        ]}
        adRulesUrl={this.props.adRulesUrl || 'NONE'}
        onReady={event =>
          this.props.onReady && this.props.onReady(event.nativeEvent)
        }
        onPlay={event =>
          this.props.onPlay && this.props.onPlay(event.nativeEvent)
        }
        onPause={event =>
          this.props.onPause && this.props.onPause(event.nativeEvent)
        }
        onEnd={event => this.props.onEnd && this.props.onEnd(event.nativeEvent)}
        onProgress={event =>
          this.props.onProgress && this.props.onProgress(event.nativeEvent)
        }
        onChangeDuration={event =>
          this.props.onChangeDuration &&
          this.props.onChangeDuration(event.nativeEvent)
        }
        onUpdateBufferProgress={event =>
          this.props.onUpdateBufferProgress &&
          this.props.onUpdateBufferProgress(event.nativeEvent)
        }
        onBufferingStarted={event =>
          this.props.onBufferingStarted &&
          this.props.onBufferingStarted(event.nativeEvent)
        }
        onBufferingCompleted={event =>
          this.props.onBufferingCompleted &&
          this.props.onBufferingCompleted(event.nativeEvent)
        }
        onEnterFullscreen={event =>
          this.props.onEnterFullscreen &&
          this.props.onEnterFullscreen(event.nativeEvent)
        }
        onExitFullscreen={event =>
          this.props.onExitFullscreen &&
          this.props.onExitFullscreen(event.nativeEvent)
        }
        onError={event =>
          this.props.onError && this.props.onError(event.nativeEvent)
        }
        onToggleAndroidFullscreen={event => {
          const fullscreen =
            typeof event.nativeEvent.fullscreen === 'boolean'
              ? event.nativeEvent.fullscreen
              : !this.state.androidFullscreen;
          if (fullscreen === this.state.androidFullscreen) return;
          this.setState({ androidFullscreen: fullscreen });
          if (fullscreen) {
            this.props.onEnterFullscreen &&
            this.props.onEnterFullscreen(event.nativeEvent);
          } else {
            this.props.onExitFullscreen &&
            this.props.onExitFullscreen(event.nativeEvent);
          }
        }}
        onAdStarted={event =>
          this.props.onAdStarted &&
          this.props.onAdStarted(event.nativeEvent)
        }
        onAdCompleted={event =>
          this.props.onAdCompleted &&
          this.props.onAdCompleted(event.nativeEvent)
        }
        onAdError={event =>
          this.props.onAdError &&
          this.props.onAdError(event.nativeEvent)
        }
        onAdOpenInBrowser={event =>
          this.props.onAdOpenInBrowser &&
          this.props.onAdOpenInBrowser(event.nativeEvent)
        }
        onAdReturnFromBrowser={event =>
          this.props.onAdReturnFromBrowser &&
          this.props.onAdReturnFromBrowser(event.nativeEvent)
        }
      />
    );
  }
}

BrightcovePlayer.prototype.seekTo = Platform.select({
  ios: function(seconds) {
    NativeModules.BrightcovePlayerManager.seekTo(
      ReactNative.findNodeHandle(this),
      seconds
    );
  },
  android: function(seconds) {
    UIManager.dispatchViewManagerCommand(
      ReactNative.findNodeHandle(this._root),
      UIManager.BrightcovePlayer.Commands.seekTo,
      [seconds]
    );
  }
});

BrightcovePlayer.propTypes = {
  ...(ViewPropTypes || View.propTypes),
  policyKey: PropTypes.string,
  accountId: PropTypes.string,
  referenceId: PropTypes.string,
  videoId: PropTypes.string,
  autoPlay: PropTypes.bool,
  adRulesUrl: PropTypes.string,
  play: PropTypes.bool,
  fullscreen: PropTypes.bool,
  disableDefaultControl: PropTypes.bool,
  volume: PropTypes.number,
  onReady: PropTypes.func,
  onPlay: PropTypes.func,
  onPause: PropTypes.func,
  onEnd: PropTypes.func,
  onError: PropTypes.func,
  onProgress: PropTypes.func,
  onChangeDuration: PropTypes.func,
  onUpdateBufferProgress: PropTypes.func,
  onBufferingStarted: PropTypes.func,
  onBufferingCompleted: PropTypes.func,
  onEnterFullscreen: PropTypes.func,
  onExitFullscreen: PropTypes.func,
  onAdStarted: PropTypes.func,
  onAdCompleted: PropTypes.func,
  onAdError: PropTypes.func,
  // Warning: only supported in ios for now
  onAdOpenInBrowser: PropTypes.func,
  onAdReturnFromBrowser: PropTypes.func,
};

BrightcovePlayer.defaultProps = {};

const NativeBrightcovePlayer = requireNativeComponent(
  'BrightcovePlayer',
  BrightcovePlayer
);

module.exports = BrightcovePlayer;
