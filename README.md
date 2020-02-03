Simple native library to add transcoding capability to React Native apps. For Android and iOS.

On iOS the library uses the AVFoundation classes. On Android ypresto/android-transcoder is used which transcodes using the MediaCodec native capabilities for hardware accelerated transcoding free of ffmpeg. 

Based on:
- selsamman/react-native-transcode [https://github.com/selsamman/react-native-transcode]
- jbavari/cordova-plugin-video-editor [https://github.com/jbavari/cordova-plugin-video-editor]

# react-native-video-transcoder

## Getting started

`$ npm install react-native-video-transcoder --save`

### Mostly automatic installation

`$ react-native link react-native-video-transcoder`

## Usage
```javascript
import VideoTranscoder from 'react-native-video-transcoder';

// TODO: What to do with the module?
VideoTranscoder;
```
