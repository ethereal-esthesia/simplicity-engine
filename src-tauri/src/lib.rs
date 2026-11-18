#[cfg(target_os = "macos")]
use block2::RcBlock;
#[cfg(target_os = "macos")]
use objc2::{rc::Retained, runtime::AnyObject, AnyThread, MainThreadMarker};
#[cfg(target_os = "macos")]
use objc2_app_kit::{
    NSAnimatablePropertyContainer, NSAnimationContext, NSAutoresizingMaskOptions, NSColor, NSImage,
    NSNormalWindowLevel, NSScreenSaverWindowLevel, NSView, NSWindow, NSWindowCollectionBehavior,
};
#[cfg(target_os = "macos")]
use objc2_foundation::{
    NSData, NSDataBase64DecodingOptions, NSNumber, NSPoint, NSProcessInfo, NSRect, NSSize, NSString,
};
#[cfg(target_os = "macos")]
use objc2_quartz_core::{
    kCAFillModeForwards, kCAFilterTrilinear, CABasicAnimation, CALayer, CAMediaTiming,
    CAMediaTimingFunction,
};
#[cfg(all(desktop, not(target_os = "macos")))]
use simplicity_core::window_geometry::{edge_deltas, interpolate_edges};
#[cfg(desktop)]
use simplicity_core::window_geometry::{
    nearest_corner, target_edges, top_right_edges, WindowCorner, WindowEdges,
};
#[cfg(target_os = "macos")]
use std::sync::mpsc;
#[cfg(desktop)]
use std::sync::Mutex;
#[cfg(all(desktop, not(target_os = "macos")))]
use std::thread;
#[cfg(desktop)]
use std::time::Duration;
#[cfg(all(desktop, not(target_os = "macos")))]
use std::time::Instant;
#[cfg(desktop)]
use std::time::{SystemTime, UNIX_EPOCH};
#[cfg(all(desktop, not(target_os = "macos")))]
use tauri::LogicalSize;
#[cfg(desktop)]
use tauri::Manager;
#[cfg(desktop)]
use tauri::{LogicalPosition, WebviewWindow};

#[cfg(desktop)]
const WINDOW_ANIMATION_DURATION: Duration = Duration::from_millis(1500);
#[cfg(all(desktop, not(target_os = "macos")))]
const FRAME_INTERVAL: Duration = Duration::from_nanos(1_000_000_000 / 60);
#[cfg(target_os = "macos")]
const WINDOW_CORNER_RADIUS: f64 = 20.0;

#[cfg(target_os = "macos")]
fn overlay_collection_behavior(
    behavior: NSWindowCollectionBehavior,
    supports_cross_app_spaces: bool,
) -> NSWindowCollectionBehavior {
    let behavior = (behavior
        & !(NSWindowCollectionBehavior::MoveToActiveSpace
            | NSWindowCollectionBehavior::FullScreenPrimary
            | NSWindowCollectionBehavior::FullScreenNone))
        | NSWindowCollectionBehavior::CanJoinAllSpaces
        | NSWindowCollectionBehavior::FullScreenAuxiliary;
    if supports_cross_app_spaces {
        (behavior & !(NSWindowCollectionBehavior::Primary | NSWindowCollectionBehavior::Auxiliary))
            | NSWindowCollectionBehavior::CanJoinAllApplications
    } else {
        behavior
    }
}

#[cfg(target_os = "macos")]
fn configure_overlay_window(
    window: &WebviewWindow,
    original_behavior: NSWindowCollectionBehavior,
    enabled: bool,
) -> Result<(), String> {
    let pointer = window.ns_window().map_err(|error| error.to_string())?;
    let ns_window = unsafe { &*pointer.cast::<NSWindow>() };
    let supports_cross_app_spaces = NSProcessInfo::processInfo()
        .operatingSystemVersion()
        .majorVersion
        >= 13;
    ns_window.setCollectionBehavior(if enabled {
        overlay_collection_behavior(original_behavior, supports_cross_app_spaces)
    } else {
        original_behavior
    });
    ns_window.setLevel(if enabled {
        NSScreenSaverWindowLevel
    } else {
        NSNormalWindowLevel
    });
    if enabled {
        ns_window.setHidesOnDeactivate(false);
    }
    Ok(())
}

#[cfg(desktop)]
struct WindowOptions {
    always_on_top: bool,
}

#[cfg(desktop)]
struct CompactMenu(tauri::menu::Menu<tauri::Wry>);

#[cfg(desktop)]
const CLOSE_MENU_ITEM: &str = "compact-close";

#[cfg(target_os = "macos")]
extern "C" {
    fn simplicity_show_recording_menu(
        window: *mut std::ffi::c_void,
        x: f64,
        y: f64,
        encoder: *const std::ffi::c_char,
    );
}

