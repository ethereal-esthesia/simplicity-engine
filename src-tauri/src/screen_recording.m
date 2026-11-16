#import <AppKit/AppKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreMedia/CoreMedia.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>

static NSString *const RecordingFolderKey = @"ScreenRecordingFolder";
static NSString *const RecordingFrameRateKey = @"ScreenRecordingFrameRate";

static NSInteger recordingFrameRate(void) {
    id saved = [[NSUserDefaults standardUserDefaults] objectForKey:RecordingFrameRateKey];
    if (!saved) return 60;
    if (![saved isKindOfClass:[NSNumber class]]) return 0;
    NSInteger rate = [saved integerValue];
    return (rate == 24 || rate == 30 || rate == 60) && [saved doubleValue] == rate ? rate : 0;
}

static NSString *recordingError(NSError *error) {
    if (!error) return @"Unknown recording error.";
    NSMutableString *message = [NSMutableString stringWithFormat:@"%@ (%@ %ld)",
        error.localizedDescription, error.domain, (long)error.code];
    NSError *underlying = error.userInfo[NSUnderlyingErrorKey];
    if (underlying) [message appendFormat:@"\n%@", recordingError(underlying)];
    return message;
}

API_AVAILABLE(macos(15.0))
@interface RecordingWriter : NSObject <SCStreamOutput>
@property(nonatomic, strong) AVAssetWriter *writer;
@property(nonatomic, strong) AVAssetWriterInput *video;
@property(nonatomic, strong) AVAssetWriterInput *audio;
@property(nonatomic, strong) dispatch_queue_t queue;
@property(nonatomic, strong) NSURL *temporaryURL;
@property(nonatomic, strong) NSURL *destinationURL;
@property(nonatomic, copy) NSString *encoderPath;
@property(nonatomic, copy) void (^onError)(NSString *);
@property(nonatomic) BOOL sessionStarted;
@property(nonatomic) BOOL failed;
- (instancetype)initWithURL:(NSURL *)url encoder:(NSString *)encoder
                 frameRate:(NSInteger)frameRate error:(NSError **)error;
- (void)finish:(void (^)(NSString *))completion;
- (void)cancel;
@end

API_AVAILABLE(macos(15.0))
@implementation RecordingWriter

- (instancetype)initWithURL:(NSURL *)url encoder:(NSString *)encoder
                 frameRate:(NSInteger)frameRate error:(NSError **)error {
    self = [super init];
    if (!self) return nil;
    _destinationURL = url;
    _encoderPath = encoder;
    _temporaryURL = [[url URLByDeletingLastPathComponent] URLByAppendingPathComponent:
        [NSString stringWithFormat:@".screen-recording-%@.mov", NSUUID.UUID.UUIDString]];
    _queue = dispatch_queue_create("dev.simplicityengine.recording", DISPATCH_QUEUE_SERIAL);
    _writer = [[AVAssetWriter alloc] initWithURL:_temporaryURL fileType:AVFileTypeQuickTimeMovie error:error];
    if (!_writer) return nil;
    NSDictionary *videoSettings = @{
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoWidthKey: @1920,
        AVVideoHeightKey: @1080,
        AVVideoCompressionPropertiesKey: @{
            AVVideoAverageBitRateKey: @12000000,
            AVVideoExpectedSourceFrameRateKey: @(frameRate),
            AVVideoMaxKeyFrameIntervalKey: @(frameRate / 2),
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
        },
    };
    NSDictionary *audioSettings = @{
        AVFormatIDKey: @(kAudioFormatAppleLossless),
        AVSampleRateKey: @48000,
        AVNumberOfChannelsKey: @2,
        AVEncoderBitDepthHintKey: @24,
    };
    _video = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    _audio = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioSettings];
    _video.expectsMediaDataInRealTime = YES;
    _audio.expectsMediaDataInRealTime = YES;
    if (![_writer canAddInput:_video] || ![_writer canAddInput:_audio]) {
        if (error) *error = [NSError errorWithDomain:@"SimplicityRecording" code:1
            userInfo:@{NSLocalizedDescriptionKey: @"Cannot configure the video and audio encoder."}];
        return nil;
    }
    [_writer addInput:_video];
    [_writer addInput:_audio];
    if (![_writer startWriting]) {
        if (error) *error = _writer.error;
        return nil;
    }
    return self;
}

