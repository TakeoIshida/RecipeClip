import Foundation
import SwiftData

struct ShoppingListAddResult: Equatable {
    let addedCount: Int
    let updatedCount: Int

    var affectedCount: Int { addedCount + updatedCount }
}

enum ShoppingListService {
    @MainActor
    static func addIngredients(from recipe: Recipe, to context: ModelContext) throws -> ShoppingListAddResult {
        let ingredients = recipe.sortedIngredients.compactMap { ingredient -> (String, String)? in
            let name = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return (name, ingredient.amount.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return try add(ingredients, from: recipe, to: context)
    }

    @MainActor
    static func addIngredient(
        _ ingredient: Ingredient,
        from recipe: Recipe,
        to context: ModelContext
    ) throws -> ShoppingListAddResult {
        let name = ingredient.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ShoppingListError.emptyName }
        let amount = ingredient.amount.trimmingCharacters(in: .whitespacesAndNewlines)
        return try add([(name, amount)], from: recipe, to: context)
    }

    @MainActor
    private static func add(
        _ ingredients: [(name: String, amount: String)],
        from recipe: Recipe,
        to context: ModelContext
    ) throws -> ShoppingListAddResult {
        let existingItems = try context.fetch(FetchDescriptor<ShoppingItem>())
        var itemsByName: [String: ShoppingItem] = [:]
        for item in existingItems where item.sourceRecipeID == recipe.id {
            itemsByName[normalizedName(item.name)] = item
        }

        var addedCount = 0
        var updatedCount = 0
        for (name, amount) in ingredients {
            let key = normalizedName(name)
            if let existing = itemsByName[key] {
                existing.name = name
                existing.amount = amount
                existing.sourceRecipeTitle = recipe.title
                existing.isPurchased = false
                updatedCount += 1
            } else {
                let item = ShoppingItem(
                    name: name,
                    amount: amount,
                    sourceRecipeID: recipe.id,
                    sourceRecipeTitle: recipe.title
                )
                context.insert(item)
                itemsByName[key] = item
                addedCount += 1
            }
        }

        try context.save()
        return ShoppingListAddResult(addedCount: addedCount, updatedCount: updatedCount)
    }

    @MainActor
    static func addManualItem(name: String, amount: String, to context: ModelContext) throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw ShoppingListError.emptyName }
        context.insert(ShoppingItem(
            name: cleanName,
            amount: amount.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        try context.save()
    }

    @MainActor
    static func deletePurchased(from context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<ShoppingItem>())
        items.filter(\.isPurchased).forEach(context.delete)
        try context.save()
    }

    @MainActor
    static func deleteAll(from context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<ShoppingItem>())
        items.forEach(context.delete)
        try context.save()
    }

    private static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .widthInsensitive], locale: .current)
    }
}

enum ShoppingListError: LocalizedError {
    case emptyName

    var errorDescription: String? {
        "材料名を入力してね。"
    }
}
