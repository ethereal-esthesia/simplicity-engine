#[derive(Clone, Copy, Debug, PartialEq)]
pub struct WindowEdges {
    pub left: f64,
    pub top: f64,
    pub right: f64,
    pub bottom: f64,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum WindowCorner {
    TopLeft,
    TopRight,
    BottomLeft,
    BottomRight,
}

pub fn nearest_corner(window: WindowEdges, display: WindowEdges) -> WindowCorner {
    let left = window.left + window.right < display.left + display.right;
    let top = window.top + window.bottom < display.top + display.bottom;
    match (top, left) {
        (true, true) => WindowCorner::TopLeft,
        (true, false) => WindowCorner::TopRight,
        (false, true) => WindowCorner::BottomLeft,
        (false, false) => WindowCorner::BottomRight,
    }
}

pub fn target_edges(origin_x: f64, origin_y: f64, width: f64, height: f64) -> WindowEdges {
    let inset = width.min(height) * 0.05;
    WindowEdges {
        left: origin_x + inset,
        top: origin_y + inset,
        right: origin_x + width - inset,
        bottom: origin_y + height - inset,
    }
}

pub fn bottom_right_edges(container: WindowEdges, width: f64, height: f64) -> WindowEdges {
    WindowEdges {
        left: container.right - width,
        top: container.bottom - height,
        right: container.right,
        bottom: container.bottom,
    }
}

pub fn top_right_edges(container: WindowEdges, width: f64, height: f64) -> WindowEdges {
    WindowEdges {
        left: container.right - width,
        top: container.top,
        right: container.right,
        bottom: container.top + height,
    }
}

pub fn edge_deltas(start: WindowEdges, target: WindowEdges) -> WindowEdges {
    WindowEdges {
        left: target.left - start.left,
        top: target.top - start.top,
        right: target.right - start.right,
        bottom: target.bottom - start.bottom,
    }
}

pub fn interpolate_edges(start: WindowEdges, deltas: WindowEdges, progress: f64) -> WindowEdges {
    let progress = progress.clamp(0.0, 1.0);
    let amount = progress * progress * (3.0 - 2.0 * progress);
    WindowEdges {
        left: start.left + deltas.left * amount,
        top: start.top + deltas.top * amount,
        right: start.right + deltas.right * amount,
        bottom: start.bottom + deltas.bottom * amount,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn target_edges_use_five_percent_of_the_shorter_monitor_dimension() {
        assert_eq!(
            target_edges(0.0, 0.0, 800.0, 600.0),
            WindowEdges {
                left: 30.0,
                top: 30.0,
                right: 770.0,
                bottom: 570.0,
            }
        );
        assert_eq!(
            target_edges(100.0, -200.0, 600.0, 800.0),
            WindowEdges {
                left: 130.0,
                top: -170.0,
                right: 670.0,
                bottom: 570.0,
            }
        );
    }

    #[test]
    fn all_edges_follow_the_same_eased_fraction_of_precomputed_deltas() {
        let start = WindowEdges {
            left: 700.0,
            top: 500.0,
            right: 780.0,
            bottom: 580.0,
        };
        let target = target_edges(0.0, 0.0, 800.0, 600.0);
        let deltas = edge_deltas(start, target);
        let eased = 0.25_f64.powi(2) * (3.0 - 2.0 * 0.25);
        let current = interpolate_edges(start, deltas, 0.25);

        assert_eq!(current.left, start.left + deltas.left * eased);
        assert_eq!(current.top, start.top + deltas.top * eased);
        assert_eq!(current.right, start.right + deltas.right * eased);
        assert_eq!(current.bottom, start.bottom + deltas.bottom * eased);
        assert_eq!(interpolate_edges(start, deltas, 1.0), target);
    }

    #[test]
    fn compact_window_is_anchored_to_the_targets_bottom_right_corner() {
        let target = target_edges(0.0, 0.0, 800.0, 600.0);
        assert_eq!(
            bottom_right_edges(target, 88.0, 88.0),
            WindowEdges {
                left: 682.0,
                top: 482.0,
                right: 770.0,
                bottom: 570.0,
            }
        );
    }

    #[test]
    fn compact_window_is_anchored_to_the_targets_top_right_corner() {
        let target = target_edges(-1000.0, -500.0, 1000.0, 800.0);
        let window = top_right_edges(target, 88.0, 60.0);
        assert_eq!(
            window,
            WindowEdges {
                left: -128.0,
                top: -460.0,
                right: -40.0,
                bottom: -400.0,
            }
        );
        assert_eq!(nearest_corner(window, target), WindowCorner::TopRight);
    }

    #[test]
    fn interpolation_preserves_fractional_edge_positions() {
        let start = WindowEdges {
            left: 0.0,
            top: 0.0,
            right: 10.0,
            bottom: 10.0,
        };
        let deltas = WindowEdges {
            left: 1.0,
            top: 1.0,
            right: 1.0,
            bottom: 1.0,
        };
        assert_eq!(
            interpolate_edges(start, deltas, 0.5),
            WindowEdges {
                left: 0.5,
                top: 0.5,
                right: 10.5,
                bottom: 10.5,
            }
        );
    }

    #[test]
    fn nearest_display_corner_follows_window_center_in_each_quadrant() {
        let display = target_edges(-1000.0, -500.0, 1000.0, 800.0);
        for (x, y, expected) in [
            (-900.0, -400.0, WindowCorner::TopLeft),
            (-200.0, -400.0, WindowCorner::TopRight),
            (-900.0, 100.0, WindowCorner::BottomLeft),
            (-200.0, 100.0, WindowCorner::BottomRight),
        ] {
            let window = WindowEdges {
                left: x,
                top: y,
                right: x + 88.0,
                bottom: y + 88.0,
            };
            assert_eq!(nearest_corner(window, display), expected);
        }
    }

    #[test]
    fn nearest_display_corner_breaks_center_ties_toward_bottom_right() {
        let display = target_edges(0.0, 0.0, 800.0, 600.0);
        let centered = WindowEdges {
            left: 356.0,
            top: 256.0,
            right: 444.0,
            bottom: 344.0,
        };
        assert_eq!(nearest_corner(centered, display), WindowCorner::BottomRight);
    }
}
