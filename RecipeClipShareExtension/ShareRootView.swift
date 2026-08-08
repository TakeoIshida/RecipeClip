import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ShareRootView: View {
    @Environment(\.modelContext) private var modelContext

    let extensionContext: NSExtensionContext?
    let onCancel: () -> Void
    let onComplete: () -> Void

    @State private var videoURL = ""
    @State private var title = ""
    @State private var channelName = ""
    @State private var thumbnailURL: String?
    @State private var thumbnailData: Data?
    @State private var metadataUpdatedAt: Date?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView("動画情報を取得中…")
                        Spacer()
                    }
                } else {
                    if thumbnailData != nil || thumbnailURL != nil {
                        RecipeThumbnail(data: thumbnailData, urlString: thumbnailURL)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .listRowInsets(EdgeInsets())
                    }

                    Section("動画情報") {
                        TextField("料理名", text: $title)
                        TextField("動画チャンネル", text: $channelName)
                        Text(videoURL)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    if let message {
                        Section {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("レシピに保存")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("下書き保存") { save() }
                        .disabled(!canSave || isSaving)
                }
            }
        }
        .task { await prepareSharedVideo() }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (try? YouTubeURLNormalizer.normalize(videoURL)) != nil
    }

    @MainActor
    private func prepareSharedVideo() async {
        defer { isLoading = false }

        do {
            guard SharedModelContainer.hasAcceptedCurrentPrivacyPolicy else {
                throw ShareError.consentRequired
            }
            let sharedValue = try await ShareItemLoader.youtubeURL(from: extensionContext)
            let canonicalURL = try YouTubeURLNormalizer.normalize(sharedValue)
            videoURL = canonicalURL.absoluteString

            do {
                let metadata = try await YouTubeService().fetchMetadata(for: sharedValue)
                title = metadata.title
                channelName = metadata.channelName
                thumbnailURL = metadata.thumbnailURL?.absoluteString
                thumbnailData = metadata.thumbnailData
                metadataUpdatedAt = .now
            } catch {
                message = String(localized: "動画情報を取得できなかったよ。料理名とチャンネル名を入力して保存できるよ。")
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private func save() {
        guard let canonicalURL = try? YouTubeURLNormalizer.normalize(videoURL) else { return }
        isSaving = true
        let recipe = Recipe(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            videoURL: canonicalURL.absoluteString,
            channelName: channelName.trimmingCharacters(in: .whitespacesAndNewlines),
            thumbnailURL: thumbnailURL,
            thumbnailData: thumbnailData,
            isDraft: true,
            metadataUpdatedAt: metadataUpdatedAt
        )
        modelContext.insert(recipe)

        do {
            try modelContext.save()
            onComplete()
        } catch {
            isSaving = false
            message = String(localized: "保存できなかったよ。もう一度試してね。")
        }
    }
}

private enum ShareItemLoader {
    static func youtubeURL(from context: NSExtensionContext?) async throws -> String {
        var providers: [NSItemProvider] = []
        for item in context?.inputItems.compactMap({ $0 as? NSExtensionItem }) ?? [] {
            providers.append(contentsOf: item.attachments ?? [])
        }

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let value = try? await load(provider, type: UTType.url.identifier),
               let string = stringValue(from: value),
               (try? YouTubeURLNormalizer.normalize(string)) != nil {
                return string
            }
        }

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
               let value = try? await load(provider, type: UTType.plainText.identifier),
               let string = stringValue(from: value),
               let candidate = firstURL(in: string),
               (try? YouTubeURLNormalizer.normalize(candidate)) != nil {
                return candidate
            }
        }

        throw ShareError.noYouTubeURL
    }

    private static func load(_ provider: NSItemProvider, type: String) async throws -> NSSecureCoding? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: item)
                }
            }
        }
    }

    private static func stringValue(from item: NSSecureCoding?) -> String? {
        if let url = item as? URL { return url.absoluteString }
        if let string = item as? String { return string }
        if let attributedString = item as? NSAttributedString { return attributedString.string }
        return nil
    }

    private static func firstURL(in text: String) -> String? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        return detector.firstMatch(in: text, range: range)?.url?.absoluteString
    }
}
