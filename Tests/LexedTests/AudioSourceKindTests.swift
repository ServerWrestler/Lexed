import XCTest
@testable import Lexed

final class AudioSourceKindTests: XCTestCase {

    func testHasBothSources() {
        XCTAssertEqual(Set(AudioSourceKind.allCases), [.systemAudio, .microphone])
    }

    /// `audioSourceKind` is persisted in UserDefaults by raw value, so these
    /// strings must stay stable across releases.
    func testRawValuesAreStable() {
        XCTAssertEqual(AudioSourceKind.systemAudio.rawValue, "systemAudio")
        XCTAssertEqual(AudioSourceKind.microphone.rawValue, "microphone")
        XCTAssertEqual(AudioSourceKind(rawValue: "systemAudio"), .systemAudio)
        XCTAssertNil(AudioSourceKind(rawValue: "bogus"))
    }

    func testEveryCaseHasLabelAndHelp() {
        for kind in AudioSourceKind.allCases {
            XCTAssertFalse(kind.label.isEmpty)
            XCTAssertFalse(kind.help.isEmpty)
        }
    }
}
