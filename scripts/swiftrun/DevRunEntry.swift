// Compiled into the `OpenClip` target by scripts/swiftrun/prepare.py.
import AppKit

@_cdecl("openclip_dev_run_main")
public func openclipDevRunMain() {
    MainActor.assumeIsolated {
        NSApplication.shared.setActivationPolicy(.accessory)
        OpenClipApp.main()
    }
}
