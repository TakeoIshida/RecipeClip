import XCTest
@testable import RecipeClip

final class YouTubeURLNormalizerTests: XCTestCase {
    func testSupportedURLFormatsBecomeCanonicalWatchURL() throws {
        let expected = "https://www.youtube.com/watch?v=abc_123-XYZ"
        let values = [
            "https://www.youtube.com/watch?v=abc_123-XYZ&t=30",
            "https://youtu.be/abc_123-XYZ?si=share",
            "https://youtube.com/shorts/abc_123-XYZ",
            "https://www.youtube.com/embed/abc_123-XYZ",
            "https://www.youtube-nocookie.com/embed/abc_123-XYZ",
            "youtube.com/live/abc_123-XYZ"
        ]

        for value in values {
            XCTAssertEqual(try YouTubeURLNormalizer.normalize(value).absoluteString, expected)
        }
    }

    func testRejectsNonYouTubeURL() {
        XCTAssertThrowsError(try YouTubeURLNormalizer.normalize("https://example.com/watch?v=abc")) {
            XCTAssertEqual($0 as? YouTubeError, .unsupportedURL)
        }
    }

    func testRejectsURLWithoutVideoID() {
        XCTAssertThrowsError(try YouTubeURLNormalizer.normalize("https://youtube.com/watch")) {
            XCTAssertEqual($0 as? YouTubeError, .missingVideoID)
        }
    }

    func testShareDraftCanSaveWithManualTitleAndSharedURL() {
        XCTAssertTrue(
            ShareDraftValidator.canSave(
                title: "麻婆豆腐",
                videoURL: "https://youtu.be/abc_123-XYZ"
            )
        )
    }

    func testShareDraftRequiresBothTitleAndValidYouTubeURL() {
        XCTAssertFalse(
            ShareDraftValidator.canSave(
                title: "   ",
                videoURL: "https://youtu.be/abc_123-XYZ"
            )
        )
        XCTAssertFalse(
            ShareDraftValidator.canSave(
                title: "麻婆豆腐",
                videoURL: "https://example.com/video"
            )
        )
    }
}
