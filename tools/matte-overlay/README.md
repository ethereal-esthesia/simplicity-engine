# Matte Overlay

A native macOS menu-bar utility that places grey tint and persistent greyscale grain over every connected display. The tint softens contrast by lifting dark pixels and lowering bright pixels toward grey.

The grain adapts `serenity-engine/src/bin/invert_noise_fullscreen_probe.rs`: the same 64-bit LCG (`state * 6364136223846793005 + 1`), brightness `192 + ((state >> 32) % 64)`, with 64 possible grey levels. Each display now gets its own field at the window’s backing-pixel resolution, including Retina scaling, instead of stretching the original 960 × 540 field. The probe's changing hue is replaced with greyscale. A fixed seed keeps the texture stationary and consistent across displays; nearest-neighbour sampling preserves its grain. Each display’s image is cached and regenerated when its backing dimensions change, with no animation timer. macOS scaled display modes may resample the final desktop to the panel resolution. The new overlay uses 12% grain opacity, independently of the grey tint slider. At 0% tint the grain remains; **Turn Overlay Off** hides both layers.

Build and launch from the repository root:

```sh
bash tools/matte-overlay/build.sh
open "build/Matte Overlay.app"
```

Use **◐** in the menu bar to change strength (0–65%), toggle the overlay, or quit. Strength and enabled state persist between launches. The default is 18% neutral sRGB grey.

Run `"build/Matte Overlay.app/Contents/MacOS/MatteOverlay" --check-grain` to verify the noise generator and image dimensions.

Overlay windows ignore mouse events and never take keyboard focus. They cover full display frames, join desktop Spaces, support fullscreen Spaces, and rebuild when displays change. macOS secure surfaces and some system-managed fullscreen modes may appear above them. No screen capture or Accessibility permission is required. Quitting removes all overlays; the app does not install a login item.

Use **Full-resolution grain** in the menu to compare: checked uses the display backing resolution; unchecked uses the original 960 × 540 texture. This choice persists between launches.

**Random (animated grain)** refreshes at 30 fps using xorshift64 (left 13, right 7, left 17). The generator state transition uses only shifts and XOR, without multiplication or division. A continuous reservoir consumes every output bit in six-bit groups, carrying leftovers across pixels and frames; `192 | sample` retains the 192–255 range. This is a lightweight generator, not a benchmarked claim of the fastest possible implementation. Turning Random off restores the original stationary texture. Turning the overlay off stops the animation timer. Random mode persists between launches.

The menu omits a redundant app-name heading. **Turn Overlay Off / On** describes the available action without a checkmark. Tint labels and the slider stay enabled while the overlay is on, including at 0% tint; they are greyed out and the slider is disabled only while the overlay is off.
