import Foundation
import SwiftData

enum SharedModelContainer {
    static let appGroupIdentifier = "group.com.ishidatakeo.RecipeClip"
    static let currentPrivacyPolicyVersion = 1
    static let privacyPolicyURL = URL(string: "https://takeoishida.github.io/RecipeClip/privacy-policy.html")!
    private static let storeName = "RecipeClip.store"
    private static let acceptedPrivacyPolicyVersionKey = "acceptedPrivacyPolicyVersion"
    private static let privacyConsentMarkerName = ".privacy-consent-version"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    static var appGroupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private static var privacyConsentMarkerURL: URL? {
        appGroupContainerURL?
            .appendingPathComponent(privacyConsentMarkerName, isDirectory: false)
    }

    static var hasAcceptedCurrentPrivacyPolicy: Bool {
        let defaultsVersion = sharedDefaults?.integer(forKey: acceptedPrivacyPolicyVersionKey) ?? 0
        let localDefaultsVersion = UserDefaults.standard.integer(forKey: acceptedPrivacyPolicyVersionKey)
        let markerVersion = privacyConsentMarkerURL
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { String(data: $0, encoding: .utf8) }
            .flatMap(Int.init) ?? 0

        return max(defaultsVersion, localDefaultsVersion, markerVersion) >= currentPrivacyPolicyVersion
    }

    static func acceptCurrentPrivacyPolicy() {
        sharedDefaults?.set(currentPrivacyPolicyVersion, forKey: acceptedPrivacyPolicyVersionKey)
        UserDefaults.standard.set(currentPrivacyPolicyVersion, forKey: acceptedPrivacyPolicyVersionKey)

        guard let markerURL = privacyConsentMarkerURL,
              let marker = String(currentPrivacyPolicyVersion).data(using: .utf8) else {
            return
        }
        try? marker.write(to: markerURL, options: .atomic)
    }

    /// Rewrites consent from either the app's local defaults or App Group defaults.
    /// The file marker gives the Share Extension a second cross-process source.
    static func repairPrivacyPolicyConsentSharingIfNeeded() {
        guard hasAcceptedCurrentPrivacyPolicy else { return }
        acceptCurrentPrivacyPolicy()
    }

    static var schema: Schema {
        Schema([Recipe.self, Ingredient.self, CookingStep.self, ShoppingItem.self])
    }

    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration

        if inMemory {
            configuration = ModelConfiguration(
                "RecipeClipTests",
                schema: schema,
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
        } else if let groupURL = appGroupContainerURL {
            configuration = ModelConfiguration(
                "RecipeClip",
                schema: schema,
                url: groupURL.appendingPathComponent(storeName),
                cloudKitDatabase: .none
            )
        } else {
            // Previews and unsigned simulator builds do not always expose App Groups.
            configuration = ModelConfiguration(
                "RecipeClip",
                schema: schema,
                cloudKitDatabase: .none
            )
        }

        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

struct PendingShareDraft: Codable, Equatable {
    let id: UUID
    let title: String
    let videoURL: String
    let channelName: String
    let thumbnailURL: String?
    let thumbnailData: Data?
    let createdAt: Date
    let metadataUpdatedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        videoURL: String,
        channelName: String = "",
        thumbnailURL: String? = nil,
        thumbnailData: Data? = nil,
        createdAt: Date = .now,
        metadataUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.videoURL = videoURL
        self.channelName = channelName
        self.thumbnailURL = thumbnailURL
        self.thumbnailData = thumbnailData
        self.createdAt = createdAt
        self.metadataUpdatedAt = metadataUpdatedAt
    }
}

enum PendingShareDraftStoreError: LocalizedError {
    case appGroupUnavailable

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return String(localized: "アプリと共有する保存場所を開けませんでした。動画レシピ帳本体を一度開いてから、もう一度試してください。")
        }
    }
}

enum PendingShareDraftStore {
    private static let directoryName = "PendingShareDrafts"

    static func enqueue(_ draft: PendingShareDraft) throws {
        guard let containerURL = SharedModelContainer.appGroupContainerURL else {
            throw PendingShareDraftStoreError.appGroupUnavailable
        }
        try enqueue(draft, in: containerURL)
    }

    static func enqueue(_ draft: PendingShareDraft, in containerURL: URL) throws {
        let directoryURL = containerURL.appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent(draft.id.uuidString).appendingPathExtension("json")
        let data = try JSONEncoder().encode(draft)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    @discardableResult
    static func importPendingDrafts(into modelContext: ModelContext) throws -> Int {
        guard let containerURL = SharedModelContainer.appGroupContainerURL else {
            // The Share Extension reports this problem when the user actually
            // saves. Avoid showing an import alert on every main-app launch.
            return 0
        }
        return try importPendingDrafts(into: modelContext, from: containerURL)
    }

    @discardableResult
    static func importPendingDrafts(into modelContext: ModelContext, from containerURL: URL) throws -> Int {
        let directoryURL = containerURL.appendingPathComponent(directoryName, isDirectory: true)
        guard FileManager.default.fileExists(atPath: directoryURL.path) else { return 0 }

        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "json" }

        var importedFiles: [URL] = []
        for fileURL in fileURLs {
            guard let data = try? Data(contentsOf: fileURL),
                  let draft = try? JSONDecoder().decode(PendingShareDraft.self, from: data),
                  (try? YouTubeURLNormalizer.normalize(draft.videoURL)) != nil else {
                continue
            }

            let draftID = draft.id
            let descriptor = FetchDescriptor<Recipe>(predicate: #Predicate { $0.id == draftID })
            if try modelContext.fetchCount(descriptor) == 0 {
                modelContext.insert(
                    Recipe(
                        id: draft.id,
                        title: draft.title,
                        videoURL: draft.videoURL,
                        channelName: draft.channelName,
                        thumbnailURL: draft.thumbnailURL,
                        thumbnailData: draft.thumbnailData,
                        isDraft: true,
                        createdAt: draft.createdAt,
                        updatedAt: draft.createdAt,
                        metadataUpdatedAt: draft.metadataUpdatedAt
                    )
                )
            }
            importedFiles.append(fileURL)
        }

        guard !importedFiles.isEmpty else { return 0 }
        try modelContext.save()
        for fileURL in importedFiles {
            try FileManager.default.removeItem(at: fileURL)
        }
        return importedFiles.count
    }
}
