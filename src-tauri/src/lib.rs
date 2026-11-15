#[cfg(target_os = "macos")]
use objc2_app_kit::NSWindow;
#[cfg(target_os = "macos")]
use objc2_foundation::{NSPoint, NSRect, NSSize};
#[cfg(desktop)]
use simplicity_core::window_geometry::{
    bottom_right_edges, edge_deltas, interpolate_edges, target_edges, WindowEdges,
};
#[cfg(target_os = "macos")]
use std::sync::mpsc;
#[cfg(desktop)]
use std::thread;
#[cfg(desktop)]
use std::time::{Duration, Instant};
#[cfg(all(desktop, not(target_os = "macos")))]
use tauri::LogicalSize;
#[cfg(desktop)]
use tauri::Manager;
#[cfg(desktop)]
use tauri::{LogicalPosition, WebviewWindow};

#[cfg(desktop)]
const WINDOW_ANIMATION_DURATION: Duration = Duration::from_millis(1500);
#[cfg(desktop)]
const FRAME_INTERVAL: Duration = Duration::from_nanos(1_000_000_000 / 60);
#[cfg(desktop)]
const ICON_WINDOW_SIZE: f64 = 88.0;

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
fn set_appkit_frame(window: &WebviewWindow, frame: AppKitFrame) -> Result<(), String> {
    let (sender, receiver) = mpsc::sync_channel(1);
    let dispatch_window = window.clone();
    window
        .run_on_main_thread(move || {
            let result = dispatch_window
                .ns_window()
                .map_err(|error| error.to_string())
                .map(|pointer| {
                    let ns_window = unsafe { &*pointer.cast::<NSWindow>() };
                    ns_window.setFrame_display(
                        NSRect {
                            origin: NSPoint {
                                x: frame.x,
                                y: frame.y,
                            },
                            size: NSSize {
                                width: frame.width,
                                height: frame.height,
                            },
                        },
                        true,
                    );
                });
            let _ = sender.send(result);
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

#[cfg(desktop)]
fn animate_window_to(
    window: WebviewWindow,
    target: WindowEdges,
    reduced_motion: bool,
) -> Result<(), String> {
    let start = current_edges(&window)?;
    #[cfg(target_os = "macos")]
    let start_frame = current_appkit_frame(&window)?;
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
        #[cfg(target_os = "macos")]
        set_appkit_frame(&window, appkit_frame_for_edges(start_frame, start, edges))?;
        #[cfg(not(target_os = "macos"))]
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

#[cfg(desktop)]
fn expand_native_window(window: WebviewWindow, reduced_motion: bool) -> Result<(), String> {
    let target = target_edges_for_window(&window)?;
    animate_window_to(window, target, reduced_motion)
}

#[cfg(desktop)]
fn shrink_native_window(window: WebviewWindow, reduced_motion: bool) -> Result<(), String> {
    let monitor_edges = target_edges_for_window(&window)?;
    let target = bottom_right_edges(monitor_edges, ICON_WINDOW_SIZE, ICON_WINDOW_SIZE);
    animate_window_to(window, target, reduced_motion)
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

#[tauri::command]
fn is_desktop() -> bool {
    cfg!(desktop)
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let builder = tauri::Builder::default();
    #[cfg(desktop)]
    let builder = builder
        .setup(|app| {
            let window = app
                .get_webview_window("main")
                .ok_or_else(|| std::io::Error::other("The main window is not configured"))?;
            let target = target_edges_for_window(&window).map_err(std::io::Error::other)?;
            let size = window.outer_size()?;
            let scale_factor = window.scale_factor()?;
            let icon = bottom_right_edges(
                target,
                f64::from(size.width) / scale_factor,
                f64::from(size.height) / scale_factor,
            );
            window.set_position(LogicalPosition::new(icon.left, icon.top))?;
            window.set_always_on_top(true)?;
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            is_desktop,
            expand_window,
            shrink_window,
            start_window_dragging
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
