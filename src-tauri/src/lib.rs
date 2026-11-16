#[cfg(target_os = "macos")]
use block2::RcBlock;
#[cfg(target_os = "macos")]
use objc2_app_kit::{
    NSAnimatablePropertyContainer, NSAnimationContext, NSAutoresizingMaskOptions, NSColor,
    NSNormalWindowLevel, NSScreenSaverWindowLevel, NSView, NSWindow, NSWindowCollectionBehavior,
};
#[cfg(target_os = "macos")]
use objc2_foundation::{NSPoint, NSProcessInfo, NSRect, NSSize};
#[cfg(target_os = "macos")]
use objc2_quartz_core::CAMediaTimingFunction;
#[cfg(desktop)]
use simplicity_core::window_geometry::{
    bottom_right_edges, nearest_corner, target_edges, WindowCorner, WindowEdges,
};
#[cfg(all(desktop, not(target_os = "macos")))]
use simplicity_core::window_geometry::{edge_deltas, interpolate_edges};
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
fn shrink_native_window(window: WebviewWindow, reduced_motion: bool) -> Result<(), String> {
    let expansion = saved_expansion(&window)?;
    animate_to_original(window.clone(), expansion, reduced_motion)?;
    clear_expansion(&window)
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
async fn shrink_window(window: WebviewWindow, reduced_motion: bool) -> Result<(), String> {
    tauri::async_runtime::spawn_blocking(move || shrink_native_window(window, reduced_motion))
        .await
        .map_err(|error| error.to_string())?
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
        .setup(move |app| {
            let window = app
                .get_webview_window("main")
                .ok_or_else(|| std::io::Error::other("The main window is not configured"))?;
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
            let icon = bottom_right_edges(
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
