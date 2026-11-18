#import "../src-tauri/src/screen_recording.m"

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 88, 88)
            styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
        ScreenRecorder *recorder = [[ScreenRecorder alloc] init];
        recorder.window = window;
        recorder.starting = YES;
        __block BOOL menuShown = NO;
        [recorder stopThen:^{ menuShown = YES; }];
        NSCAssert(recorder.stopRequested && !menuShown, @"Stop must wait for capture");
        NSCAssert(recorder.progress.superview == window.contentView, @"Spinner must be visible");
        NSCAssert([recorder.progress hitTest:NSMakePoint(1, 1)] == nil, @"Spinner must not intercept clicks");
        RecordingProgressIndicator *progress = recorder.progress;
        [recorder stopThen:^{ NSCAssert(NO, @"Do not replace a pending menu"); }];
        NSCAssert(recorder.progress == progress, @"Repeated clicks must not add another spinner");
        [recorder reset];
        NSCAssert(!recorder.progress && !progress.superview, @"Reset must remove the spinner");
        recorder.afterStop = nil;
        [recorder stopThen:^{ menuShown = YES; }];
        NSCAssert(menuShown && !recorder.progress, @"Idle menu must not show a spinner");
    }
    return 0;
}
