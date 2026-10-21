import AppKit
import SwiftUI
import Testing
@testable import jog_bridge_panel

/// Builds the view for every state without a window. This is a smoke test (the view does not
/// crash and has a real size), not a visual check — but set JOG_BRIDGE_RENDER_DIR to also get
/// a PNG of each state to look at.
@MainActor
struct StatusViewRenderTests {
    private struct FixedProbe: BridgeProbing {
        let value: BridgeSnapshot
        func snapshot() async -> BridgeSnapshot { value }
    }

    private static let cases: [(name: String, snapshot: BridgeSnapshot)] = [
        ("ok", .fixture()),
        ("console-unplugged", .fixture(usb: false, log: LogLine.log(LogLine.started, LogLine.waiting))),
        ("console-held", .fixture(log: LogLine.log(LogLine.started, LogLine.claimFailed, LogLine.waiting))),
        ("stopped", .fixture(service: .crashed)),
        ("needs-approval", .fixture(service: .notLoaded, approval: .requiresApproval, midi: false)),
        ("not-installed", .fixture(installed: false, service: .notLoaded, approval: .unknown, midi: false)),
    ]

    @Test(arguments: StatusViewRenderTests.cases.map(\.name))
    func rendersEveryState(name: String) throws {
        let snapshot = try #require(Self.cases.first { $0.name == name }?.snapshot)
        let view = StatusView(probe: FixedProbe(value: snapshot), actions: BridgeActions(),
                              initialSnapshot: snapshot)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.nsImage)
        #expect(image.size.width > 400)
        #expect(image.size.height > 150)

        if let folder = ProcessInfo.processInfo.environment["JOG_BRIDGE_RENDER_DIR"],
           let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
            try png.write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(name).png"))
        }
    }
}
