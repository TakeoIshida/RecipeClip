import Foundation
import SwiftData

enum SharedModelContainer {
    static let appGroupIdentifier = "group.com.ishidatakeo.RecipeClip"
    static let currentPrivacyPolicyVersion = 1
    private static let storeName = "RecipeClip.store"
    private static let acceptedPrivacyPolicyVersionKey = "acceptedPrivacyPolicyVersion"

    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static var hasAcceptedCurrentPrivacyPolicy: Bool {
        sharedDefaults.integer(forKey: acceptedPrivacyPolicyVersionKey) >= currentPrivacyPolicyVersion
    }

    static func acceptCurrentPrivacyPolicy() {
        sharedDefaults.set(currentPrivacyPolicyVersion, forKey: acceptedPrivacyPolicyVersionKey)
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