#[cfg(desktop)]
#[derive(Clone, Copy)]
struct Expansion {
    #[cfg(not(target_os = "macos"))]
    original: WindowEdges,
    target: WindowEdges,
    #[cfg(target_os = "macos")]
    original_frame: AppKitFrame,
}

#[cfg(desktop)]
#[derive(Default)]
struct WindowState(Mutex<Option<Expansion>>);

#[cfg(desktop)]
struct ShrinkDiagnostics {
    enabled: bool,
    events: Mutex<Option<Vec<(SystemTime, &'static str, i64, i64)>>>,
}

#[cfg(desktop)]
fn timestamp_ms(time: SystemTime) -> f64 {
    match time.duration_since(UNIX_EPOCH) {
        Ok(duration) => duration.as_secs_f64() * 1000.0,
        Err(error) => -error.duration().as_secs_f64() * 1000.0,
    }
}

#[cfg(target_os = "macos")]
fn round_appkit_window(window: &WebviewWindow) -> Result<(), String> {
    let pointer = window.ns_window().map_err(|error| error.to_string())?;
    let ns_window = unsafe { &*pointer.cast::<NSWindow>() };
    let view = ns_window
        .contentView()
        .ok_or_else(|| "The window has no content view to round".to_owned())?;
    view.setWantsLayer(true);
    let layer = view
        .layer()
        .ok_or_else(|| "The window content view has no backing layer".to_owned())?;
    // Keep the native surface visible when the webview redraws behind the frame.
    layer.setBackgroundColor(Some(&NSColor::whiteColor().CGColor()));
    layer.setCornerRadius(WINDOW_CORNER_RADIUS);
    layer.setMasksToBounds(true);
    Ok(())
}

#[cfg(desktop)]
fn target_edges_for_window(window: &WebviewWindow) -> Result<WindowEdges, String> {
    let monitor = window
        .current_monitor()
        .map_err(|error| error.to_string())?
        .or(window
            .primary_monitor()
            .map_err(|error| error.to_string())?)
        .ok_or_else(|| "No display monitor is available".to_owned())?;
    // Preserve fractional logical points; the OS applies any backing-pixel rounding.
    let scale_factor = window.scale_factor().map_err(|error| error.to_string())?;
    let position = monitor.position();
    let size = monitor.size();
    Ok(target_edges(
        f64::from(position.x) / scale_factor,
        f64::from(position.y) / scale_factor,
        f64::from(size.width) / scale_factor,
        f64::from(size.height) / scale_factor,
    ))
}

#[cfg(all(desktop, not(target_os = "macos")))]
fn apply_edges(window: &WebviewWindow, edges: WindowEdges) -> Result<(), String> {
    let position = LogicalPosition::new(edges.left, edges.top);
    let size = LogicalSize::new(
        (edges.right - edges.left).max(1.0),
        (edges.bottom - edges.top).max(1.0),
    );
    window
        .set_position(position)
        .map_err(|error| error.to_string())?;
    window.set_size(size).map_err(|error| error.to_string())
}

#[cfg(target_os = "macos")]
#[derive(Clone, Copy, Debug, PartialEq)]
struct AppKitFrame {
    x: f64,
    y: f64,
    width: f64,
    height: f64,
}

#[cfg(target_os = "macos")]
fn current_appkit_frame(window: &WebviewWindow) -> Result<AppKitFrame, String> {
    let (sender, receiver) = mpsc::sync_channel(1);
    let dispatch_window = window.clone();
    window
        .run_on_main_thread(move || {
            let frame = dispatch_window
                .ns_window()
                .map_err(|error| error.to_string())
                .map(|pointer| {
                    let ns_window = unsafe { &*pointer.cast::<NSWindow>() };
                    let frame = ns_window.frame();
                    AppKitFrame {
                        x: frame.origin.x,
                        y: frame.origin.y,
                        width: frame.size.width,
                        height: frame.size.height,
                    }
                });
            let _ = sender.send(frame);
        })
        .map_err(|error| error.to_string())?;
    receiver.recv().map_err(|error| error.to_string())?
}

#[cfg(target_os = "macos")]
fn set_webview_anchor(
    window: &WebviewWindow,
    anchor: Option<(WindowCorner, WindowEdges)>,
) -> Result<(), String> {
    let (sender, receiver) = mpsc::sync_channel(1);
    window
        .with_webview(move |webview| {
            let view = unsafe { &*webview.inner().cast::<NSView>() };
            // Tauri keeps the webview and its parent alive for this main-thread callback.
            let result = unsafe { view.superview() }
                .ok_or_else(|| "The webview has no parent view".to_owned())
                .map(|parent| {
                    if let Some((corner, target)) = anchor {
                        let bounds = parent.bounds();
                        let width = (target.right - target.left).max(bounds.size.width);
                        let height = (target.bottom - target.top).max(bounds.size.height);
                        let right =
                            matches!(corner, WindowCorner::TopRight | WindowCorner::BottomRight);
                        let top = matches!(corner, WindowCorner::TopLeft | WindowCorner::TopRight);
                        let y_at_min = top == parent.isFlipped();
                        let frame = NSRect {
                            origin: NSPoint {
                                x: if right {
                                    bounds.size.width - width
                                } else {
                                    0.0
                                },
                                y: if y_at_min {
                                    0.0
                                } else {
                                    bounds.size.height - height
                                },
                            },
                            size: NSSize { width, height },
                        };
                        let horizontal = if right {
                            NSAutoresizingMaskOptions::ViewMinXMargin
                        } else {
                            NSAutoresizingMaskOptions::ViewMaxXMargin
                        };
                        let vertical = if y_at_min {
                            NSAutoresizingMaskOptions::ViewMaxYMargin
                        } else {
                            NSAutoresizingMaskOptions::ViewMinYMargin
                        };
                        view.setAutoresizingMask(horizontal | vertical);
                        view.setFrame(frame);
                    } else {
                        view.setAutoresizingMask(
                            NSAutoresizingMaskOptions::ViewWidthSizable
                                | NSAutoresizingMaskOptions::ViewHeightSizable,
                        );
                        view.setFrame(parent.bounds());
                    }
                });
            let _ = sender.send(result);
        })
        .map_err(|error| error.to_string())?;
    receiver.recv().map_err(|error| error.to_string())?
}

#[cfg(target_os = "macos")]
fn scaled_bitmap_frame(start: NSSize, target: NSSize, bitmap: NSSize) -> NSRect {
    let scale = (target.width / start.width).min(target.height / start.height);
    let width = bitmap.width * scale;
    let height = bitmap.height * scale;
    NSRect {
        origin: NSPoint {
            x: (target.width - width) / 2.0,
            y: (target.height - height) / 2.0,
        },
        size: NSSize { width, height },
    }
}

#[cfg(target_os = "macos")]
fn animate_appkit_frame_with_bitmap(
    window: &WebviewWindow,
    frame: AppKitFrame,
    reduced_motion: bool,
    png: String,
    bitmap: NSSize,
) -> Result<(), String> {
    let (sender, receiver) = mpsc::sync_channel(1);
    let dispatch_window = window.clone();
    window
        .with_webview(move |webview| {
            let result = (|| {
                let view = unsafe { &*webview.inner().cast::<NSView>() };
                let parent = unsafe { view.superview() }
                    .ok_or_else(|| "The webview has no parent view".to_owned())?;
                // Tauri owns the view during this callback; retain it until animation completes.
                let retained_view =
                    unsafe { Retained::retain(view as *const NSView as *mut NSView) }
                        .ok_or_else(|| "Cannot retain the webview".to_owned())?;
                MainThreadMarker::new()
                    .ok_or_else(|| "Bitmap animation requires the main thread".to_owned())?;
                let encoded = NSString::from_str(&png);
                let data = NSData::initWithBase64EncodedString_options(
                    NSData::alloc(),
                    &encoded,
                    NSDataBase64DecodingOptions::empty(),
                )
                .ok_or_else(|| "Cannot decode diagram bitmap".to_owned())?;
                let image = NSImage::initWithData(NSImage::alloc(), &data)
                    .ok_or_else(|| "Cannot load diagram bitmap".to_owned())?;
                let cg_image = unsafe {
                    image.CGImageForProposedRect_context_hints(std::ptr::null_mut(), None, None)
                }
                .ok_or_else(|| "Cannot convert diagram bitmap to a native image".to_owned())?;
                let pointer = dispatch_window
                    .ns_window()
                    .map_err(|error| error.to_string())?;
                let ns_window = unsafe { &*pointer.cast::<NSWindow>() };
                let current_window = ns_window.frame();
                let start = parent.bounds().size;
                let target = NSSize {
                    width: start.width + frame.width - current_window.size.width,
                    height: start.height + frame.height - current_window.size.height,
                };
                if start.width <= 0.0
                    || start.height <= 0.0
                    || target.width <= 0.0
                    || target.height <= 0.0
                    || !bitmap.width.is_finite()
                    || !bitmap.height.is_finite()
                    || bitmap.width <= 0.0
                    || bitmap.height <= 0.0
                {
                    return Err("Cannot animate an empty diagram or window".to_owned());
                }
                let initial_bitmap_frame = scaled_bitmap_frame(start, start, bitmap);
                let bitmap_frame = scaled_bitmap_frame(start, target, bitmap);
                parent.setWantsLayer(true);
                let parent_layer = parent
                    .layer()
                    .ok_or_else(|| "The window has no backing layer for the diagram".to_owned())?;
                let layer = CALayer::layer();
                layer.setFrame(initial_bitmap_frame);
                // CALayer accepts a CGImage as its contents.
                unsafe {
                    let contents = &*std::ptr::from_ref(&*cg_image).cast::<AnyObject>();
                    layer.setContents(Some(contents));
                    layer.setMinificationFilter(kCAFilterTrilinear);
                }
                let window_frame = NSRect {
                    origin: NSPoint {
                        x: frame.x,
                        y: frame.y,
                    },
                    size: NSSize {
                        width: frame.width,
                        height: frame.height,
                    },
                };
                parent_layer.addSublayer(&layer);
                view.setHidden(true);
                if reduced_motion {
                    ns_window.setFrame_display(window_frame, true);
                    retained_view.setHidden(false);
                    layer.removeFromSuperlayer();
                    return Ok(false);
                }
                NSAnimationContext::beginGrouping();
                let context = NSAnimationContext::currentContext();
                context.setDuration(WINDOW_ANIMATION_DURATION.as_secs_f64());
                let timing = CAMediaTimingFunction::functionWithControlPoints(
                    1.0 / 3.0,
                    0.0,
                    2.0 / 3.0,
                    1.0,
                );
                context.setTimingFunction(Some(&timing));
                let completion_sender = sender.clone();
                let completion_layer = layer.clone();
                let completion = RcBlock::new(move || {
                    retained_view.setHidden(false);
                    completion_layer.removeFromSuperlayer();
                    let _ = completion_sender.send(Ok(()));
                });
                context.setCompletionHandler(Some(&completion));
                let position = layer.position();
                let scale = bitmap_frame.size.width / initial_bitmap_frame.size.width;
                for (key, from, to) in [
                    ("position.x", position.x, target.width / 2.0),
                    ("position.y", position.y, target.height / 2.0),
                    ("transform.scale", 1.0, scale),
                ] {
                    let key = NSString::from_str(key);
                    let animation = CABasicAnimation::animationWithKeyPath(Some(&key));
                    let from = NSNumber::numberWithDouble(from);
                    let to = NSNumber::numberWithDouble(to);
                    // These key paths all accept numeric values.
                    unsafe {
                        animation.setFromValue(Some(&from));
                        animation.setToValue(Some(&to));
                        animation.setFillMode(kCAFillModeForwards);
                    }
                    animation.setDuration(WINDOW_ANIMATION_DURATION.as_secs_f64());
                    animation.setTimingFunction(Some(&timing));
                    animation.setRemovedOnCompletion(false);
                    layer.addAnimation_forKey(&animation, Some(&key));
                }
                ns_window
                    .animator()
                    .setFrame_display_animate(window_frame, true, true);
                NSAnimationContext::endGrouping();
                Ok(true)
            })();
            match result {
                Ok(true) => {}
                Ok(false) => {
                    let _ = sender.send(Ok(()));
                }
                Err(error) => {
                    let _ = sender.send(Err(error));
                }
            }
        })
        .map_err(|error| error.to_string())?;
    receiver.recv().map_err(|error| error.to_string())?
}

#[cfg(target_os = "macos")]
fn appkit_frame_for_edges(
    start_frame: AppKitFrame,
    start_edges: WindowEdges,
    edges: WindowEdges,
) -> AppKitFrame {
    AppKitFrame {
        x: start_frame.x + edges.left - start_edges.left,
        // AppKit grows upward from the bottom edge; Tauri geometry starts at the top.
        y: start_frame.y - edges.bottom + start_edges.bottom,
        width: edges.right - edges.left,
        height: edges.bottom - edges.top,
    }
}

#[cfg(target_os = "macos")]
fn animate_appkit_frame(
    window: &WebviewWindow,
    frame: AppKitFrame,
    reduced_motion: bool,
) -> Result<(), String> {
    let (sender, receiver) = mpsc::sync_channel(1);
    let dispatch_window = window.clone();
    window
        .run_on_main_thread(move || {
            let pointer = match dispatch_window.ns_window() {
                Ok(pointer) => pointer,
                Err(error) => {
                    let _ = sender.send(Err(error.to_string()));
                    return;
                }
            };
            let ns_window = unsafe { &*pointer.cast::<NSWindow>() };
            let rect = NSRect {
                origin: NSPoint {
                    x: frame.x,
                    y: frame.y,
                },
                size: NSSize {
                    width: frame.width,
                    height: frame.height,
                },
            };
            if reduced_motion {
                ns_window.setFrame_display(rect, true);
                let _ = sender.send(Ok(()));
                return;
            }

            NSAnimationContext::beginGrouping();
            let context = NSAnimationContext::currentContext();
            context.setDuration(WINDOW_ANIMATION_DURATION.as_secs_f64());
            // These control points produce the same smoothstep easing as the core.
            let timing =
                CAMediaTimingFunction::functionWithControlPoints(1.0 / 3.0, 0.0, 2.0 / 3.0, 1.0);
            context.setTimingFunction(Some(&timing));
            let completion = RcBlock::new(move || {
                let _ = sender.send(Ok(()));
            });
            context.setCompletionHandler(Some(&completion));
            ns_window
                .animator()
                .setFrame_display_animate(rect, true, true);
            NSAnimationContext::endGrouping();
        })
        .map_err(|error| error.to_string())?;
    receiver.recv().map_err(|error| error.to_string())?
}

#[cfg(desktop)]
fn current_edges(window: &WebviewWindow) -> Result<WindowEdges, String> {
    let scale_factor = window.scale_factor().map_err(|error| error.to_string())?;
    let position = window.outer_position().map_err(|error| error.to_string())?;
    let size = window.outer_size().map_err(|error| error.to_string())?;
    Ok(WindowEdges {
        left: f64::from(position.x) / scale_factor,
        top: f64::from(position.y) / scale_factor,
        right: f64::from(position.x) / scale_factor + f64::from(size.width) / scale_factor,
        bottom: f64::from(position.y) / scale_factor + f64::from(size.height) / scale_factor,
    })
}

#[cfg(all(desktop, not(target_os = "macos")))]
fn animate_window_to(
    window: WebviewWindow,
    target: WindowEdges,
    reduced_motion: bool,
) -> Result<(), String> {
    let start = current_edges(&window)?;
    let deltas = edge_deltas(start, target);
    let duration = if reduced_motion {
        Duration::from_millis(1)
    } else {
        WINDOW_ANIMATION_DURATION
    };
    let started_at = Instant::now();
    let mut next_frame = started_at;

    loop {
        let progress = (started_at.elapsed().as_secs_f64() / duration.as_secs_f64()).min(1.0);
        let edges = interpolate_edges(start, deltas, progress);
        apply_edges(&window, edges)?;
        if progress >= 1.0 {
            return Ok(());
        }
        next_frame += FRAME_INTERVAL;
        let now = Instant::now();
        while next_frame <= now {
            next_frame += FRAME_INTERVAL;
        }
        thread::sleep(next_frame.duration_since(now));
    }
}

#[cfg(target_os = "macos")]
fn animate_window_to(
    window: WebviewWindow,
    target: WindowEdges,
    reduced_motion: bool,
) -> Result<(), String> {
    let start = current_edges(&window)?;
    let start_frame = current_appkit_frame(&window)?;
    animate_appkit_frame(
        &window,
        appkit_frame_for_edges(start_frame, start, target),
        reduced_motion,
    )
}

#[cfg(desktop)]
fn prepare_native_expansion(window: WebviewWindow) -> Result<&'static str, String> {
    let original = current_edges(&window)?;
    let target = target_edges_for_window(&window)?;
    let corner = nearest_corner(original, target);
    let expansion = Expansion {
        #[cfg(not(target_os = "macos"))]
        original,
        target,
        #[cfg(target_os = "macos")]
        original_frame: current_appkit_frame(&window)?,
    };
    let state = window.state::<WindowState>();
    let mut saved = state.0.lock().map_err(|error| error.to_string())?;
    if saved.is_some() {
        return Err("A window expansion is already active".to_owned());
    }
    #[cfg(target_os = "macos")]
    set_webview_anchor(&window, Some((corner, target)))?;
    *saved = Some(expansion);
    Ok(match corner {
        WindowCorner::TopLeft => "top-left",
        WindowCorner::TopRight => "top-right",
        WindowCorner::BottomLeft => "bottom-left",
        WindowCorner::BottomRight => "bottom-right",
    })
}

