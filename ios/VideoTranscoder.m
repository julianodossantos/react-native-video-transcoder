#import "VideoTranscoder.h"
#import "SDAVAssetExportSession.h"

static inline CGFloat RadiansToDegrees(CGFloat radians) {
    return radians * 180 / M_PI;
};
static inline NSMutableDictionary * findSegment(NSArray * segments, CMPersistentTrackID trackID) {
    for (int i = 0; i < segments.count; ++i)
        if ([[segments[i] valueForKey: @"trackID"] integerValue] == trackID)
            return segments[i];
    return nil;
}

static VideoTranscoderProgress * progress;

@implementation VideoTranscoderProgress

RCT_EXPORT_MODULE();

- (void)startObserving {
    progress = self;
}

- (void)stopObserving {
    progress = nil;
}


- (NSArray<NSString *> *)supportedEvents
{
    return @[@"Progress"];
}


- (void)sendNotification:(NSNumber *) progress
{
    [self sendEventWithName:@"Progress" body:@{@"progress":progress}];
}

@end


@implementation VideoTranscoder

NSMutableDictionary *files;
NSMutableArray *segments;
NSMutableDictionary *currentSegment;
SDAVAssetExportSession *assetExportSession;
NSTimer *exportProgressBarTimer;
NSInteger NO_DURATION = 999999999;

RCT_EXPORT_MODULE()

