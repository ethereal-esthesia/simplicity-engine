//! Host-independent engine behavior and the C ABI shared by native and Wasm
//! hosts; no browser or Tauri dependencies.

pub mod fast_rng;
pub mod menu;

#[no_mangle]
pub extern "C" fn abi_version() -> u32 {
    1
}

#[no_mangle]
pub extern "C" fn mark_size() -> f64 {
    8.0
}

#[no_mangle]
pub extern "C" fn mark_origin(extent: f64) -> f64 {
    if extent.is_finite() && extent > 0.0 {
        (extent - mark_size()) * 0.5
    } else {
        0.0
    }
}

#[no_mangle]
pub extern "C" fn background_rgb() -> u32 {
    0x080c12
}

#[no_mangle]
pub extern "C" fn mark_rgb() -> u32 {
    0x40ffd0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mark_stays_centered_across_viewport_sizes() {
        for extent in [1.0, 8.0, 640.0, 1920.0, 3840.0] {
            assert_eq!(mark_origin(extent) + mark_size() / 2.0, extent / 2.0);
        }
    }

    #[test]
    fn invalid_dimensions_do_not_propagate_nan() {
        for extent in [0.0, -1.0, f64::NAN, f64::INFINITY] {
            assert_eq!(mark_origin(extent), 0.0);
        }
    }
}
