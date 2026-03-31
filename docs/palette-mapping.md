# Palette Mapping: Hue-Anchor at 128

This document defines a compact, integer-safe palette mapping used for blur/intensity rendering.

## Goals
- Index `0` is black.
- Index `128` is the selected hue anchor color `N = (Nr, Ng, Nb)`.
- Index `255` is white.
- `1..127` ramps from black to `N`.
- `129..255` ramps from `N` to white.

## Hue Anchor Color
The hue anchor `N` is obtained from an 8-bit hue table (piecewise linear interpolation across knot colors). Once `N` is chosen, the palette formula below is independent of hue model.

### Hue Level Calculation (Reproducible)
If hue is provided in degrees:

```text
hue8 = round(hue_deg * 255 / 360) mod 256
```

Then compute anchor `N = (Nr, Ng, Nb)` by piecewise interpolation on these knots:

```text
H=0   -> (255,  85,  85)
H=43  -> (171, 171,   1)
H=85  -> ( 87, 255,  85)
H=128 -> (  1, 171, 171)
H=170 -> ( 83,  87, 255)
H=213 -> (169,   1, 171)
H=255 -> (253,  83,  87)
```

For each channel `C in {R,G,B}` on the segment `[H0,H1]`:

```text
C = round((C0*(H1 - H) + C1*(H - H0)) / (H1 - H0))
```

where `H` is `hue8`.

## Pretty-Print Formula
Given `value` in `[0, 255]` and anchor channel `n` (one of `Nr`, `Ng`, `Nb`):

```text
value = 0:
  C = 0

1 <= value <= 127:
  C = round(n * value / 128)

value = 128:
  C = n

129 <= value <= 255:
  t = value - 128
  C = n + round((255 - n) * t / 127)

value = 255:
  C = 255
```

Apply that channel-wise to get `R, G, B`.

### Level Meaning
- `value` is the palette level/index (`0..255`).
- `0..128` is the black-to-hue side.
- `128` is the hue anchor level.
- `128..255` is the hue-to-white side.

## Integer Implementation (Rounded)
Use integer rounding and clamp output to `[0, 255]`:

```cpp
uint8_t to_black_side(uint8_t n, int value) {
    // value in [0, 128]
    int c = (static_cast<int>(n) * value + 64) / 128;   // rounded
    return static_cast<uint8_t>(std::clamp(c, 0, 255));
}

uint8_t to_white_side(uint8_t n, int value) {
    // value in [128, 255]
    int t = value - 128;
    int c = static_cast<int>(n) + ((255 - static_cast<int>(n)) * t + 63) / 127; // rounded
    return static_cast<uint8_t>(std::clamp(c, 0, 255));
}
```

## Full Palette Reproduction Algorithm

```text
Input: hue_deg
Output: palette[256] (RGB + alpha)

1) Compute hue8 = round(hue_deg * 255 / 360) mod 256
2) Compute anchor N=(Nr,Ng,Nb) from hue8 via knot interpolation
3) Set palette[0]   = (0,0,0,0)
4) For value=1..127:
     R = round(Nr * value / 128)
     G = round(Ng * value / 128)
     B = round(Nb * value / 128)
     A = value
5) Set palette[128] = (Nr,Ng,Nb,128)
6) For value=129..254:
     t = value - 128
     R = Nr + round((255 - Nr) * t / 127)
     G = Ng + round((255 - Ng) * t / 127)
     B = Nb + round((255 - Nb) * t / 127)
     A = value
7) Set palette[255] = (255,255,255,255)
```

## Notes
- This preserves the anchor hue exactly at `128`.
- Brightness progression is monotonic toward black on one side and white on the other.
- The formula is deterministic and stable for byte-based render pipelines.

## LModL Gaussian Pixel-Area (Pretty Print)
LModL's blur path estimates per-pixel Gaussian area by sub-sampling each pixel on a grid and averaging the Gaussian value over those samples (with circular clipping at radius `r`).

### Core Gaussian Term

```text
G(d, r) = (1 / sqrt(2*pi)) * exp( -9 * d^2 / (2 * r^2) )
```

where:
- `d = sqrt(x^2 + y^2)` is distance from blur center
- `r` is blur radius
- samples with `d > r` are excluded

### Per-Pixel Estimate

```text
mSum = 0
for each sub-sample s inside the pixel:
  d_s = distance(sample_position_s, blur_center)
  if d_s <= r:
    mSum += G(d_s, r) * normMult * amp

pixel_intensity = mSum / (subsample_count * 4)
```

The implementation uses integer/fixed-style scaling constants (`normMult`, `amp`) and shifts in place of explicit floating division in the hot loop.

### Reproducible Pseudocode

```text
Input:
  pixel center (xp, yp)
  blur center (x, y)
  radius r
  granularity g = 2^granShift

For each pixel in bounding square [x-r, x+r] x [y-r, y+r]:
  mSum = 0
  For gy in 0..g-1:
    For gx in 0..g-1:
      sample_x = xp + ((gx + 0.5)/g) - x
      sample_y = yp + ((gy + 0.5)/g) - y
      d = sqrt(sample_x^2 + sample_y^2)
      If d <= r:
        mSum += (1/sqrt(2*pi)) * exp(-9*d^2/(2*r^2)) * normMult * amp

  pixel_intensity = mSum / (g*g*4)
```