// (String inputFileName, String outputFileName, int width, int height, int fps, int videoBitrate, final Promise promise) {
RCT_EXPORT_METHOD(transcode:(NSDictionary*)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if ([options isKindOfClass:[NSNull class]]) {
        options = [NSDictionary dictionary];
    }

    NSString *inputFilePath = [options objectForKey:@"inputFilePath"];
    NSURL *inputFileURL = [self getURLFromFilePath:inputFilePath];
    NSString *outputFilePath = [options objectForKey:@"outputFilePath"];
    NSURL *outputURL = [NSURL fileURLWithPath:outputFilePath];
    BOOL optimizeForNetworkUse = ([options objectForKey:@"optimizeForNetworkUse"]) ? [[options objectForKey:@"optimizeForNetworkUse"] intValue] : YES;
    BOOL maintainAspectRatio = [options objectForKey:@"maintainAspectRatio"] ? [[options objectForKey:@"maintainAspectRatio"] boolValue] : YES;
    float width = [[options objectForKey:@"width"] floatValue];
    float height = [[options objectForKey:@"height"] floatValue];
    int videoBitrate = ([options objectForKey:@"videoBitrate"]) ? [[options objectForKey:@"videoBitrate"] intValue] : 1000000; // default to 1 megabit
    int audioChannels = ([options objectForKey:@"audioChannels"]) ? [[options objectForKey:@"audioChannels"] intValue] : 2;
    int audioSampleRate = ([options objectForKey:@"audioSampleRate"]) ? [[options objectForKey:@"audioSampleRate"] intValue] : 44100;
    int audioBitrate = ([options objectForKey:@"audioBitrate"]) ? [[options objectForKey:@"audioBitrate"] intValue] : 128000; // default to 128 kilobits
    NSString *stringOutputFileType = AVFileTypeMPEG4;
    NSString *outputExtension = @".mp4";


    AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:inputFileURL options:nil];
    NSArray *tracks = [avAsset tracksWithMediaType:AVMediaTypeVideo];
    AVAssetTrack *track = [tracks objectAtIndex:0];
    CGSize mediaSize = track.naturalSize;
    float videoWidth = mediaSize.width;
    float videoHeight = mediaSize.height;
    int newWidth;
    int newHeight;

    if (maintainAspectRatio) {
        float aspectRatio = videoWidth / videoHeight;

        // for some portrait videos ios gives the wrong width and height, this fixes that
        NSString *videoOrientation = [self getOrientationForTrack:avAsset];
        if ([videoOrientation isEqual: @"portrait"]) {
            if (videoWidth > videoHeight) {
                videoWidth = mediaSize.height;
                videoHeight = mediaSize.width;
                aspectRatio = videoWidth / videoHeight;
            }
        }

        newWidth = (width && height) ? height * aspectRatio : videoWidth;
        newHeight = (width && height) ? newWidth / aspectRatio : videoHeight;
    } else {
        newWidth = (width && height) ? width : videoWidth;
        newHeight = (width && height) ? height : videoHeight;
    }

    NSLog(@"input videoWidth: %f", videoWidth);
    NSLog(@"input videoHeight: %f", videoHeight);
    NSLog(@"output newWidth: %d", newWidth);
    NSLog(@"output newHeight: %d", newHeight);

    assetExportSession = [SDAVAssetExportSession.alloc initWithAsset:avAsset];
    assetExportSession.outputFileType = stringOutputFileType;
    assetExportSession.outputURL = outputURL;
    assetExportSession.shouldOptimizeForNetworkUse = optimizeForNetworkUse;
    assetExportSession.videoSettings = @
    {
        AVVideoCodecKey: AVVideoCodecH264,
        AVVideoWidthKey: [NSNumber numberWithInt: newWidth],
        AVVideoHeightKey: [NSNumber numberWithInt: newHeight],
        AVVideoCompressionPropertiesKey: @
        {
            AVVideoAverageBitRateKey: [NSNumber numberWithInt: videoBitrate],
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
        }
    };
    assetExportSession.audioSettings = @
    {
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVNumberOfChannelsKey: [NSNumber numberWithInt: audioChannels],
        AVSampleRateKey: [NSNumber numberWithInt: audioSampleRate],
        AVEncoderBitRateKey: [NSNumber numberWithInt: audioBitrate]
    };

    dispatch_async(dispatch_get_main_queue(), ^{
        exportProgressBarTimer = [NSTimer scheduledTimerWithTimeInterval:.1 target:self selector:@selector(updateExportDisplay) userInfo:nil repeats:YES];
    });
    
    
    // Start encoding
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [assetExportSession exportAsynchronouslyWithCompletionHandler:^
         {
             if (assetExportSession.status == AVAssetExportSessionStatusCompleted)
             {
                 [exportProgressBarTimer invalidate];
                 NSLog(@"Video export succeeded ");
                 NSLog(@"Finished! Created %@", outputFilePath);
                 resolve(@"Finished");
             }
             else if (assetExportSession.status == AVAssetExportSessionStatusCancelled)
             {
                 [exportProgressBarTimer invalidate];
                 NSLog(@"Video export cancelled");
                 reject(@"cancel", @"Cancelled", assetExportSession.error);
                 
             }
             else
             {
                 [exportProgressBarTimer invalidate];
                 NSLog(@"Video export failed with error: %@: %ld", assetExportSession.error.localizedDescription, (long)assetExportSession.error.code);;
                 reject(@"failed", @"Failed", assetExportSession.error);
             }
         }];
    });
}

// inspired by http://stackoverflow.com/a/6046421/1673842
- (NSString*)getOrientationForTrack:(AVAsset *)asset
{
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    CGSize size = [videoTrack naturalSize];
    CGAffineTransform txf = [videoTrack preferredTransform];

    if (size.width == txf.tx && size.height == txf.ty)
        return @"landscape";
    else if (txf.tx == 0 && txf.ty == 0)
        return @"landscape";
    else if (txf.tx == 0 && txf.ty == size.width)
        return @"portrait";
    else
        return @"portrait";
}


- (void)updateExportDisplay {
    if (progress != nil)
        [progress sendNotification:@(assetExportSession.progress)];
    
}

- (NSURL*)getURLFromFilePath:(NSString*)filePath
{
    if ([filePath containsString:@"assets-library://"]) {
        return [NSURL URLWithString:[filePath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    } else if ([filePath containsString:@"file://"]) {
        return [NSURL URLWithString:[filePath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    }
    
    return [NSURL fileURLWithPath:[filePath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
}

@end
