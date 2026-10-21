import SwiftUI

/// The panel that opens when the user clicks Jog Bridge in /Applications. The daemon does the
/// real work in the background; this only shows whether it is running, and helps when it is not.
///
/// A single `Window` scene: closing the window quits the panel (the daemon is unaffected).
@main
struct JogBridgePanelApp: App {
    var body: some Scene {
        Window("Jog Bridge", id: "status") {
            StatusView(probe: LiveBridgeProbe(), actions: BridgeActions())
        }
        .windowResizability(.contentSize)
    }
}