- (void)stream:(SCStream *)stream didOutputSampleBuffer:(CMSampleBufferRef)sample
        ofType:(SCStreamOutputType)type {
    if (self.failed || !CMSampleBufferDataIsReady(sample)) return;
    if (type == SCStreamOutputTypeScreen && !CMSampleBufferGetImageBuffer(sample)) return;
    AVAssetWriterInput *input = type == SCStreamOutputTypeScreen ? self.video :
        type == SCStreamOutputTypeAudio ? self.audio : nil;
    if (!input) return;
    CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sample);
    if (!CMTIME_IS_VALID(timestamp)) return;
    if (!self.sessionStarted) {
        [self.writer startSessionAtSourceTime:timestamp];
        self.sessionStarted = YES;
    }
    if (!input.readyForMoreMediaData || ![input appendSampleBuffer:sample]) {
        self.failed = YES;
        NSString *message = self.writer.error ?
            recordingError(self.writer.error) :
            @"The encoder could not keep up with the screen or audio stream.";
        self.onError(message);
    }
}

- (void)finish:(void (^)(NSString *))completion {
    dispatch_async(self.queue, ^{
        if (self.failed || !self.sessionStarted) {
            [self.writer cancelWriting];
            completion(@"The recording did not receive any screen or audio data.");
            return;
        }
        [self.video markAsFinished];
        [self.audio markAsFinished];
        self.failed = YES;
        [self.writer finishWritingWithCompletionHandler:^{
            if (self.writer.status != AVAssetWriterStatusCompleted) {
                completion(recordingError(self.writer.error));
                return;
            }
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                NSTask *task = [[NSTask alloc] init];
                task.executableURL = [NSURL fileURLWithPath:self.encoderPath];
                task.arguments = @[@"-v", @"error", @"-n", @"-i", self.temporaryURL.path,
                    @"-map", @"0:v:0", @"-map", @"0:a:0", @"-c:v", @"copy",
                    @"-c:a", @"aac", @"-b:a", @"384k", @"-movflags", @"+faststart",
                    self.destinationURL.path];
                NSPipe *errors = [NSPipe pipe];
                task.standardError = errors;
                NSError *launchError = nil;
                if (![task launchAndReturnError:&launchError]) {
                    completion([NSString stringWithFormat:@"Cannot start the audio encoder: %@\nThe original recording remains at %@",
                        recordingError(launchError), self.temporaryURL.path]);
                    return;
                }
                NSData *errorData = [errors.fileHandleForReading readDataToEndOfFile];
                [task waitUntilExit];
                if (task.terminationStatus != 0) {
                    NSString *details = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
                    completion([NSString stringWithFormat:@"Cannot encode the recording: %@\nThe original recording remains at %@",
                        details ?: @"Unknown encoder error.", self.temporaryURL.path]);
                    return;
                }
                NSError *removeError = nil;
                if (![[NSFileManager defaultManager] removeItemAtURL:self.temporaryURL error:&removeError]) {
                    completion([NSString stringWithFormat:@"Recording saved, but its temporary file could not be removed: %@",
                        recordingError(removeError)]);
                    return;
                }
                completion(nil);
            });
        }];
    });
}

- (void)cancel {
    dispatch_async(self.queue, ^{
        self.failed = YES;
        if (self.writer.status == AVAssetWriterStatusWriting ||
            self.writer.status == AVAssetWriterStatusUnknown) {
            [self.writer cancelWriting];
        }
    });
}
@end

@interface RecordingSettings : NSObject
@property(nonatomic, copy) NSString *folder;
@property(nonatomic, strong) NSTextField *folderLabel;
- (void)chooseFolder:(id)sender;
@end

