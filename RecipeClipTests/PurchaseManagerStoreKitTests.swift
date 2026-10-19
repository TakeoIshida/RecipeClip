import StoreKit
import StoreKitTest
import XCTest
@testable import RecipeClip

@MainActor
final class PurchaseManagerStoreKitTests: XCTestCase {
    private var session: SKTestSession!

    override func setUpWithError() throws {
        session = try SKTestSession(configurationFileNamed: "RecipeClip")
        session.disableDialogs = true
        session.clearTransactions()
    }

    override func tearDownWithError() throws {
        session.clearTransactions()
        session = nil
    }

    func testFreeLimitAllowsFirstFifteenRecipesOnly() {
        let manager = PurchaseManager()

        XCTAssertTrue(manager.canAddRecipe(currentCount: 0))
        XCTAssertTrue(manager.canAddRecipe(currentCount: 14))
        XCTAssertFalse(manager.canAddRecipe(currentCount: 15))
    }

    func testProductMetadataLoadsBeforePurchase() async throws {
        let manager = PurchaseManager()
        await manager.refresh()

        XCTAssertEqual(manager.product?.id, PurchaseManager.unlimitedProductID)
        XCTAssertFalse(manager.hasUnlimitedRecipes)
    }

    func testEntitlementSurvivesManagerRecreation() async throws {
        try await session.buyProduct(identifier: PurchaseManager.unlimitedProductID)

        let relaunchedManager = PurchaseManager()
        await relaunchedManager.refresh()

        XCTAssertTrue(relaunchedManager.hasUnlimitedRecipes)
        XCTAssertTrue(relaunchedManager.canAddRecipe(currentCount: PurchaseManager.freeRecipeLimit))
    }

    func testNoEntitlementWithoutPurchase() async {
        let manager = PurchaseManager()
        await manager.refresh()

        XCTAssertFalse(manager.hasUnlimitedRecipes)
        XCTAssertFalse(manager.canAddRecipe(currentCount: PurchaseManager.freeRecipeLimit))
    }
}
