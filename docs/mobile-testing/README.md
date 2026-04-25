# Mobile Testing

This note collects the practical testing setup for our own 2D graphics apps on:

- Android phone
- Android tablet
- Amazon Fire tablets
- iPhone
- iPad

It also answers the narrower question: can QEMU cover these targets by itself?

## Recommended Setup

### Android Phone

Use the Android Emulator in Android Studio for day-to-day iteration.

Why:
- Google recommends the Android Emulator for testing across different device types and API levels.
- It is fast for layout, rendering, and interaction checks.
- It is the normal first stop before moving to hardware.

Keep at least one real Android device for final checks when any of the following matter:
- animation smoothness
- touch feel
- GPU/driver behavior
- memory pressure
- thermal throttling

Practical setup:
1. Open Android Studio Device Manager.
2. Create a phone AVD such as a `Pixel`.
3. Install a current system image.
4. Start the emulator and install builds with `adb install -r your-app.apk`.

### Android Tablet

Use Android Studio again, but create a tablet AVD such as `Pixel Tablet`.

Focus on:
- large-layout behavior
- orientation changes
- touch target sizing
- pointer and keyboard behavior where relevant

## Amazon Fire Tablet

Use a virtual Amazon device in Android Studio for initial verification, then test on a real Fire tablet before submission.

Why:
- Amazon documents a virtual-device path using Android Studio's Device Manager and custom Fire tablet specs.
- Amazon also says virtual testing is only an initial verification step and requires physical-device testing before Appstore submission.
- Fire-specific QA should include layout on tablet screens and smooth 2D rendering with hardware acceleration enabled.

For 2D apps, make sure the manifest enables hardware acceleration:

```xml
<application
    android:hardwareAccelerated="true" />
```

## iPhone

Use Xcode Simulator for iteration and a real iPhone for final validation.

Practical install steps:
1. Install `Xcode` from the Mac App Store.
2. Run:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

3. In `Xcode > Settings > Components`, install the current `iOS` Simulator runtime.
4. Choose an `iPhone` run destination and run the app.

Why:
- Apple recommends Simulator for quick debugging and testing on multiple device shapes.
- Apple is explicit that Simulator does not replicate real-device performance, memory behavior, or every hardware feature.
- Real hardware is required for final graphics/performance confidence.

## iPad

Use the same Xcode setup as iPhone, but add an `iPad` simulator destination.

Focus on:
- large-canvas layouts
- landscape behavior
- split-view and resizable scene behavior
- memory use on tablet-sized content

## QEMU Verdict

Short version:

| Target | Best tool | Can QEMU cover it? | Notes |
| --- | --- | --- | --- |
| Android phone | Android Studio Emulator + real Android phone | Yes, partially | The Android Emulator is the right workflow and is QEMU-based under the hood. |
| Android tablet | Android Studio Emulator + real Android tablet | Yes, partially | Same emulator stack as Android phone, just a tablet AVD and final tablet hardware pass. |
| Amazon Fire tablet | Android Studio virtual Fire device + real Fire tablet | Yes, partially | Good for initial verification because Fire OS is Android-based, but Amazon still requires testing on a physical Fire tablet before submission. |
| iPhone | Xcode Simulator + real iPhone | No | QEMU is not the supported workflow here. Use Apple's tooling. |
| iPad | Xcode Simulator + real iPad | No | Use Apple's tooling here as well. |

## Practical Guidance

If the goal is shipping a 2D app with the smallest sane device matrix:

1. Use Android Studio Emulator for Android.
2. Add one Android tablet AVD for large-screen checks.
3. Add one physical Android phone for final checks.
4. Add one physical Fire tablet for Amazon validation.
5. Use Xcode Simulator for iPhone and iPad iteration.
6. Add one physical iPhone or iPad for final checks.

That gets broad coverage without pretending a single VM tool solves everything.

## Why QEMU Stops Short

QEMU is useful here, but only as part of the Android side:

- Android Studio Emulator is the normal Android testing path and provides the best supported emulator workflow.
- Amazon's virtual Fire path builds on Android Studio virtual devices rather than asking you to hand-roll a direct QEMU workflow.
- Apple's documented path is Xcode Simulator plus real hardware, not QEMU.

So if the question is "can QEMU be the one universal answer for Android, Fire, and iPhone testing?", the answer is no.

## Sources

- Android Emulator: <https://developer.android.com/studio/run/emulator>
- Android AVD management: <https://developer.android.com/studio/run/managing-avds>
- Android quality guidelines: <https://developer.android.com/docs/quality-guidelines/core-app-quality>
- Amazon virtual Fire testing: <https://www.developer.amazon.com/docs/fire-tablets/ft-testing-without-an-amazon-device.html>
- Amazon Fire tablet test criteria: <https://developer.amazon.com/docs/app-testing/test-criteria.html>
- Amazon run on Fire tablet: <https://developer.amazon.com/docs/fire-tablets/ft-test-app-on-emulator-or-tablet.html>
- Apple Xcode components and simulator runtimes: <https://developer.apple.com/documentation/xcode/installing-additional-simulator-runtimes>
- Apple run in Simulator or on device: <https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device/>
- Apple devices and Simulator overview: <https://developer.apple.com/documentation/xcode/devices-and-simulator/>
- Apple Simulator vs hardware: <https://developer.apple.com/documentation/xcode/testing-in-simulator-versus-testing-on-hardware-devices>
