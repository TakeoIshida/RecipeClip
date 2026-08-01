import SwiftData
import XCTest
@testable import RecipeClip

@MainActor
final class BackupServiceTests: XCTestCase {
    func testBackupRoundTripPreservesAllRecipeAndShoppingFields() throws {
        let container = try SharedModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        let recipeID = UUID()
        let thumbnail = Data([0x01, 0x02, 0x03])
        let recipe = Recipe(
            id: recipeID,
            title: "肉じゃが",
            videoURL: "https://www.youtube.com/watch?v=abcdefghijk",
            channelName: "料理チャンネル",
            thumbnailURL: "https://example.com/image.jpg",
            thumbnailData: thumbnail,
            memo: "弱火で煮る",
            isFavorite: true,
            ingredients: [Ingredient(name: "じゃがいも", amount: "3個", sortOrder: 0)],
            cookingSteps: [CookingStep(text: "材料を切る", sortOrder: 0)]
        )
        context.insert(recipe)
        context.insert(ShoppingItem(
            name: "じゃがいも",
            amount: "3個",
            sourceRecipeID: recipeID,
            sourceRecipeTitle: "肉じゃが"
        ))
        try context.save()

        let original = try BackupService.makeBackup(from: context)
        let decoded = try BackupService.decode(BackupService.encode(original))

        XCTAssertEqual(decoded.schemaVersion, original.schemaVersion)
        XCTAssertEqual(decoded.recipes.count, 1)
        XCTAssertEqual(decoded.shoppingItems.count, 1)
        XCTAssertEqual(decoded.recipes.first?.id, recipeID)
        XCTAssertEqual(decoded.recipes.first?.title, "肉じゃが")
        XCTAssertEqual(decoded.recipes.first?.memo, "弱火で煮る")
        XCTAssertEqual(decoded.recipes.first?.isFavorite, true)
        XCTAssertEqual(decoded.exportedAt.timeIntervalSince(original.exportedAt), 0, accuracy: 0.001)
        XCTAssertEqual(decoded.recipes.first?.thumbnailData, thumbnail)
        XCTAssertEqual(decoded.recipes.first?.ingredients.first?.amount, "3個")
        XCTAssertEqual(decoded.recipes.first?.cookingSteps.first?.text, "材料を切る")
        XCTAssertEqual(decoded.shoppingItems.first?.sourceRecipeID, recipeID)
    }

    func testRestoreReplacesCurrentData() throws {
        let container = try SharedModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        context.insert(Recipe(title: "古いレシピ", videoURL: "https://youtu.be/abcdefghijk"))
        context.insert(ShoppingItem(name: "古い材料"))
        try context.save()

        let restoredRecipeID = UUID()
        let backup = RecipeClipBackup(
            schemaVersion: BackupService.currentSchemaVersion,
            exportedAt: .now,
            recipes: [
                .init(
                    id: restoredRecipeID,
                    title: "復元レシピ",
                    videoURL: "https://www.youtube.com/watch?v=lmnopqrstuv",
                    channelName: "復元チャンネル",
                    thumbnailURL: nil,
                    thumbnailData: nil,
                    memo: "復元メモ",
                    isFavorite: false,
                    isDraft: false,
                    createdAt: .now,
                    updatedAt: .now,
                    metadataUpdatedAt: nil,
                    ingredients: [.init(id: UUID(), name: "玉ねぎ", amount: "1個", sortOrder: 0)],
                    cookingSteps: [.init(id: UUID(), text: "炒める", sortOrder: 0)]
                )
            ],
            shoppingItems: [
                .init(
                    id: UUID(),
                    name: "玉ねぎ",
                    amount: "1個",
                    isPurchased: true,
                    sourceRecipeID: restoredRecipeID,
                    sourceRecipeTitle: "復元レシピ",
                    createdAt: .now
                )
            ]
        )

        try BackupService.restore(backup, into: context)
        let recipes = try context.fetch(FetchDescriptor<Recipe>())
        let items = try context.fetch(FetchDescriptor<ShoppingItem>())

        XCTAssertEqual(recipes.count, 1)
        XCTAssertEqual(recipes.first?.title, "復元レシピ")
        XCTAssertEqual(recipes.first?.ingredients.first?.name, "玉ねぎ")
        XCTAssertEqual(items.count, 1)
        XCTAssertTrue(items[0].isPurchased)
    }

    func testDecodeRejectsUnsupportedVersionAndInvalidURLs() throws {
        let unsupported = RecipeClipBackup(
            schemaVersion: 99,
            exportedAt: .now,
            recipes: [],
            shoppingItems: []
        )
        XCTAssertThrowsError(try BackupService.decode(BackupService.encode(unsupported)))

        let invalid = RecipeClipBackup(
            schemaVersion: BackupService.currentSchemaVersion,
            exportedAt: .now,
            recipes: [
                .init(
                    id: UUID(), title: "レシピ", videoURL: "https://example.com/video",
                    channelName: "", thumbnailURL: nil, thumbnailData: nil, memo: "",
                    isFavorite: false, isDraft: false, createdAt: .now, updatedAt: .now,
                    metadataUpdatedAt: nil, ingredients: [], cookingSteps: []
                )
            ],
            shoppingItems: []
        )
        XCTAssertThrowsError(try BackupService.decode(BackupService.encode(invalid)))
    }
}