#[cfg(desktop)]
fn saved_expansion(window: &WebviewWindow) -> Result<Expansion, String> {
    window
        .state::<WindowState>()
        .0
        .lock()
        .map_err(|error| error.to_string())?
        .ok_or_else(|| "No original window position is available".to_owned())
}

#[cfg(desktop)]
fn clear_expansion(window: &WebviewWindow) -> Result<(), String> {
    *window
        .state::<WindowState>()
        .0
        .lock()
        .map_err(|error| error.to_string())? = None;
    Ok(())
}

#[cfg(desktop)]
fn animate_to_original(
    window: WebviewWindow,
    expansion: Expansion,
    reduced_motion: bool,
) -> Result<(), String> {
    #[cfg(target_os = "macos")]
    return animate_appkit_frame(&window, expansion.original_frame, reduced_motion);
    #[cfg(not(target_os = "macos"))]
    animate_window_to(window, expansion.original, reduced_motion)
}

#[cfg(desktop)]
fn expand_native_window(window: WebviewWindow, reduced_motion: bool) -> Result<(), String> {
    let expansion = saved_expansion(&window)?;
    let animation = animate_window_to(window.clone(), expansion.target, reduced_motion);
    #[cfg(target_os = "macos")]
    let restore = set_webview_anchor(&window, None);
    #[cfg(not(target_os = "macos"))]
    let restore: Result<(), String> = Ok(());

    match (animation, restore) {
        (Ok(()), Ok(())) => Ok(()),
        (animation, restore) => {
            let mut errors = Vec::new();
            if let Err(error) = animation {
                errors.push(format!("Window animation failed: {error}"));
            }
            if let Err(error) = restore {
                errors.push(format!("Webview restoration failed: {error}"));
            }
            if let Err(error) = animate_to_original(window.clone(), expansion, true) {
                errors.push(format!("Window rollback failed: {error}"));
            }
            if let Err(error) = clear_expansion(&window) {
                errors.push(format!("Expansion state cleanup failed: {error}"));
            }
            Err(errors.join("; "))
        }
    }
}

