# Mobile Testing Setup

This note documents the local mobile-testing setup for:

- Android phone
- Android tablet
- Amazon Fire tablet
- iPhone
- iPad

It also documents how to install Android Studio and keep the heavy Android files on the external volume under:

`/Volumes/Storage/VM Images/Android Studio`

## What QEMU Can Cover

Short version:

| Target | Primary tool | QEMU coverage | Final answer |
| --- | --- | --- | --- |
| Android phone | Android Studio Emulator | QEMU-backed under the hood | Yes, for emulator-based testing |
| Android tablet | Android Studio Emulator | QEMU-backed under the hood | Yes, for emulator-based testing |
| Amazon Fire tablet | Android Studio virtual device plus Fire-specific profile | Close enough for initial verification | Partially |
| iPhone | Xcode Simulator | None in the supported workflow | No |
| iPad | Xcode Simulator | None in the supported workflow | No |

So if the question is "can one QEMU-based setup cover all three targets?", the answer is no.

What it can do:
- Android phone: yes
- Android tablet: yes
- Fire tablet: yes for early checks, but not as the whole submission path
- iPhone: no
- iPad: no

## Android Studio Install on the External Volume

This section assumes macOS with Homebrew and an external volume mounted at:

`/Volumes/Storage`

### 1. Install Android Studio and platform tools

```bash
brew install --cask android-studio android-platform-tools
```

This places the Android Studio app bundle in the standard macOS location:

`/Applications/Android Studio.app`

### 2. Create the external Android Studio folder

```bash
mkdir -p "/Volumes/Storage/VM Images/Android Studio"
```

### 3. Move the Android Studio app bundle to the external volume

```bash
mv "/Applications/Android Studio.app" \
  "/Volumes/Storage/VM Images/Android Studio/Android Studio.app"

ln -s "/Volumes/Storage/VM Images/Android Studio/Android Studio.app" \
  "/Applications/Android Studio.app"
```

This keeps the normal macOS app path intact while storing the actual app bundle on the external volume.

### 4. Move the Android SDK and emulator AVD storage to the external volume

If Android Studio or the SDK has already been used, the bulky parts normally live here:

- `~/Library/Android/sdk`
- `~/.android/avd`

Move them to the external volume and leave symlinks behind:

```bash
mkdir -p "/Volumes/Storage/VM Images/Android Studio"

if [ -d "$HOME/Library/Android/sdk" ] && [ ! -L "$HOME/Library/Android/sdk" ]; then
  mv "$HOME/Library/Android/sdk" "/Volumes/Storage/VM Images/Android Studio/sdk"
fi

if [ -d "$HOME/.android/avd" ] && [ ! -L "$HOME/.android/avd" ]; then
  mv "$HOME/.android/avd" "/Volumes/Storage/VM Images/Android Studio/avd"
fi

mkdir -p "/Volumes/Storage/VM Images/Android Studio/sdk"
mkdir -p "/Volumes/Storage/VM Images/Android Studio/avd"

ln -sfn "/Volumes/Storage/VM Images/Android Studio/sdk" \
  "$HOME/Library/Android/sdk"

ln -sfn "/Volumes/Storage/VM Images/Android Studio/avd" \
  "$HOME/.android/avd"
```

After that, the expected visible paths stay the same:

- `/Applications/Android Studio.app`
- `~/Library/Android/sdk`
- `~/.android/avd`

But the actual storage lives here:

- `/Volumes/Storage/VM Images/Android Studio/Android Studio.app`
- `/Volumes/Storage/VM Images/Android Studio/sdk`
- `/Volumes/Storage/VM Images/Android Studio/avd`

### 5. Launch Android Studio and install emulator components

Open Android Studio and use the SDK Manager to install:

- Android SDK Platform
- Android Emulator
- at least one Android system image

Then create an Android Virtual Device in Device Manager.

## Android Phone Environment

Use the Android Emulator in Android Studio for day-to-day phone iteration.

Why:
- Google recommends the Android Emulator for testing across different device types and Android API levels.
- It is the supported fast feedback loop for UI, input, and rendering checks.
- It is the QEMU-backed environment that actually makes sense here.

Practical setup:

1. Open Android Studio.
2. Open `View > Tool Windows > Device Manager`.
3. Click `+` and choose `Create Virtual Device`.
4. Pick a phone profile such as `Pixel`.
5. Install and select a current Google Play or Google APIs system image.
6. Start the AVD and use `adb install -r your-app.apk` for quick local installs.

Keep at least one real Android device for final checks when any of these matter:

- animation smoothness
- touch feel
- GPU/driver behavior
- memory pressure
- thermal throttling

