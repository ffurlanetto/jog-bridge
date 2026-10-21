import Foundation
@testable import jog_bridge

/// Converts "90 0A 7F" into bytes.
func bytes(_ hexString: String) -> [UInt8] {
    hexString.split(separator: " ").compactMap { UInt8($0, radix: 16) }
}

/// A 38-byte all-zero frame, with forced bytes and a sequence counter.
func makeFrame(_ overrides: [Int: UInt8] = [:], counter: UInt8 = 0) -> [UInt8] {
    var frame = [UInt8](repeating: 0, count: HerculesFrameDecoder.frameLength)
    for (index, value) in overrides { frame[index] = value }
    frame[HerculesFrameDecoder.frameLength - 1] = counter
    return frame
}

/// Repository root, derived from this file's location (Tests/jog-bridgeTests/).
let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

/// Loads a JSON file from the Fixtures folder.
func loadFixture<T: Decodable>(_ name: String, as type: T.Type = T.self) throws -> T {
    guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
        throw FixtureError.missing(name)
    }
    return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
}

enum FixtureError: Error { case missing(String) }

/// Waits until a condition becomes true (CoreMIDI callbacks arrive on another thread).
func waitUntil(timeout: Duration = .seconds(3), _ condition: () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}
