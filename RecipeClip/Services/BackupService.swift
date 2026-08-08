import Foundation
import SwiftData

struct RecipeClipBackup: Codable, Equatable {
    let schemaVersion: Int
    let exportedAt: Date
    let recipes: [RecipeRecord]
    let shoppingItems: [ShoppingItemRecord]

    struct RecipeRecord: Codable, Equatable {
        let id: UUID
        let title: String
        let videoURL: String
        let channelName: String
        let thumbnailURL: String?
        let thumbnailData: Data?
        let memo: String
        let isFavorite: Bool
        let isDraft: Bool
        let createdAt: Date
        let updatedAt: Date
        let metadataUpdatedAt: Date?
        let ingredients: [IngredientRecord]
        let cookingSteps: [CookingStepRecord]
    }

    struct IngredientRecord: Codable, Equatable {
        let id: UUID
        let name: String
        let amount: String
        let sortOrder: Int
    }

    struct CookingStepRecord: Codable, Equatable {
        let id: UUID
        let text: String
        let sortOrder: Int
    }

    struct ShoppingItemRecord: Codable, Equatable {
        let id: UUID
        let name: String
        let amount: String
        let isPurchased: Bool
        let sourceRecipeID: UUID?
        let sourceRecipeTitle: String?
        let createdAt: Date
    }
}

enum BackupServiceError: LocalizedError {
    case unsupportedVersion
    case invalidContents

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion:
            return String(localized: "このバックアップは、このバージョンのアプリでは読み込めないよ。")
        case .invalidContents:
            return String(localized: "バックアップの内容を確認できなかったよ。")
        }
    }
}

@MainActor
enum BackupService {
    static let currentSchemaVersion = 1

    static func makeBackup(from context: ModelContext, date: Date = .now) throws -> RecipeClipBackup {
        let recipes = try context.fetch(FetchDescriptor<Recipe>())
        let shoppingItems = try context.fetch(FetchDescriptor<ShoppingItem>())

        return RecipeClipBackup(
            schemaVersion: currentSchemaVersion,
            exportedAt: date,
            recipes: recipes.map { recipe in
                RecipeClipBackup.RecipeRecord(
                    id: recipe.id,
                    title: recipe.title,
                    videoURL: recipe.videoURL,
                    channelName: recipe.channelName,
                    thumbnailURL: recipe.thumbnailURL,
                    thumbnailData: recipe.thumbnailData,
                    memo: recipe.memo,
                    isFavorite: recipe.isFavorite,
                    isDraft: recipe.isDraft,
                    createdAt: recipe.createdAt,
                    updatedAt: recipe.updatedAt,
                    metadataUpdatedAt: recipe.metadataUpdatedAt,
                    ingredients: recipe.sortedIngredients.map {
                        .init(id: $0.id, name: $0.name, amount: $0.amount, sortOrder: $0.sortOrder)
                    },
                    cookingSteps: recipe.sortedCookingSteps.map {
                        .init(id: $0.id, text: $0.text, sortOrder: $0.sortOrder)
                    }
                )
            },
            shoppingItems: shoppingItems.map {
                .init(
                    id: $0.id,
                    name: $0.name,
                    amount: $0.amount,
                    isPurchased: $0.isPurchased,
                    sourceRecipeID: $0.sourceRecipeID,
                    sourceRecipeTitle: $0.sourceRecipeTitle,
                    createdAt: $0.createdAt
                )
            }
        )
    }

    static func encode(_ backup: RecipeClipBackup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    static func decode(_ data: Data) throws -> RecipeClipBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let backup = try decoder.decode(RecipeClipBackup.self, from: data)
        guard backup.schemaVersion == currentSchemaVersion else {
            throw BackupServiceError.unsupportedVersion
        }
        guard backup.recipes.allSatisfy({
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && (try? YouTubeURLNormalizer.normalize($0.videoURL)) != nil
        }), backup.shoppingItems.allSatisfy({
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else {
            throw BackupServiceError.invalidContents
        }
        return backup
    }

    static func restore(_ backup: RecipeClipBackup, into context: ModelContext) throws {
        guard backup.schemaVersion == currentSchemaVersion else {
            throw BackupServiceError.unsupportedVersion
        }

        try context.fetch(FetchDescriptor<Recipe>()).forEach(context.delete)
        try context.fetch(FetchDescriptor<ShoppingItem>()).forEach(context.delete)

        for record in backup.recipes {
            let recipe = Recipe(
                id: record.id,
                title: record.title,
                videoURL: record.videoURL,
                channelName: record.channelName,
                thumbnailURL: record.thumbnailURL,
                thumbnailData: record.thumbnailData,
                memo: record.memo,
                isFavorite: record.isFavorite,
                isDraft: record.isDraft,
                ingredients: record.ingredients.map {
                    Ingredient(id: $0.id, name: $0.name, amount: $0.amount, sortOrder: $0.sortOrder)
                },
                cookingSteps: record.cookingSteps.map {
                    CookingStep(id: $0.id, text: $0.text, sortOrder: $0.sortOrder)
                },
                createdAt: record.createdAt,
                updatedAt: record.updatedAt,
                metadataUpdatedAt: record.metadataUpdatedAt
            )
            context.insert(recipe)
        }

        for record in backup.shoppingItems {
            context.insert(ShoppingItem(
                id: record.id,
                name: record.name,
                amount: record.amount,
                isPurchased: record.isPurchased,
                sourceRecipeID: record.sourceRecipeID,
                sourceRecipeTitle: record.sourceRecipeTitle,
                createdAt: record.createdAt
            ))
        }

        try context.save()
        NotificationCenter.default.post(name: .recipeClipBackupDidRestore, object: nil)
    }
}

extension Notification.Name {
    static let recipeClipBackupDidRestore = Notification.Name("recipeClipBackupDidRestore")
}