## Android Tablet Environment

Use Android Studio's emulator again here, but create a tablet AVD instead of a phone AVD.

Practical setup:

1. Open Android Studio Device Manager.
2. Create a new virtual device.
3. Choose a tablet profile such as `Pixel Tablet`.
4. Install and select a current system image.
5. Verify orientation changes, letterboxing, pointer input, and large-layout behavior.

Use a real Android tablet when you need final confidence in frame pacing, touch behavior, and GPU quirks on larger screens.

## Amazon Fire Tablet Environment

Use Android Studio's Device Manager to create a virtual Amazon-style device for initial verification, then test on a physical Fire tablet before submission.

Why:
- Amazon documents a virtual-device path using Android Studio's AVD tooling and Fire tablet specs.
- Amazon also says virtual-device testing is only an initial step and that physical-device testing is still required before Appstore submission.

Good fit for:
- layout checks
- orientation checks
- coarse rendering checks
- basic installation and startup checks

Not enough by itself for:
- final Appstore readiness
- hardware-specific behavior
- full confidence in performance and tablet feel

For 2D apps, enable hardware acceleration in the manifest:

```xml
<application
    android:hardwareAccelerated="true" />
```

If you want to debug a real Fire tablet from the Mac side, install it over ADB:

```bash
adb devices
adb install -r your-app.apk
```

## iPhone Environment

Do not use QEMU here. Use Xcode Simulator plus a real iPhone.

### Install Xcode and the iPhone simulator

1. Install `Xcode` from the Mac App Store.
2. Point command-line tools at it:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

3. Open Xcode and go to `Xcode > Settings > Components`.
4. Install the current `iOS` Simulator runtime if it is not already present.

Optional command-line helper for downloading platform support:

```bash
xcodebuild -downloadPlatform iOS -exportPath "$HOME/Downloads"
```

### Use it

1. Open your Xcode project.
2. Pick an `iPhone` run destination in the toolbar.
3. Press Run, or launch the Simulator directly with:

```bash
open -a Simulator
```

Why:
- Apple's supported workflow is Simulator plus real hardware.
- Apple is explicit that Simulator does not replicate real-device performance, memory usage, or every hardware feature.

Good fit for Simulator:
- layout
- navigation
- basic rendering
- quick interaction checks

Still use a real iPhone for:
- performance
- GPU behavior
- touch feel
- battery and thermal reality
- release confidence

## iPad Environment

Use the same Xcode installation as iPhone, but select an `iPad` simulator device type.

Practical setup:

1. Install Xcode and the `iOS` Simulator runtime as described above.
2. In Xcode, choose an `iPad` run destination such as `iPad Pro`.
3. Verify split-view behavior, stage-size changes, large touch targets, and landscape layouts.

Use a real iPad before release when performance, pencil input, keyboard interaction, or large-canvas memory behavior matters.

## Recommended Practical Device Matrix

If the goal is the smallest sane setup for a 2D graphics app:

1. Android Studio Emulator with one Android phone AVD
2. Android Studio Emulator with one Android tablet AVD
3. one real Android phone
4. one real Fire tablet
5. Xcode Simulator with iPhone and iPad destinations
6. one real iPhone or iPad, depending on which Apple form factor matters more first

That is the practical line between "useful emulator coverage" and "this still needs hardware."

## Sources

- Android Emulator: <https://developer.android.com/studio/run/emulator>
- Android AVD management: <https://developer.android.com/studio/run/managing-avds>
- Android hardware-device testing: <https://developer.android.com/studio/run/device>
- Android quality guidelines: <https://developer.android.com/docs/quality-guidelines/core-app-quality>
- Amazon virtual Fire testing: <https://www.developer.amazon.com/docs/fire-tablets/ft-testing-without-an-amazon-device.html>
- Amazon Fire tablet run/install testing: <https://developer.amazon.com/docs/fire-tablets/ft-test-app-on-emulator-or-tablet.html>
- Amazon Fire tablet ADB setup: <https://developer.amazon.com/docs/fire-tablets/connecting-adb-to-device.html>
- Amazon Fire tablet test criteria: <https://developer.amazon.com/docs/app-testing/test-criteria.html>
- Apple Xcode components and simulator runtimes: <https://developer.apple.com/documentation/xcode/installing-additional-simulator-runtimes>
- Apple run in Simulator or on device: <https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device/>
- Apple devices and Simulator overview: <https://developer.apple.com/documentation/xcode/devices-and-simulator/>
- Apple Simulator vs hardware: <https://developer.apple.com/documentation/xcode/testing-in-simulator-versus-testing-on-hardware-devices>
