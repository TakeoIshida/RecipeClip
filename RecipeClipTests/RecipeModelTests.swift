import SwiftData
import XCTest
@testable import RecipeClip

final class RecipeModelTests: XCTestCase {
    func testInMemoryContainerPersistsOrderedRecipeContent() throws {
        let container = try SharedModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let recipe = Recipe(
            title: "親子丼",
            videoURL: "https://www.youtube.com/watch?v=abc",
            channelName: "ごはん研究所",
            ingredients: [
                Ingredient(name: "卵", amount: "2個", sortOrder: 1),
                Ingredient(name: "鶏肉", amount: "150g", sortOrder: 0)
            ],
            cookingSteps: [
                CookingStep(text: "卵を入れる", sortOrder: 1),
                CookingStep(text: "鶏肉を煮る", sortOrder: 0)
            ]
        )
        context.insert(recipe)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Recipe>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].sortedIngredients.map(\.name), ["鶏肉", "卵"])
        XCTAssertEqual(fetched[0].sortedCookingSteps.map(\.text), ["鶏肉を煮る", "卵を入れる"])
    }

    func testSearchMatchesTitleChannelAndIngredient() {
        let recipe = Recipe(
            title: "カレー",
            videoURL: "https://www.youtube.com/watch?v=abc",
            channelName: "週末キッチン",
            ingredients: [Ingredient(name: "じゃがいも", amount: "2個", sortOrder: 0)]
        )

        XCTAssertTrue(RecipeFiltering.matches(recipe, query: "カレー"))
        XCTAssertTrue(RecipeFiltering.matches(recipe, query: "キッチン"))
        XCTAssertTrue(RecipeFiltering.matches(recipe, query: "じゃが"))
        XCTAssertFalse(RecipeFiltering.matches(recipe, query: "パスタ"))
    }
}
