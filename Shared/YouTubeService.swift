import Foundation

struct YouTubeMetadata: Equatable {
    let canonicalURL: URL
    let title: String
    let channelName: String
    let thumbnailURL: URL?
    let thumbnailData: Data?
}

enum YouTubeError: LocalizedError, Equatable {
    case invalidURL
    case unsupportedURL
    case missingVideoID
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return String(localized: "URLを確認してね。")
        case .unsupportedURL:
            return String(localized: "YouTubeの動画URLを入力してね。")
        case .missingVideoID:
            return String(localized: "動画IDを読み取れなかったよ。")
        case .invalidResponse:
            return String(localized: "動画情報を取得できなかったよ。料理名とチャンネル名を手入力できるよ。")
        }
    }
}

enum YouTubeURLNormalizer {
    static func normalize(_ rawValue: String) throws -> URL {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw YouTubeError.invalidURL }
        if !value.contains("://") {
            value = "https://" + value
        }

        guard let components = URLComponents(string: value),
              let rawHost = components.host?.lowercased() else {
            throw YouTubeError.invalidURL
        }

        let host = rawHost
            .replacingOccurrences(of: "www.", with: "")
            .replacingOccurrences(of: "m.", with: "")

        let videoID: String?
        if host == "youtu.be" {
            videoID = components.path.split(separator: "/").first.map(String.init)
        } else if host == "youtube.com" || host == "youtube-nocookie.com" {
            let pathParts = components.path.split(separator: "/").map(String.init)
            if components.path == "/watch" {
                videoID = components.queryItems?.first(where: { $0.name == "v" })?.value
            } else if let first = pathParts.first,
                      ["shorts", "embed", "live"].contains(first),
                      pathParts.count >= 2 {
                videoID = pathParts[1]
            } else {
                videoID = nil
            }
        } else {
            throw YouTubeError.unsupportedURL
        }

        guard let videoID,
              !videoID.isEmpty,
              videoID.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil else {
            throw YouTubeError.missingVideoID
        }

        var canonical = URLComponents(string: "https://www.youtube.com/watch")!
        canonical.queryItems = [URLQueryItem(name: "v", value: videoID)]
        guard let url = canonical.url else { throw YouTubeError.invalidURL }
        return url
    }
}

enum ShareDraftValidator {
    static func canSave(title: String, videoURL: String) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (try? YouTubeURLNormalizer.normalize(videoURL)) != nil
    }
}

protocol YouTubeMetadataFetching {
    func fetchMetadata(for rawURL: String) async throws -> YouTubeMetadata
}

struct YouTubeService: YouTubeMetadataFetching {
    private let session: URLSession

    init(session: URLSession? = nil) {
        self.session = session ?? PrivacyRespectingURLSession.make()
    }

    func fetchMetadata(for rawURL: String) async throws -> YouTubeMetadata {
        let canonicalURL = try YouTubeURLNormalizer.normalize(rawURL)
        var components = URLComponents(string: "https://www.youtube.com/oembed")!
        components.queryItems = [
            URLQueryItem(name: "url", value: canonicalURL.absoluteString),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let endpoint = components.url else { throw YouTubeError.invalidURL }

        let (data, response) = try await session.data(from: endpoint)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode,
              let payload = try? JSONDecoder().decode(OEmbedPayload.self, from: data) else {
            throw YouTubeError.invalidResponse
        }

        let thumbnailURL = payload.thumbnailURL.flatMap(URL.init(string:))
        let thumbnailData: Data?
        if let thumbnailURL,
           let result = try? await session.data(from: thumbnailURL),
           let httpResponse = result.1 as? HTTPURLResponse,
           200..<300 ~= httpResponse.statusCode {
            thumbnailData = result.0
        } else {
            thumbnailData = nil
        }

        return YouTubeMetadata(
            canonicalURL: canonicalURL,
            title: payload.title,
            channelName: payload.authorName,
            thumbnailURL: thumbnailURL,
            thumbnailData: thumbnailData
        )
    }
}

enum PrivacyRespectingURLSession {
    static func make() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }
}

private struct OEmbedPayload: Decodable {
    let title: String
    let authorName: String
    let thumbnailURL: String?

    enum CodingKeys: String, CodingKey {
        case title
        case authorName = "author_name"
        case thumbnailURL = "thumbnail_url"
    }
}
