import AppKit

// Xorshift64: the state transition uses only shifts and XOR.
// A continuous bit reservoir packs six bits per grey sample; leftovers
// carry across word, image, and frame boundaries instead of being discarded.
struct GrainRNG {
    private var state: UInt64 = 0x9E3779B97F4A7C15
    private var reservoir: UInt64 = 0
    private var remaining = 0

    mutating func nextGrey() -> UInt8 {
        if remaining >= 6 {
            let value = UInt8(reservoir & 63)
            reservoir >>= 6
            remaining -= 6
            return 192 | value
        }
        let carry = reservoir
        let carryCount = remaining
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        let needed = 6 - carryCount
        let value = carry | ((state & ((1 << needed) - 1)) << carryCount)
        reservoir = state >> needed
        remaining = 64 - needed
        return 192 | UInt8(value)
    }
}

// Adapted from serenity-engine/src/bin/invert_noise_fullscreen_probe.rs:
// same LCG and 192...255 brightness distribution, at display backing resolution.
// The probe resets its seed each frame; its spatial grain is stationary.
enum ProbeGrain {
    static let opacity: CGFloat = 0.12

    static func samples(seed: UInt64, count: Int) -> [UInt8] {
        var state = seed
        return (0..<count).map { _ in
            state = state &* 6364136223846793005 &+ 1
            return 192 + UInt8((state >> 32) % 64)
        }
    }

    static func image(width: Int, height: Int) -> CGImage {
        let pixels = samples(seed: 0x9E3779B97F4A7C15, count: width * height)
        return image(width: width, height: height, pixels: pixels)
    }

    static func image(width: Int, height: Int, pixels: [UInt8]) -> CGImage {
        let provider = CGDataProvider(data: Data(pixels) as CFData)!
        return CGImage(width: width, height: height, bitsPerComponent: 8,
                       bitsPerPixel: 8, bytesPerRow: width,
                       space: CGColorSpaceCreateDeviceGray(), bitmapInfo: [],
                       provider: provider, decode: nil, shouldInterpolate: false,
                       intent: .defaultIntent)!
    }
}

final class MatteView: NSView {
    var strength: Double = 0 { didSet { needsDisplay = true } }
    override var isOpaque: Bool { false }
    var fullResolution = true { didSet { needsDisplay = true } }
    var random = false {
        didSet {
            if random != oldValue { grain = nil; needsDisplay = true }
        }
    }
    private var rng = GrainRNG()
    private var grain: CGImage?

    func advanceGrain() {
        guard random else { return }
        grain = nil
        needsDisplay = true
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        needsDisplay = true
    }

