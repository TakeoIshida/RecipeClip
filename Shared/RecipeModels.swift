import Foundation
import SwiftData

@Model
final class Recipe {
    @Attribute(.unique) var id: UUID
    var title: String
    var videoURL: String
    var channelName: String
    var thumbnailURL: String?
    @Attribute(.externalStorage) var thumbnailData: Data?
    var memo: String
    var isFavorite: Bool
    var isDraft: Bool
    var createdAt: Date
    var updatedAt: Date
    var metadataUpdatedAt: Date?

    @Relationship(deleteRule: .cascade)
    var ingredients: [Ingredient]

    @Relationship(deleteRule: .cascade)
    var cookingSteps: [CookingStep]

    init(
        id: UUID = UUID(),
        title: String,
        videoURL: String,
        channelName: String = "",
        thumbnailURL: String? = nil,
        thumbnailData: Data? = nil,
        memo: String = "",
        isFavorite: Bool = false,
        isDraft: Bool = false,
        ingredients: [Ingredient] = [],
        cookingSteps: [CookingStep] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        metadataUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.videoURL = videoURL
        self.channelName = channelName
        self.thumbnailURL = thumbnailURL
        self.thumbnailData = thumbnailData
        self.memo = memo
        self.isFavorite = isFavorite
        self.isDraft = isDraft
        self.ingredients = ingredients
        self.cookingSteps = cookingSteps
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadataUpdatedAt = metadataUpdatedAt
    }

    var sortedIngredients: [Ingredient] {
        ingredients.sorted { $0.sortOrder < $1.sortOrder }
    }

    var sortedCookingSteps: [CookingStep] {
        cookingSteps.sorted { $0.sortOrder < $1.sortOrder }
    }
}

@Model
final class Ingredient {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: String
    var sortOrder: Int

    init(id: UUID = UUID(), name: String, amount: String = "", sortOrder: Int) {
        self.id = id
        self.name = name
        self.amount = amount
        self.sortOrder = sortOrder
    }
}

@Model
final class CookingStep {
    @Attribute(.unique) var id: UUID
    var text: String
    var sortOrder: Int

    init(id: UUID = UUID(), text: String, sortOrder: Int) {
        self.id = id
        self.text = text
        self.sortOrder = sortOrder
    }
}

@Model
final class ShoppingItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: String
    var isPurchased: Bool
    var sourceRecipeID: UUID?
    var sourceRecipeTitle: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        amount: String = "",
        isPurchased: Bool = false,
        sourceRecipeID: UUID? = nil,
        sourceRecipeTitle: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.isPurchased = isPurchased
        self.sourceRecipeID = sourceRecipeID
        self.sourceRecipeTitle = sourceRecipeTitle
        self.createdAt = createdAt
    }
}

enum RecipeFilter: String, CaseIterable, Identifiable {
    case all = "すべて"
    case favorites = "お気に入り"

    var id: Self { self }
}

enum RecipeFiltering {
    static func matches(_ recipe: Recipe, query: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return true }

        let searchableValues = [recipe.title, recipe.channelName]
            + recipe.ingredients.map(\.name)
        return searchableValues.contains {
            $0.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }
}