@implementation RecordingSettings
- (void)chooseFolder:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.message = @"Choose where screen recordings will be saved.";
    panel.canChooseDirectories = YES;
    panel.canChooseFiles = NO;
    panel.canCreateDirectories = YES;
    panel.allowsMultipleSelection = NO;
    if (self.folder) panel.directoryURL = [NSURL fileURLWithPath:self.folder isDirectory:YES];
    if ([panel runModal] == NSModalResponseOK) {
        self.folder = panel.URL.path;
        self.folderLabel.stringValue = self.folder;
        self.folderLabel.toolTip = self.folder;
    }
}
@end

API_AVAILABLE(macos(15.0))
@interface ScreenRecorder : NSObject <SCStreamDelegate>
@property(nonatomic, strong) SCStream *stream;
@property(nonatomic, strong) RecordingWriter *output;
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, copy) NSString *encoderPath;
@property(nonatomic, copy) void (^afterStop)(void);
@property(nonatomic) BOOL starting;
@property(nonatomic) BOOL stopping;
@property(nonatomic) BOOL stopRequested;
@end

API_AVAILABLE(macos(15.0))
@implementation ScreenRecorder

- (void)showError:(NSString *)message {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Screen recording";
    alert.informativeText = message;
    [alert runModal];
}

- (void)settings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger frameRate = recordingFrameRate();
    if (!frameRate) {
        [self showError:@"The saved recording frame rate is invalid. Choose a frame rate in Settings."];
        frameRate = 60;
    }
    RecordingSettings *settings = [[RecordingSettings alloc] init];
    settings.folder = [defaults stringForKey:RecordingFolderKey];

    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 380, 100)];
    NSTextField *folderTitle = [NSTextField labelWithString:@"Recording folder:"];
    folderTitle.frame = NSMakeRect(0, 78, 380, 20);
    [view addSubview:folderTitle];
    settings.folderLabel = [NSTextField labelWithString:settings.folder ?: @"No folder selected"];
    settings.folderLabel.frame = NSMakeRect(0, 51, 280, 20);
    settings.folderLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    settings.folderLabel.toolTip = settings.folder;
    [view addSubview:settings.folderLabel];
    NSButton *choose = [NSButton buttonWithTitle:@"Choose…" target:settings action:@selector(chooseFolder:)];
    choose.frame = NSMakeRect(285, 47, 95, 28);
    [view addSubview:choose];
    NSTextField *frameRateLabel = [NSTextField labelWithString:@"Maximum frame rate:"];
    frameRateLabel.frame = NSMakeRect(0, 9, 150, 20);
    [view addSubview:frameRateLabel];
    NSPopUpButton *frameRates = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(155, 4, 115, 26)];
    for (NSNumber *rate in @[@24, @30, @60]) {
        [frameRates addItemWithTitle:[NSString stringWithFormat:@"%@ fps", rate]];
        frameRates.lastItem.tag = rate.integerValue;
    }
    [frameRates selectItemWithTag:frameRate];
    [view addSubview:frameRates];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Recording Settings";
    alert.accessoryView = view;
    [alert addButtonWithTitle:@"Save"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        if (settings.folder) [defaults setObject:settings.folder forKey:RecordingFolderKey];
        [defaults setInteger:frameRates.selectedItem.tag forKey:RecordingFrameRateKey];
    }
}

- (void)reset {
    self.stream = nil;
    self.output = nil;
    self.starting = NO;
    self.stopping = NO;
    self.stopRequested = NO;
}

- (void)fail:(NSString *)message {
    SCStream *stream = self.stream;
    RecordingWriter *output = self.output;
    [self reset];
    self.afterStop = nil;
    [output cancel];
    if (stream) {
        [stream stopCaptureWithCompletionHandler:^(NSError *error) {
            if (error) NSLog(@"Cannot stop failed screen capture: %@", error.localizedDescription);
        }];
    }
    [self showError:message];
}