    private func grainImage() -> CGImage {
        let pixels = convertToBacking(bounds)
        let width = fullResolution ? max(1, Int(pixels.width.rounded())) : 960
        let height = fullResolution ? max(1, Int(pixels.height.rounded())) : 540
        if grain?.width != width || grain?.height != height {
            if random {
                let values = (0..<(width * height)).map { _ in rng.nextGrey() }
                grain = ProbeGrain.image(width: width, height: height, pixels: values)
            } else {
                grain = ProbeGrain.image(width: width, height: height)
            }
        }
        return grain!
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        context.setFillColor(NSColor(srgbRed: 0.5, green: 0.5, blue: 0.5,
                                     alpha: strength).cgColor)
        context.fill(bounds)
        context.saveGState()
        context.interpolationQuality = .none
        context.setAlpha(ProbeGrain.opacity)
        context.draw(grainImage(), in: bounds)
        context.restoreGState()
    }
}

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [NSWindow] = []
    private var statusItem: NSStatusItem!
    private var toggleItem: NSMenuItem!
    private var strengthItem: NSMenuItem!
    private var ditherInfoItem: NSMenuItem!
    private var tintSlider: NSSlider!
    private var resolutionItem: NSMenuItem!
    private var randomItem: NSMenuItem!
    private var random = false
    private var animationTimer: Timer?
    private var fullResolution = true
    private let defaults = UserDefaults.standard
    private var enabled = true
    private var strength: Double = 0.18

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: ["strength": 0.18, "enabled": true, "fullResolution": true])
        strength = min(0.65, max(0, defaults.double(forKey: "strength")))
        enabled = defaults.bool(forKey: "enabled")
        fullResolution = defaults.bool(forKey: "fullResolution")
        random = defaults.bool(forKey: "randomGrain")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "◐"
        statusItem.button?.toolTip = "Matte Overlay"
        let menu = NSMenu()
        menu.autoenablesItems = false
        toggleItem = NSMenuItem(title: "", action: #selector(toggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        resolutionItem = NSMenuItem(title: "Full-resolution grain", action: #selector(toggleResolution), keyEquivalent: "")
        resolutionItem.target = self
        menu.addItem(resolutionItem)
        randomItem = NSMenuItem(title: "Random (animated grain)", action: #selector(toggleRandom), keyEquivalent: "")
        randomItem.target = self
        menu.addItem(randomItem)
        menu.addItem(.separator())
        strengthItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.addItem(strengthItem)
        ditherInfoItem = NSMenuItem(title: "Dither stays on at 0% tint", action: nil, keyEquivalent: "")
        menu.addItem(ditherInfoItem)
        let slider = NSSlider(value: strength, minValue: 0, maxValue: 0.65,
                              target: self, action: #selector(changeStrength(_:)))
        tintSlider = slider
        slider.isContinuous = true
        slider.frame = NSRect(x: 16, y: 8, width: 210, height: 24)
        slider.setAccessibilityLabel("Grey overlay strength")
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 242, height: 40))
        container.addSubview(slider)
        let sliderItem = NSMenuItem()
        sliderItem.view = container
        menu.addItem(sliderItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Matte Overlay", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
        NotificationCenter.default.addObserver(self, selector: #selector(rebuildWindows),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        rebuildWindows()
    }

    @objc private func rebuildWindows() {
        windows.forEach { $0.close() }
        windows = NSScreen.screens.map { screen in
            let window = OverlayWindow(contentRect: screen.frame, styleMask: .borderless,
                                       backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.backgroundColor = .clear
            window.contentView = MatteView(frame: NSRect(origin: .zero, size: screen.frame.size))
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.hidesOnDeactivate = false
            window.isMovable = false
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)))
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.setFrame(screen.frame, display: true)
            return window
        }
        updateAppearance()
    }

    private func updateAppearance() {
        for window in windows {
            (window.contentView as? MatteView)?.strength = strength
            (window.contentView as? MatteView)?.fullResolution = fullResolution
            (window.contentView as? MatteView)?.random = random
            if enabled { window.orderFrontRegardless() } else { window.orderOut(nil) }
        }
        randomItem.state = random ? .on : .off
        updateAnimation()
        resolutionItem.state = fullResolution ? .on : .off
        toggleItem.title = enabled ? "Turn Overlay Off" : "Turn Overlay On"
        toggleItem.state = .off
        strengthItem.isEnabled = enabled
        ditherInfoItem.isEnabled = enabled
        tintSlider.isEnabled = enabled
        strengthItem.title = "Grey tint: \(Int((strength * 100).rounded()))%"
        statusItem.button?.appearsDisabled = !enabled
    }

    private func updateAnimation() {
        guard random && enabled else {
            animationTimer?.invalidate()
            animationTimer = nil
            return
        }
        guard animationTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.windows.forEach { ($0.contentView as? MatteView)?.advanceGrain() }
        }
        timer.tolerance = 0.002
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    @objc private func toggleRandom() {
        random.toggle()
        defaults.set(random, forKey: "randomGrain")
        updateAppearance()
    }

    @objc private func toggleResolution() {
        fullResolution.toggle()
        defaults.set(fullResolution, forKey: "fullResolution")
        updateAppearance()
    }

    @objc private func toggle() {
        enabled.toggle()
        defaults.set(enabled, forKey: "enabled")
        updateAppearance()
    }

    @objc private func changeStrength(_ slider: NSSlider) {
        strength = slider.doubleValue
        defaults.set(strength, forKey: "strength")
        updateAppearance()
    }

    @objc private func quitApp() { NSApp.terminate(nil) }
}

if CommandLine.arguments.contains("--check-grain") {
    // Independent bit-by-bit reference verifies packing across 64-bit boundaries.
    var referenceState: UInt64 = 0x9E3779B97F4A7C15
    var bits: [UInt8] = []
    for _ in 0..<99 {
        referenceState ^= referenceState << 13
        referenceState ^= referenceState >> 7
        referenceState ^= referenceState << 17
        for bit in 0..<64 { bits.append(UInt8((referenceState >> bit) & 1)) }
    }
    var rng = GrainRNG()
    var generated: [UInt8] = []
    for offset in stride(from: 0, to: bits.count, by: 6) {
        var value: UInt8 = 192
        for bit in 0..<6 { value |= bits[offset + bit] << bit }
        let actual = rng.nextGrey()
        precondition(actual == value, "Lost or reordered RNG bits")
        generated.append(actual)
    }
    precondition(Set(generated) == Set(UInt8(192)...UInt8(255)))
    let samples = ProbeGrain.samples(seed: 0x9E3779B97F4A7C15, count: 960 * 540)
    precondition(Set(samples) == Set(UInt8(192)...UInt8(255)))
    precondition(samples == ProbeGrain.samples(seed: 0x9E3779B97F4A7C15, count: samples.count))
    precondition(ProbeGrain.opacity > 0)
    for (width, height) in [(960, 540), (1920, 1080), (3840, 2160)] {
        let image = ProbeGrain.image(width: width, height: height)
        precondition(image.width == width && image.height == height)
        precondition(image.bytesPerRow == width)
    }
    precondition(Array(samples.prefix(8)) == [226, 232, 247, 223, 228, 236, 209, 208])
    for tint in [0.0, 0.18, 0.65] {
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 960, pixelsHigh: 540,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let view = MatteView(frame: NSRect(x: 0, y: 0, width: 960, height: 540))
        view.strength = tint
        view.draw(view.bounds)
        NSGraphicsContext.restoreGraphicsState()
        let colors = (0..<64).map { bitmap.colorAt(x: $0, y: 0)! }
        precondition(colors.allSatisfy { $0.alphaComponent > 0 })
        precondition(Set(colors.map { Int(($0.redComponent * 255).rounded()) }).count > 1)
    }
    print("Grain checks passed; first samples: \(Array(samples.prefix(8)))")
    exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
