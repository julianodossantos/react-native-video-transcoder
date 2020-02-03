import React from 'react';
import {NativeModules, NativeEventEmitter, Platform} from 'react-native'
const {VideoTranscoder, VideoTranscoderProgress} = NativeModules;

export default class Transcoder extends React.Component {
  static async transcode(inputFilePath, outputFilePath, width, height, fps, videoBitrate, progress) {
    let status;
    const doTranscode = () => {
      if (Platform.OS === 'android') return VideoTranscoder.transcode(inputFilePath, outputFilePath, width, height, fps, videoBitrate);
      return VideoTranscoder.transcode({inputFilePath, outputFilePath, width, height, fps, videoBitrate});
    };
    if (progress) {
      const transcodeProgress = new NativeEventEmitter(VideoTranscoderProgress);
      const subscription = transcodeProgress.addListener('Progress', (reminder) => {
		    progress((typeof (reminder.progress) == 'undefined' ? reminder : reminder.progress) * 1);
      });
      status = await doTranscode();
      subscription.remove();
    } else status = doTranscode();
    return status;
  }
}