- (void)start:(NSWindow *)window {
    if (self.starting || self.stream) {
        [self showError:@"A screen recording is already in progress."];
        return;
    }
    NSString *folder = [[NSUserDefaults standardUserDefaults] stringForKey:RecordingFolderKey];
    if (!folder) {
        [self showError:@"Choose a recording folder in Settings before recording."];
        return;
    }
    NSInteger frameRate = recordingFrameRate();
    if (!frameRate) {
        [self showError:@"The saved recording frame rate is invalid. Choose a frame rate in Settings."];
        return;
    }
    BOOL directory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:folder isDirectory:&directory] ||
        !directory || ![[NSFileManager defaultManager] isWritableFileAtPath:folder]) {
        [self showError:@"The recording folder is unavailable or not writable. Choose another folder in Settings."];
        return;
    }
    if (![[NSFileManager defaultManager] isExecutableFileAtPath:self.encoderPath]) {
        [self showError:@"The bundled recording encoder is missing or not executable. Rebuild or reinstall the app."];
        return;
    }
    if (!CGPreflightScreenCaptureAccess()) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Screen recording permission";
        alert.informativeText = @"Allow screen and system audio recording in macOS settings to start recording.";
        [alert addButtonWithTitle:@"Continue"];
        [alert addButtonWithTitle:@"Cancel"];
        if ([alert runModal] != NSAlertFirstButtonReturn) return;
        if (!CGRequestScreenCaptureAccess()) {
            [self showError:@"Screen recording permission was not granted. Enable it in System Settings and restart the app if required."];
            return;
        }
    }
    NSScreen *screen = window.screen;
    NSNumber *screenNumber = screen.deviceDescription[@"NSScreenNumber"];
    if (!screenNumber) {
        [self showError:@"Cannot determine the display containing the window."];
        return;
    }
    self.starting = YES;
    self.window = window;
    [SCShareableContent getShareableContentExcludingDesktopWindows:NO
                                              onScreenWindowsOnly:NO
                                                completionHandler:^(SCShareableContent *content, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !content) {
                [self fail:error.localizedDescription ?: @"Cannot access displays for screen recording."];
                return;
            }
            SCDisplay *display = nil;
            for (SCDisplay *candidate in content.displays) {
                if (candidate.displayID == screenNumber.unsignedIntValue) {
                    display = candidate;
                    break;
                }
            }
            if (!display) {
                [self fail:@"The window's display is no longer available for recording."];
                return;
            }
            NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
            formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
            formatter.dateFormat = @"yyyy-MM-dd_HH-mm-ss";
            NSString *base = [@"screen-recording-" stringByAppendingString:[formatter stringFromDate:[NSDate date]]];
            NSString *path = [folder stringByAppendingPathComponent:[base stringByAppendingString:@".mp4"]];
            for (NSUInteger suffix = 1; [[NSFileManager defaultManager] fileExistsAtPath:path]; suffix++) {
                path = [folder stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%lu.mp4", base, (unsigned long)suffix]];
            }
            SCStreamConfiguration *configuration = [[SCStreamConfiguration alloc] init];
            configuration.width = 1920;
            configuration.height = 1080;
            configuration.preservesAspectRatio = YES;
            configuration.minimumFrameInterval = CMTimeMake(1, (int32_t)frameRate);
            configuration.capturesAudio = YES;
            configuration.sampleRate = 48000;
            configuration.channelCount = 2;
            SCContentFilter *filter = [[SCContentFilter alloc] initWithDisplay:display excludingWindows:@[]];
            self.stream = [[SCStream alloc] initWithFilter:filter configuration:configuration delegate:self];
            NSError *outputError = nil;
            self.output = [[RecordingWriter alloc] initWithURL:[NSURL fileURLWithPath:path]
                encoder:self.encoderPath frameRate:frameRate error:&outputError];
            if (!self.output) {
                [self fail:outputError ? recordingError(outputError) : @"Cannot configure the recording output."];
                return;
            }
            __weak ScreenRecorder *weakSelf = self;
            RecordingWriter *output = self.output;
            __weak RecordingWriter *weakOutput = output;
            output.onError = ^(NSString *message) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    ScreenRecorder *recorder = weakSelf;
                    RecordingWriter *current = weakOutput;
                    if (recorder && current && recorder.output == current) [recorder fail:message];
                });
            };
            if (![self.stream addStreamOutput:output type:SCStreamOutputTypeScreen
                          sampleHandlerQueue:output.queue error:&outputError] ||
                ![self.stream addStreamOutput:output type:SCStreamOutputTypeAudio
                          sampleHandlerQueue:output.queue error:&outputError]) {
                [self fail:outputError.localizedDescription ?: @"Cannot configure screen and audio capture."];
                return;
            }
            SCStream *stream = self.stream;
            [stream startCaptureWithCompletionHandler:^(NSError *startError) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (self.stream == stream) {
                        if (startError) {
                            [self fail:startError.localizedDescription];
                        } else {
                            self.starting = NO;
                            if (self.stopRequested) [self stopCapture];
                        }
                    } else if (!startError) {
                        [stream stopCaptureWithCompletionHandler:^(NSError *error) {
                            if (error) NSLog(@"Cannot stop abandoned screen capture: %@", error.localizedDescription);
                        }];
                    }
                });
            }];
        });
    }];
}

