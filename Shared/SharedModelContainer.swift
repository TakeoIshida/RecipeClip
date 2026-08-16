import Foundation
import SwiftData

enum SharedModelContainer {
    static let appGroupIdentifier = "group.com.ishidatakeo.RecipeClip"
    static let currentPrivacyPolicyVersion = 1
    private static let storeName = "RecipeClip.store"
    private static let acceptedPrivacyPolicyVersionKey = "acceptedPrivacyPolicyVersion"
    private static let privacyConsentMarkerName = ".privacy-consent-version"

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private static var privacyConsentMarkerURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(privacyConsentMarkerName, isDirectory: false)
    }

    static var hasAcceptedCurrentPrivacyPolicy: Bool {
        let defaultsVersion = sharedDefaults?.integer(forKey: acceptedPrivacyPolicyVersionKey) ?? 0
        let markerVersion = privacyConsentMarkerURL
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { String(data: $0, encoding: .utf8) }
            .flatMap(Int.init) ?? 0

        return max(defaultsVersion, markerVersion) >= currentPrivacyPolicyVersion
    }

    static func acceptCurrentPrivacyPolicy() {
        sharedDefaults?.set(currentPrivacyPolicyVersion, forKey: acceptedPrivacyPolicyVersionKey)

        guard let markerURL = privacyConsentMarkerURL,
              let marker = String(currentPrivacyPolicyVersion).data(using: .utf8) else {
            return
        }
        try? marker.write(to: markerURL, options: .atomic)
    }

    /// Older builds only persisted consent in App Group UserDefaults. Rewriting it
    /// on app launch also creates a file marker that the Share Extension can read
    /// reliably across process boundaries.
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
        } else if let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) {
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
