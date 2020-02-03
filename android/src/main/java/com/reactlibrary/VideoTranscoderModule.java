package com.reactlibrary;

import android.os.ParcelFileDescriptor;
import android.util.Log;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import net.ypresto.androidtranscoder.*;
import net.ypresto.androidtranscoder.engine.TimeLine;
import net.ypresto.androidtranscoder.format.Android16By9FormatStrategy;
import net.ypresto.androidtranscoder.format.MediaFormatStrategyPresets;

import java.io.File;


public class VideoTranscoderModule extends ReactContextBaseJavaModule {
  private static final String TAG = "VideoTranscoderModule";
  private TimeLine timeLine;
  private TimeLine.Segment segment;
  public VideoTranscoderModule(ReactApplicationContext reactContext) {
    super(reactContext);
  }
  private int logLevel = 4;
  private String logTags;
  double nextProgress;
  double nextProgressIncrement = .05;

  @Override
  public String getName() {
    return "VideoTranscoder";
  }

  @ReactMethod
  public void transcode(String inputFileName, String outputFileName, int width, int height, int fps, int videoBitrate, final Promise promise) {

    MediaTranscoder.Listener listener = new MediaTranscoder.Listener() {
      @Override
      public void onTranscodeProgress(double progress) {
        if (progress > nextProgress) {
          Log.d(TAG, "Progress Emitted " + progress);
          nextProgress = progress + nextProgressIncrement;
          getReactApplicationContext().getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter.class)
            .emit("Progress", progress);
        } else
          Log.d(TAG, "Progress Suppressed " + progress);
      }

      @Override
      public void onTranscodeCompleted() {
        promise.resolve("Finished");
      }
      @Override
      public void onTranscodeCanceled() {

        promise.resolve("Cancelled");
      }
      @Override
      public void onTranscodeFailed(Exception e) {
        promise.reject("Exception", e);
      }
    };

    try {
      ParcelFileDescriptor fin = ParcelFileDescriptor.open(new File(inputFileName), ParcelFileDescriptor.MODE_READ_ONLY);

      (MediaTranscoder.getInstance().transcodeVideo(
              fin.getFileDescriptor(), outputFileName,
              new CustomAndroidFormatStrategy(videoBitrate, fps, width, height),
              listener)
      ).get();
    } catch (Exception e) {
      promise.reject("Exception", e);
    }

  }

}