#[cfg(desktop)]
fn shrink_native_window(
    window: WebviewWindow,
    reduced_motion: bool,
    snapshot_png: Option<String>,
    bitmap_width: f64,
    bitmap_height: f64,
) -> Result<(), String> {
    let diagnostics = window.state::<ShrinkDiagnostics>();
    if diagnostics.enabled {
        *diagnostics
            .events
            .lock()
            .map_err(|error| error.to_string())? = Some(Vec::new());
    }
    let started = SystemTime::now();
    let result = (|| {
        let expansion = saved_expansion(&window)?;
        #[cfg(target_os = "macos")]
        if let Some(png) = snapshot_png {
            let animation = animate_appkit_frame_with_bitmap(
                &window,
                expansion.original_frame,
                reduced_motion,
                png,
                NSSize {
                    width: bitmap_width,
                    height: bitmap_height,
                },
            );
            animation?;
        } else {
            animate_to_original(window.clone(), expansion, reduced_motion)?;
        }
        #[cfg(not(target_os = "macos"))]
        {
            let _ = (snapshot_png, bitmap_width, bitmap_height);
            animate_to_original(window.clone(), expansion, reduced_motion)?;
        }
        clear_expansion(&window)
    })();
    if diagnostics.enabled {
        let events = diagnostics
            .events
            .lock()
            .map_err(|error| error.to_string())?
            .take();
        eprintln!(
            "[shrink-debug] native start_ms={:.3} end_ms={:.3}",
            timestamp_ms(started),
            timestamp_ms(SystemTime::now())
        );
        if let Some(events) = events {
            for (time, kind, a, b) in events {
                eprintln!(
                    "[shrink-debug] native event_ms={:.3} {kind}={a},{b}",
                    timestamp_ms(time)
                );
            }
        } else {
            eprintln!("[shrink-debug] Native event recording was not active");
        }
    }
    result
}

