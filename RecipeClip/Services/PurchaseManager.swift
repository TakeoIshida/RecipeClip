import StoreKit
import SwiftUI

@MainActor
final class PurchaseManager: ObservableObject {
    static let unlimitedProductID = "com.ishidatakeo.RecipeClip.unlimited"
    static let freeRecipeLimit = 15

    @Published private(set) var product: Product?
    @Published private(set) var hasUnlimitedRecipes = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        transactionUpdatesTask = observeTransactionUpdates()
        Task { await refresh() }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func canAddRecipe(currentCount: Int) -> Bool {
        hasUnlimitedRecipes || currentCount < Self.freeRecipeLimit
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        // Entitlements are checked independently from storefront metadata.
        // This keeps an already purchased unlock available when price loading
        // temporarily fails (for example, during an offline launch).
        hasUnlimitedRecipes = await hasVerifiedEntitlement()

        do {
            product = try await Product.products(for: [Self.unlimitedProductID]).first
            if product == nil {
                errorMessage = String(localized: "購入商品を読み込めなかったよ。少し待ってから試してね。")
            }
        } catch {
            errorMessage = String(localized: "購入情報を読み込めなかったよ。通信状態を確認してね。")
        }
    }

    func purchaseUnlimitedRecipes() async -> Bool {
        guard let product else {
            errorMessage = String(localized: "購入商品を読み込めなかったよ。少し待ってから試してね。")
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                let transaction = try Self.verified(verification)
                await transaction.finish()
                hasUnlimitedRecipes = true
                return true
            case .pending, .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = String(localized: "購入を完了できなかったよ。請求は発生していないよ。")
            return false
        }
    }

    func restorePurchases() async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            hasUnlimitedRecipes = await hasVerifiedEntitlement()
            if !hasUnlimitedRecipes {
                errorMessage = String(localized: "復元できる購入が見つからなかったよ。")
            }
            return hasUnlimitedRecipes
        } catch {
            errorMessage = String(localized: "購入を復元できなかったよ。")
            return false
        }
    }

    private func hasVerifiedEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.verified(result) else { continue }
            if transaction.productID == Self.unlimitedProductID,
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self,
                      let transaction = try? Self.verified(result) else { continue }
                guard transaction.productID == Self.unlimitedProductID else { continue }
                self.hasUnlimitedRecipes = transaction.revocationDate == nil
                await transaction.finish()
            }
        }
    }

    private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case let .verified(value): value
        case .unverified: throw PurchaseError.failedVerification
        }
    }
}

private enum PurchaseError: Error {
    case failedVerification
}

struct UnlimitedRecipesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseManager: PurchaseManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                VStack(spacing: 10) {
                    Text("レシピを無制限に保存")
                        .font(.title.bold())
                    Text("無料版では15件まで保存できるよ。一度の購入で、広告なしのまま保存件数を無制限にできるよ。")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("レシピの保存件数が無制限", systemImage: "checkmark.circle.fill")
                    Label("追加の広告やサブスクなし", systemImage: "checkmark.circle.fill")
                    Label("同じApple Accountで購入を復元", systemImage: "checkmark.circle.fill")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    Task {
                        if await purchaseManager.purchaseUnlimitedRecipes() { dismiss() }
                    }
                } label: {
                    if purchaseManager.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(purchaseButtonTitle)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(purchaseManager.isLoading || purchaseManager.product == nil)

                if purchaseManager.product == nil && !purchaseManager.isLoading {
                    Button("購入情報を再読み込み") {
                        Task { await purchaseManager.refresh() }
                    }
                }

                Button("購入を復元") {
                    Task {
                        if await purchaseManager.restorePurchases() { dismiss() }
                    }
                }
                .disabled(purchaseManager.isLoading)

                Text("作成済みのレシピの閲覧・編集・バックアップは、無料上限に達した後も利用できるよ。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("無制限版")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task { await purchaseManager.refresh() }
            .alert("購入情報", isPresented: Binding(
                get: { purchaseManager.errorMessage != nil },
                set: { if !$0 { purchaseManager.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchaseManager.errorMessage ?? "")
            }
        }
    }

    private var purchaseButtonTitle: String {
        guard let displayPrice = purchaseManager.product?.displayPrice else {
            return String(localized: "購入情報を読み込む")
        }
        return String.localizedStringWithFormat(
            String(localized: "unlimited.purchase_price"),
            displayPrice
        )
    }
}
