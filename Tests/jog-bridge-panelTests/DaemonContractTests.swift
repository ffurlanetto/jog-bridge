import Foundation
import Testing
@testable import jog_bridge_panel

/// The panel depends on text the daemon logs and on identifiers the installer ships. These
/// tests fail when one side changes without the other.
struct DaemonContractTests {
    private func daemonSources() throws -> String {
        let folder = repositoryRoot.appendingPathComponent("Sources/jog-bridge")
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        return try files.map { try String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n")
    }

    @Test(arguments: DaemonLogMarkers.all)
    func daemonStillLogsTheMarker(marker: String) throws {
        #expect(try daemonSources().contains(marker), "the daemon no longer logs “\(marker)”")
    }

    @Test func panelAndDaemonAgreeOnThePortAndTheDevice() throws {
        let sources = try daemonSources()
        #expect(sources.contains("var portName = \"\(BridgeConstants.portName)\""))
        #expect(sources.contains("var vendorID: UInt16 = 0x06F8"))
        #expect(sources.contains("var productID: UInt16 = 0xB105"))
        #expect(BridgeConstants.vendorID == 0x06F8)
        #expect(BridgeConstants.productID == 0xB105)
    }

    @Test func panelAndInstallerAgreeOnTheAgentLabelAndLog() throws {
        let url = repositoryRoot.appendingPathComponent("local.jog-bridge.plist")
        let plist = try #require(
            try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        #expect(plist["Label"] as? String == BridgeConstants.label)
        #expect(plist["StandardErrorPath"] as? String == BridgeConstants.logPath)
        #expect(plist["StandardOutPath"] as? String == BridgeConstants.logPath)
        #expect(BridgeConstants.plistURL.lastPathComponent == "\(BridgeConstants.label).plist")
    }
}