#[cfg(desktop)]
fn cancel_native_expansion(window: WebviewWindow) -> Result<(), String> {
    let expansion = *window
        .state::<WindowState>()
        .0
        .lock()
        .map_err(|error| error.to_string())?;
    let Some(expansion) = expansion else {
        return Ok(());
    };
    let mut errors = Vec::new();
    #[cfg(target_os = "macos")]
    if let Err(error) = set_webview_anchor(&window, None) {
        errors.push(format!("Webview restoration failed: {error}"));
    }
    if let Err(error) = animate_to_original(window.clone(), expansion, true) {
        errors.push(format!("Window rollback failed: {error}"));
    }
    if let Err(error) = clear_expansion(&window) {
        errors.push(format!("Expansion state cleanup failed: {error}"));
    }
    if errors.is_empty() {
        Ok(())
    } else {
        Err(errors.join("; "))
    }
}

#[cfg(desktop)]
#[tauri::command]
async fn prepare_window_expansion(window: WebviewWindow) -> Result<&'static str, String> {
    tauri::async_runtime::spawn_blocking(move || prepare_native_expansion(window))
        .await
        .map_err(|error| error.to_string())?
}

#[cfg(desktop)]
#[tauri::command]
async fn cancel_window_expansion(window: WebviewWindow) -> Result<(), String> {
    tauri::async_runtime::spawn_blocking(move || cancel_native_expansion(window))
        .await
        .map_err(|error| error.to_string())?
}

