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

    func testSearchMatchesAllRecipeText() {
        let recipe = Recipe(
            title: "カレー",
            videoURL: "https://www.youtube.com/watch?v=abc",
            channelName: "週末キッチン",
            memo: "辛さは控えめ",
            ingredients: [Ingredient(name: "じゃがいも", amount: "2個", sortOrder: 0)],
            cookingSteps: [CookingStep(text: "弱火で20分煮込む", sortOrder: 0)]
        )

        XCTAssertTrue(RecipeFiltering.matches(recipe, query: "カレー"))
        XCTAssertTrue(RecipeFiltering.matches(recipe, query: "キッチン"))
        XCTAssertTrue(RecipeFiltering.matches(recipe, query: "じゃが"))
        XCTAssertTrue(RecipeFiltering.matches(recipe, query: "2個"))
        XCTAssertTrue(RecipeFiltering.matches(recipe, query: "控えめ"))
        XCTAssertTrue(RecipeFiltering.matches(recipe, query: "20分"))
        XCTAssertFalse(RecipeFiltering.matches(recipe, query: "パスタ"))
    }

    func testRecipeSortOrdersRecipes() {
        let older = Recipe(
            title: "りんご",
            videoURL: "https://www.youtube.com/watch?v=older",
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 300)
        )
        let newer = Recipe(
            title: "カレー",
            videoURL: "https://www.youtube.com/watch?v=newer",
            createdAt: Date(timeIntervalSince1970: 200),
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        XCTAssertEqual(RecipeSort.newest.sort([older, newer]).map(\.title), ["カレー", "りんご"])
        XCTAssertEqual(RecipeSort.oldest.sort([older, newer]).map(\.title), ["りんご", "カレー"])
        XCTAssertEqual(RecipeSort.title.sort([older, newer]).map(\.title), ["カレー", "りんご"])
        XCTAssertEqual(RecipeSort.recentlyUpdated.sort([older, newer]).map(\.title), ["りんご", "カレー"])
    }

    func testPendingShareDraftIsImportedIntoRecipeStore() throws {
        let temporaryContainerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryContainerURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryContainerURL) }

        let draft = PendingShareDraft(
            title: "麻婆豆腐",
            videoURL: "https://www.youtube.com/watch?v=abc_123-XYZ",
            channelName: "山野辺"
        )
        try PendingShareDraftStore.enqueue(draft, in: temporaryContainerURL)

        let container = try SharedModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        XCTAssertEqual(
            try PendingShareDraftStore.importPendingDrafts(into: context, from: temporaryContainerURL),
            1
        )

        let recipes = try context.fetch(FetchDescriptor<Recipe>())
        XCTAssertEqual(recipes.count, 1)
        XCTAssertEqual(recipes[0].id, draft.id)
        XCTAssertEqual(recipes[0].title, "麻婆豆腐")
        XCTAssertEqual(recipes[0].channelName, "山野辺")
        XCTAssertTrue(recipes[0].isDraft)
        XCTAssertEqual(
            try PendingShareDraftStore.importPendingDrafts(into: context, from: temporaryContainerURL),
            0
        )
    }

    func testPendingShareImportRespectsFreeRecipeLimit() throws {
        let temporaryContainerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryContainerURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryContainerURL) }

        try PendingShareDraftStore.enqueue(
            PendingShareDraft(title: "カレー", videoURL: "https://youtu.be/abc123"),
            in: temporaryContainerURL
        )
        try PendingShareDraftStore.enqueue(
            PendingShareDraft(title: "パスタ", videoURL: "https://youtu.be/def456"),
            in: temporaryContainerURL
        )

        let container = try SharedModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        XCTAssertEqual(
            try PendingShareDraftStore.importPendingDrafts(
                into: context,
                from: temporaryContainerURL,
                maxNewRecipes: 1
            ),
            1
        )
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Recipe>()), 1)
        XCTAssertEqual(try PendingShareDraftStore.pendingDraftCount(in: temporaryContainerURL), 1)

        XCTAssertEqual(
            try PendingShareDraftStore.importPendingDrafts(
                into: context,
                from: temporaryContainerURL,
                maxNewRecipes: nil
            ),
            1
        )
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Recipe>()), 2)
        XCTAssertEqual(try PendingShareDraftStore.pendingDraftCount(in: temporaryContainerURL), 0)
    }
}