- (void)stopThen:(void (^)(void))action {
    if (!self.starting && !self.stream) {
        action();
        return;
    }
    if (self.afterStop) return;
    self.afterStop = action;
    self.stopRequested = YES;
    if (self.starting || self.stopping) return;
    [self stopCapture];
}

- (void)stopCapture {
    self.stopping = YES;
    SCStream *stream = self.stream;
    RecordingWriter *output = self.output;
    [stream stopCaptureWithCompletionHandler:^(NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.stream == stream) [self fail:error.localizedDescription];
            });
            return;
        }
        [output finish:^(NSString *finishError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.stream != stream) return;
                if (finishError) {
                    [self fail:finishError];
                } else {
                    void (^action)(void) = self.afterStop;
                    self.afterStop = nil;
                    [self reset];
                    if (action) action();
                }
            });
        }];
    }];
}

- (void)stream:(SCStream *)stream didStopWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.stream == stream) [self fail:error.localizedDescription];
    });
}
@end

static ScreenRecorder *recorder API_AVAILABLE(macos(15.0));

@interface CompactMenuTarget : NSObject
@property(nonatomic) NSInteger selection;
- (void)select:(NSMenuItem *)item;
@end

@implementation CompactMenuTarget
- (void)select:(NSMenuItem *)item { self.selection = item.tag; }
@end

static void showMenu(NSWindow *window, double x, double y) {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
    CompactMenuTarget *target = [[CompactMenuTarget alloc] init];
    NSArray<NSString *> *titles = @[@"Record Screen", @"Settings", @"Close"];
    for (NSUInteger i = 0; i < titles.count; i++) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:titles[i] action:@selector(select:) keyEquivalent:@""];
        item.target = target;
        item.tag = (NSInteger)i + 1;
        [menu addItem:item];
    }
    NSView *view = window.contentView;
    [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(x, view.frame.size.height - y) inView:view];
    if (target.selection == 3) {
        [window close];
    } else if (@available(macOS 15.0, *)) {
        if (target.selection == 1) [recorder start:window];
        if (target.selection == 2) [recorder settings];
    } else if (target.selection) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"Screen recording requires macOS 15 or later.";
        [alert runModal];
    }
}

void simplicity_show_recording_menu(void *windowPointer, double x, double y, const char *encoderPath) {
    NSWindow *window = (__bridge NSWindow *)windowPointer;
    if (@available(macOS 15.0, *)) {
        if (!recorder) recorder = [[ScreenRecorder alloc] init];
        recorder.encoderPath = [NSString stringWithUTF8String:encoderPath];
        [recorder stopThen:^{ showMenu(window, x, y); }];
    } else {
        showMenu(window, x, y);
    }
}
