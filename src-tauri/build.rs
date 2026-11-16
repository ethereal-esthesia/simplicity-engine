fn main() {
    if std::env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("macos") {
        cc::Build::new()
            .file("src/screen_recording.m")
            .flag("-fobjc-arc")
            .flag("-fblocks")
            .compile("screen_recording");
        for framework in ["AppKit", "AVFoundation", "CoreGraphics", "CoreMedia"] {
            println!("cargo:rustc-link-lib=framework={framework}");
        }
        println!("cargo:rustc-link-arg=-Wl,-weak_framework,ScreenCaptureKit");
        println!("cargo:rerun-if-changed=src/screen_recording.m");
    }
    tauri_build::build()
}