#[cfg(desktop)]
#[tauri::command]
async fn expand_window(window: WebviewWindow, reduced_motion: bool) -> Result<(), String> {
    tauri::async_runtime::spawn_blocking(move || expand_native_window(window, reduced_motion))
        .await
        .map_err(|error| error.to_string())?
}

#[cfg(desktop)]
#[tauri::command]
async fn shrink_window(
    window: WebviewWindow,
    reduced_motion: bool,
    snapshot_png: Option<String>,
    bitmap_width: f64,
    bitmap_height: f64,
) -> Result<(), String> {
    tauri::async_runtime::spawn_blocking(move || {
        shrink_native_window(
            window,
            reduced_motion,
            snapshot_png,
            bitmap_width,
            bitmap_height,
        )
    })
    .await
    .map_err(|error| error.to_string())?
}

#[cfg(desktop)]
#[tauri::command]
fn shrink_debug_enabled(diagnostics: tauri::State<'_, ShrinkDiagnostics>) -> bool {
    diagnostics.enabled
}

#[cfg(desktop)]
#[tauri::command]
fn native_shrink_scaling() -> bool {
    cfg!(target_os = "macos")
}

#[cfg(desktop)]
#[tauri::command]
fn report_shrink_debug(diagnostics: tauri::State<'_, ShrinkDiagnostics>, trace: String) {
    if diagnostics.enabled {
        eprintln!("[shrink-debug] web {trace}");
    }
}

