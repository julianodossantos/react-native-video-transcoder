package com.reactlibrary;

import android.os.ParcelFileDescriptor;
import android.util.Log;
import android.media.MediaCodecInfo;
import android.media.MediaFormat;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.modules.core.DeviceEventManagerModule;

import net.ypresto.androidtranscoder.*;
import net.ypresto.androidtranscoder.engine.TimeLine;
import net.ypresto.androidtranscoder.format.MediaFormatStrategy;
import net.ypresto.androidtranscoder.format.Android16By9FormatStrategy;
import net.ypresto.androidtranscoder.format.MediaFormatStrategyPresets;
import net.ypresto.androidtranscoder.format.OutputFormatUnavailableException;

import java.io.File;


/**
 * Created by ehmm on 02.05.2016.
 *
 *
 */
class CustomAndroidFormatStrategy implements MediaFormatStrategy {

    private static final String TAG = "CustomFormatStrategy";
    private static final int DEFAULT_BITRATE = 8000000;
    private static final int DEFAULT_FRAMERATE = 30;
    private static final int DEFAULT_WIDTH = 0;
    private static final int DEFAULT_HEIGHT = 0;
    private final int mBitRate;
    private final int mFrameRate;
    private final int width;
    private final int height;

    public CustomAndroidFormatStrategy() {
        this.mBitRate = DEFAULT_BITRATE;
        this.mFrameRate = DEFAULT_FRAMERATE;
        this.width = DEFAULT_WIDTH;
        this.height = DEFAULT_HEIGHT;
    }

    public CustomAndroidFormatStrategy(final int bitRate, final int frameRate, final int width, final int height) {
        this.mBitRate = bitRate;
        this.mFrameRate = frameRate;
        this.width = width;
        this.height = height;
    }

    @Override
    public MediaFormat createVideoOutputFormat(MediaFormat inputFormat, boolean allowPassthru) {
        int inWidth = inputFormat.getInteger(MediaFormat.KEY_WIDTH);
        int inHeight = inputFormat.getInteger(MediaFormat.KEY_HEIGHT);
        int inLonger, inShorter, outWidth, outHeight, outLonger;
        double aspectRatio;

        if (this.width >= this.height) {
            outLonger = this.width;
        } else {
            outLonger = this.height;
        }

        if (inWidth >= inHeight) {
            inLonger = inWidth;
            inShorter = inHeight;

        } else {
            inLonger = inHeight;
            inShorter = inWidth;

        }

        if (inLonger > outLonger && outLonger > 0) {
            if (inWidth >= inHeight) {
                aspectRatio = (double) inLonger / (double) inShorter;
                outWidth = outLonger;
                outHeight = Double.valueOf(outWidth / aspectRatio).intValue();

            } else {
                aspectRatio = (double) inLonger / (double) inShorter;
                outHeight = outLonger;
                outWidth = Double.valueOf(outHeight / aspectRatio).intValue();
            }
        } else {
            outWidth = inWidth;
            outHeight = inHeight;
        }

        MediaFormat format = MediaFormat.createVideoFormat("video/avc", outWidth, outHeight);
        format.setInteger(MediaFormat.KEY_BIT_RATE, mBitRate);
        format.setInteger(MediaFormat.KEY_FRAME_RATE, mFrameRate);
        format.setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 3);
        format.setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface);

        return format;

    }

    @Override
    public MediaFormat createAudioOutputFormat(MediaFormat inputFormat, boolean allowPassthru) {
        return null;
    }

}

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
