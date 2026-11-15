#[cfg(desktop)]
use simplicity_core::window_geometry::{edge_deltas, interpolate_edges, target_edges, WindowEdges};
#[cfg(desktop)]
use std::thread;
#[cfg(desktop)]
use std::time::{Duration, Instant};
#[cfg(desktop)]
use tauri::Manager;
#[cfg(desktop)]
use tauri::{PhysicalPosition, PhysicalSize, WebviewWindow};

#[cfg(desktop)]
const EXPANSION_DURATION: Duration = Duration::from_millis(1500);
#[cfg(desktop)]
const FRAME_INTERVAL: Duration = Duration::from_millis(16);

#[cfg(desktop)]
fn target_edges_for_window(window: &WebviewWindow) -> Result<WindowEdges, String> {
    let monitor = window
        .current_monitor()
        .map_err(|error| error.to_string())?
        .or(window
            .primary_monitor()
            .map_err(|error| error.to_string())?)
        .ok_or_else(|| "No display monitor is available".to_owned())?;
    let position = monitor.position();
    let size = monitor.size();
    Ok(target_edges(
        f64::from(position.x),
        f64::from(position.y),
        f64::from(size.width),
        f64::from(size.height),
    ))
}

#[cfg(desktop)]
fn apply_edges(window: &WebviewWindow, edges: WindowEdges) -> Result<(), String> {
    let position = PhysicalPosition::new(edges.left.round() as i32, edges.top.round() as i32);
    let size = PhysicalSize::new(
        (edges.right - edges.left).round().max(1.0) as u32,
        (edges.bottom - edges.top).round().max(1.0) as u32,
    );
    window
        .set_position(position)
        .map_err(|error| error.to_string())?;
    window.set_size(size).map_err(|error| error.to_string())
}

#[cfg(desktop)]
fn expand_native_window(window: WebviewWindow, reduced_motion: bool) -> Result<(), String> {
    let target = target_edges_for_window(&window)?;
    let position = window.outer_position().map_err(|error| error.to_string())?;
    let size = window.outer_size().map_err(|error| error.to_string())?;
    let start = WindowEdges {
        left: f64::from(position.x),
        top: f64::from(position.y),
        right: f64::from(position.x) + f64::from(size.width),
        bottom: f64::from(position.y) + f64::from(size.height),
    };
    let deltas = edge_deltas(start, target);
    let duration = if reduced_motion {
        Duration::from_millis(1)
    } else {
        EXPANSION_DURATION
    };
    let started_at = Instant::now();

    loop {
        let progress = (started_at.elapsed().as_secs_f64() / duration.as_secs_f64()).min(1.0);
        apply_edges(&window, interpolate_edges(start, deltas, progress))?;
        if progress >= 1.0 {
            return Ok(());
        }
        thread::sleep(FRAME_INTERVAL);
    }
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
            window.set_position(PhysicalPosition::new(
                (target.right - f64::from(size.width)).round() as i32,
                (target.bottom - f64::from(size.height)).round() as i32,
            ))?;
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            is_desktop,
            expand_window,
            start_window_dragging
        ]);
    #[cfg(mobile)]
    let builder = builder.invoke_handler(tauri::generate_handler![is_desktop]);
    builder
        .run(tauri::generate_context!())
        .expect("could not run Simplicity Engine");
}
