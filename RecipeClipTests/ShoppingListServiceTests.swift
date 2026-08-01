import SwiftData
import XCTest
@testable import RecipeClip

@MainActor
final class ShoppingListServiceTests: XCTestCase {
    func testAddsAllIngredientsAndUpdatesSameRecipeWithoutDuplicates() throws {
        let container = try SharedModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let recipe = Recipe(
            title: "カレー",
            videoURL: "https://www.youtube.com/watch?v=abc",
            ingredients: [
                Ingredient(name: "じゃがいも", amount: "2個", sortOrder: 0),
                Ingredient(name: "玉ねぎ", amount: "1個", sortOrder: 1)
            ]
        )
        context.insert(recipe)

        let firstResult = try ShoppingListService.addIngredients(from: recipe, to: context)
        XCTAssertEqual(firstResult, ShoppingListAddResult(addedCount: 2, updatedCount: 0))

        recipe.ingredients.first(where: { $0.name == "じゃがいも" })?.amount = "3個"
        let secondResult = try ShoppingListService.addIngredients(from: recipe, to: context)
        let items = try context.fetch(FetchDescriptor<ShoppingItem>())

        XCTAssertEqual(secondResult, ShoppingListAddResult(addedCount: 0, updatedCount: 2))
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first(where: { $0.name == "じゃがいも" })?.amount, "3個")
        XCTAssertTrue(items.allSatisfy { !$0.isPurchased })
    }

    func testSameIngredientFromDifferentRecipesStaysSeparate() throws {
        let container = try SharedModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let first = Recipe(
            title: "カレー",
            videoURL: "https://www.youtube.com/watch?v=first",
            ingredients: [Ingredient(name: "玉ねぎ", amount: "1個", sortOrder: 0)]
        )
        let second = Recipe(
            title: "スープ",
            videoURL: "https://www.youtube.com/watch?v=second",
            ingredients: [Ingredient(name: "玉ねぎ", amount: "2個", sortOrder: 0)]
        )
        context.insert(first)
        context.insert(second)

        _ = try ShoppingListService.addIngredients(from: first, to: context)
        _ = try ShoppingListService.addIngredients(from: second, to: context)
        let items = try context.fetch(FetchDescriptor<ShoppingItem>())

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(Set(items.compactMap(\.sourceRecipeTitle)), Set(["カレー", "スープ"]))
    }

    func testAddsOneIngredientAndUpdatesItWithoutAddingTheOthers() throws {
        let container = try SharedModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let potato = Ingredient(name: "じゃがいも", amount: "2個", sortOrder: 0)
        let recipe = Recipe(
            title: "カレー",
            videoURL: "https://www.youtube.com/watch?v=single",
            ingredients: [
                potato,
                Ingredient(name: "玉ねぎ", amount: "1個", sortOrder: 1)
            ]
        )
        context.insert(recipe)

        let firstResult = try ShoppingListService.addIngredient(potato, from: recipe, to: context)
        var items = try context.fetch(FetchDescriptor<ShoppingItem>())
        XCTAssertEqual(firstResult, ShoppingListAddResult(addedCount: 1, updatedCount: 0))
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].name, "じゃがいも")

        items[0].isPurchased = true
        potato.amount = "3個"
        let secondResult = try ShoppingListService.addIngredient(potato, from: recipe, to: context)
        items = try context.fetch(FetchDescriptor<ShoppingItem>())

        XCTAssertEqual(secondResult, ShoppingListAddResult(addedCount: 0, updatedCount: 1))
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].amount, "3個")
        XCTAssertFalse(items[0].isPurchased)
    }

    func testManualItemsAndCleanupActionsPersist() throws {
        let container = try SharedModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        try ShoppingListService.addManualItem(name: "  牛乳  ", amount: " 1本 ", to: context)
        try ShoppingListService.addManualItem(name: "卵", amount: "6個", to: context)

        var items = try context.fetch(FetchDescriptor<ShoppingItem>())
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.allSatisfy { $0.sourceRecipeID == nil })
        XCTAssertEqual(items.first(where: { $0.name == "牛乳" })?.amount, "1本")

        items[0].isPurchased = true
        try context.save()
        try ShoppingListService.deletePurchased(from: context)
        items = try context.fetch(FetchDescriptor<ShoppingItem>())
        XCTAssertEqual(items.count, 1)

        try ShoppingListService.deleteAll(from: context)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ShoppingItem>()).isEmpty)
    }

    func testShoppingItemRemainsAfterSourceRecipeDeletion() throws {
        let container = try SharedModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let recipe = Recipe(
            title: "親子丼",
            videoURL: "https://www.youtube.com/watch?v=oyako",
            ingredients: [Ingredient(name: "卵", amount: "2個", sortOrder: 0)]
        )
        context.insert(recipe)
        _ = try ShoppingListService.addIngredients(from: recipe, to: context)

        context.delete(recipe)
        try context.save()
        let items = try context.fetch(FetchDescriptor<ShoppingItem>())

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].sourceRecipeTitle, "親子丼")
    }
}
