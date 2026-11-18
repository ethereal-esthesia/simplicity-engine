import AppKit

let app = NSApplication.shared
guard app.setActivationPolicy(.accessory) else {
    fputs("Unable to set accessory activation policy\n", stderr)
    exit(1)
}

let screens = NSScreen.screens
guard !screens.isEmpty else {
    fputs("No displays are available\n", stderr)
    exit(1)
}

let panels = screens.map { screen in
    let frame = NSRect(
        x: screen.frame.maxX - 220,
        y: screen.frame.maxY - 160,
        width: 180,
        height: 120
    )
    let panel = NSPanel(
        contentRect: frame,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false,
        screen: screen
    )
    panel.isReleasedWhenClosed = false
    panel.backgroundColor = .systemRed
    panel.isOpaque = true
    panel.hasShadow = true
    panel.ignoresMouseEvents = true
    panel.hidesOnDeactivate = false
    panel.level = .screenSaver
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    panel.orderFrontRegardless()
    return panel
}

print("Showing a red block on \(panels.count) display(s). Press Ctrl-C to stop.")
fflush(stdout)
app.run()