#[cfg(desktop)]
#[tauri::command]
fn start_window_dragging(window: WebviewWindow) -> Result<(), String> {
    window.start_dragging().map_err(|error| error.to_string())
}

#[cfg(desktop)]
#[tauri::command]
fn show_compact_menu(
    window: WebviewWindow,
    menu: tauri::State<'_, CompactMenu>,
    x: f64,
    y: f64,
) -> Result<(), String> {
    if !x.is_finite() || !y.is_finite() {
        return Err("Invalid context menu position".to_owned());
    }
    #[cfg(target_os = "macos")]
    {
        let _ = &menu.0;
        let pointer = window.ns_window().map_err(|error| error.to_string())? as usize;
        let executable = std::env::current_exe().map_err(|error| error.to_string())?;
        let bundled = executable
            .parent()
            .and_then(std::path::Path::file_name)
            .is_some_and(|name| name == "MacOS");
        let encoder = if !bundled {
            std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
                .join("../node_modules/.cache/simplicity-recording/ffmpeg")
        } else {
            window
                .app_handle()
                .path()
                .resource_dir()
                .map_err(|error| error.to_string())?
                .join("ffmpeg")
        };
        let encoder = std::ffi::CString::new(encoder.as_os_str().as_encoded_bytes())
            .map_err(|error| format!("Invalid encoder path: {error}"))?;
        let keep_alive = window.clone();
        return window
            .run_on_main_thread(move || {
                let _ = keep_alive;
                unsafe {
                    simplicity_show_recording_menu(
                        pointer as *mut std::ffi::c_void,
                        x,
                        y,
                        encoder.as_ptr(),
                    )
                };
            })
            .map_err(|error| error.to_string());
    }
    #[cfg(not(target_os = "macos"))]
    window
        .popup_menu_at(&menu.0, LogicalPosition::new(x, y))
        .map_err(|error| error.to_string())
}

#[cfg(desktop)]
#[tauri::command]
fn load_diagram_source(file: tauri::State<'_, diagram_file::DiagramFile>) -> String {
    file.source.clone()
}

#[cfg(desktop)]
#[tauri::command]
fn save_diagram_source(
    file: tauri::State<'_, diagram_file::DiagramFile>,
    source: String,
) -> Result<(), String> {
    file.save(&source)
}

#[tauri::command]
fn is_desktop() -> bool {
    cfg!(desktop)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let builder = tauri::Builder::default();
    #[cfg(desktop)]
    let diagram = diagram_file::DiagramFile::from_process().unwrap_or_else(|error| {
        eprintln!("{error}");
        std::process::exit(2);
    });
    #[cfg(desktop)]
    let window_options = WindowOptions {
        always_on_top: true,
    };
    #[cfg(desktop)]
    let builder = builder
        .manage(diagram)
        .manage(WindowState::default())
        .manage(ShrinkDiagnostics {
            enabled: std::env::var_os("SIMPLICITY_SHRINK_DEBUG").is_some_and(|value| value == "1"),
            events: Mutex::new(None),
        })
        .setup(move |app| {
            let window = app
                .get_webview_window("main")
                .ok_or_else(|| std::io::Error::other("The main window is not configured"))?;
            let handle = app.handle().clone();
            window.on_window_event(move |event| {
                let diagnostics = handle.state::<ShrinkDiagnostics>();
                if !diagnostics.enabled {
                    return;
                }
                let sample = match event {
                    tauri::WindowEvent::Moved(position) => {
                        Some(("position_px", i64::from(position.x), i64::from(position.y)))
                    }
                    tauri::WindowEvent::Resized(size) => {
                        Some(("size_px", i64::from(size.width), i64::from(size.height)))
                    }
                    _ => None,
                };
                if let Some((kind, a, b)) = sample {
                    match diagnostics.events.lock() {
                        Ok(mut events) => {
                            if let Some(events) = events.as_mut() {
                                events.push((SystemTime::now(), kind, a, b));
                            }
                        }
                        Err(error) => {
                            eprintln!("[shrink-debug] Cannot record window event: {error}")
                        }
                    }
                }
            });
            let close =
                tauri::menu::MenuItem::with_id(app, CLOSE_MENU_ITEM, "Close", true, None::<&str>)?;
            let menu = tauri::menu::Menu::with_items(app, &[&close])?;
            app.manage(CompactMenu(menu));
            window.on_menu_event(|window, event| {
                if event.id().as_ref() == CLOSE_MENU_ITEM {
                    if let Err(error) = window.close() {
                        eprintln!("Cannot close the window: {error}");
                    }
                }
            });
            #[cfg(target_os = "macos")]
            {
                if window_options.always_on_top {
                    app.handle()
                        .set_activation_policy(tauri::ActivationPolicy::Accessory)?;
                }
                round_appkit_window(&window).map_err(std::io::Error::other)?;
                let pointer = window.ns_window()?;
                let ns_window = unsafe { &*pointer.cast::<NSWindow>() };
                let original_behavior = ns_window.collectionBehavior();
                configure_overlay_window(&window, original_behavior, window_options.always_on_top)
                    .map_err(std::io::Error::other)?;
            }
            let target = target_edges_for_window(&window).map_err(std::io::Error::other)?;
            let size = window.outer_size()?;
            let scale_factor = window.scale_factor()?;
            let icon = top_right_edges(
                target,
                f64::from(size.width) / scale_factor,
                f64::from(size.height) / scale_factor,
            );
            window.set_position(LogicalPosition::new(icon.left, icon.top))?;
            #[cfg(not(target_os = "macos"))]
            window.set_always_on_top(window_options.always_on_top)?;
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            is_desktop,
            prepare_window_expansion,
            cancel_window_expansion,
            expand_window,
            shrink_window,
            shrink_debug_enabled,
            native_shrink_scaling,
            report_shrink_debug,
            start_window_dragging,
            show_compact_menu,
            load_diagram_source,
            save_diagram_source
        ]);
    #[cfg(mobile)]
    let builder = builder.invoke_handler(tauri::generate_handler![is_desktop]);
    builder
        .run(tauri::generate_context!())
        .expect("could not run Simplicity Engine");
}

