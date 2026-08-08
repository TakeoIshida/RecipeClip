import XCTest
@testable import RecipeClip

final class YouTubeServiceTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.handler = nil
        super.tearDown()
    }

    func testFetchesMetadataAndThumbnail() async throws {
        URLProtocolStub.handler = { request in
            if request.url?.host == "www.youtube.com" {
                let body = #"{"title":"肉じゃが","author_name":"料理チャンネル","thumbnail_url":"https://img.youtube.com/thumb.jpg"}"#.data(using: .utf8)!
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
            }
            let image = Data([0x01, 0x02, 0x03])
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, image)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let service = YouTubeService(session: URLSession(configuration: configuration))

        let metadata = try await service.fetchMetadata(for: "https://youtu.be/abc123")

        XCTAssertEqual(metadata.title, "肉じゃが")
        XCTAssertEqual(metadata.channelName, "料理チャンネル")
        XCTAssertEqual(metadata.canonicalURL.absoluteString, "https://www.youtube.com/watch?v=abc123")
        XCTAssertEqual(metadata.thumbnailData, Data([0x01, 0x02, 0x03]))
    }

    func testBadResponseThrowsManualEntryError() async {
        URLProtocolStub.handler = { request in
            (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let service = YouTubeService(session: URLSession(configuration: configuration))

        do {
            _ = try await service.fetchMetadata(for: "https://youtu.be/deleted")
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? YouTubeError, .invalidResponse)
        }
    }
}

final class RecipeAutoFillTests: XCTestCase {
    func testRuleParserExtractsIngredientsStepsAndMemo() {
        let description = """
        【材料】
        ・じゃがいも 2個
        ・牛肉：200g

        【作り方】
        1. じゃがいもを切る
        2. 牛肉と一緒に煮る

        【ポイント】
        弱火で煮込む
        """

        let result = RecipeRuleParser.parse(description, fallbackTitle: "簡単肉じゃが")

        XCTAssertEqual(result.title, "簡単肉じゃが")
        XCTAssertEqual(result.ingredients.count, 2)
        XCTAssertEqual(result.ingredients[0].name, "じゃがいも")
        XCTAssertEqual(result.ingredients[0].amount, "2個")
        XCTAssertEqual(result.ingredients[1].name, "牛肉")
        XCTAssertEqual(result.ingredients[1].amount, "200g")
        XCTAssertEqual(result.steps, ["じゃがいもを切る", "牛肉と一緒に煮る"])
        XCTAssertEqual(result.memo, "弱火で煮込む")
        XCTAssertEqual(result.method, .ruleBased)
    }

    func testEnglishDescriptionParsing() {
        let description = """
        Ingredients
        - 2 cups flour
        - olive oil 2 tbsp
        - salt to taste

        Instructions
        1. Mix the flour and salt.
        2. Add the olive oil and knead.

        Tips
        Rest the dough for 10 minutes.
        """

        let result = RecipeRuleParser.parse(description, fallbackTitle: "Simple Flatbread")

        XCTAssertEqual(result.title, "Simple Flatbread")
        XCTAssertEqual(result.ingredients.count, 3)
        XCTAssertEqual(result.ingredients[0], .init(name: "flour", amount: "2 cups"))
        XCTAssertEqual(result.ingredients[1], .init(name: "olive oil", amount: "2 tbsp"))
        XCTAssertEqual(result.ingredients[2], .init(name: "salt", amount: "to taste"))
        XCTAssertEqual(result.steps, ["Mix the flour and salt.", "Add the olive oil and knead."])
        XCTAssertEqual(result.memo, "Rest the dough for 10 minutes.")
    }
}

private final class URLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.unknown) }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