#[cfg(all(test, target_os = "macos"))]
mod tests {
    use super::*;

    #[test]
    fn scaled_bitmap_stays_centered_and_proportional_during_animation() {
        for start in [
            NSSize {
                width: 1812.0,
                height: 972.0,
            },
            NSSize {
                width: 972.0,
                height: 1812.0,
            },
        ] {
            let target = NSSize {
                width: 88.0,
                height: 88.0,
            };
            let bitmap = NSSize {
                width: start.width * 0.8,
                height: start.height * 0.9,
            };
            let begin = scaled_bitmap_frame(start, start, bitmap);
            let end = scaled_bitmap_frame(start, target, bitmap);
            for progress in [0.0, 0.25, 0.5, 0.75, 1.0] {
                let window_width = start.width + (target.width - start.width) * progress;
                let window_height = start.height + (target.height - start.height) * progress;
                let view_width = begin.size.width + (end.size.width - begin.size.width) * progress;
                let view_height =
                    begin.size.height + (end.size.height - begin.size.height) * progress;
                let x = begin.origin.x + (end.origin.x - begin.origin.x) * progress;
                let y = begin.origin.y + (end.origin.y - begin.origin.y) * progress;
                assert!((view_width / bitmap.width - view_height / bitmap.height).abs() < 1e-10);
                assert!((2.0 * x + view_width - window_width).abs() < 1e-10);
                assert!((2.0 * y + view_height - window_height).abs() < 1e-10);
            }
        }
    }

    #[test]
    fn overlay_joins_fullscreen_spaces_without_conflicting_behaviors() {
        let behavior = NSWindowCollectionBehavior::MoveToActiveSpace
            | NSWindowCollectionBehavior::FullScreenPrimary
            | NSWindowCollectionBehavior::FullScreenNone
            | NSWindowCollectionBehavior::Primary
            | NSWindowCollectionBehavior::IgnoresCycle;

        assert_eq!(
            overlay_collection_behavior(behavior, true),
            NSWindowCollectionBehavior::CanJoinAllSpaces
                | NSWindowCollectionBehavior::FullScreenAuxiliary
                | NSWindowCollectionBehavior::CanJoinAllApplications
                | NSWindowCollectionBehavior::IgnoresCycle
        );
        assert_eq!(
            overlay_collection_behavior(behavior, false),
            NSWindowCollectionBehavior::CanJoinAllSpaces
                | NSWindowCollectionBehavior::FullScreenAuxiliary
                | NSWindowCollectionBehavior::Primary
                | NSWindowCollectionBehavior::IgnoresCycle
        );
    }

    #[test]
    fn appkit_frame_updates_position_and_size_from_one_edge_rectangle() {
        let start_frame = AppKitFrame {
            x: 200.0,
            y: 500.0,
            width: 100.0,
            height: 100.0,
        };
        let start_edges = WindowEdges {
            left: 100.0,
            top: 200.0,
            right: 200.0,
            bottom: 300.0,
        };
        let edges = WindowEdges {
            left: 110.0,
            top: 150.0,
            right: 310.0,
            bottom: 350.0,
        };

        assert_eq!(
            appkit_frame_for_edges(start_frame, start_edges, edges),
            AppKitFrame {
                x: 210.0,
                y: 450.0,
                width: 200.0,
                height: 200.0,
            }
        );
    }
}
#[cfg(desktop)]
mod diagram_file;
