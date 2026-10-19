import SwiftData
import SwiftUI

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Query private var shoppingItems: [ShoppingItem]
    @State private var importErrorMessage: String?
    @State private var launchGate: LaunchGate? = {
        if !AppConsent.hasAcceptedCurrentPolicy { return .privacy }
        if !OnboardingState.isCompleted { return .onboarding }
        return nil
    }()

    private var pendingItemCount: Int {
        shoppingItems.lazy.filter { !$0.isPurchased }.count
    }

    var body: some View {
        TabView {
            RecipeListView()
                .tabItem {
                    Label("レシピ", systemImage: "fork.knife")
                }

            ShoppingListView()
                .tabItem {
                    Label("買い物リスト", systemImage: "cart")
                }
                .badge(pendingItemCount)
        }
        .fullScreenCover(item: $launchGate) { gate in
            switch gate {
            case .privacy:
                PrivacyConsentView {
                    AppConsent.acceptCurrentPolicy()
                    launchGate = OnboardingState.isCompleted ? nil : .onboarding
                    importPendingSharesIfAllowed()
                }
            case .onboarding:
                OnboardingView {
                    launchGate = nil
                }
            }
        }
        .task {
            await purchaseManager.refresh()
            importPendingSharesIfAllowed()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            SharedModelContainer.repairPrivacyPolicyConsentSharingIfNeeded()
            Task {
                await purchaseManager.refresh()
                importPendingSharesIfAllowed()
            }
        }
        .onChange(of: purchaseManager.hasUnlimitedRecipes) { _, isUnlimited in
            if isUnlimited { importPendingSharesIfAllowed() }
        }
        .alert("共有したレシピを読み込めませんでした", isPresented: Binding(
            get: { importErrorMessage != nil },
            set: { if !$0 { importErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    private func importPendingSharesIfAllowed() {
        guard AppConsent.hasAcceptedCurrentPolicy else { return }
        do {
            let currentCount = try modelContext.fetchCount(FetchDescriptor<Recipe>())
            let availableSlots = purchaseManager.hasUnlimitedRecipes
                ? nil
                : max(0, PurchaseManager.freeRecipeLimit - currentCount)
            let importedCount = try PendingShareDraftStore.importPendingDrafts(
                into: modelContext,
                maxNewRecipes: availableSlots
            )
            if importedCount > 0 {
                NotificationCenter.default.post(name: .recipeClipDidSaveRecipe, object: nil)
            }
            if try PendingShareDraftStore.pendingDraftCount() > 0, availableSlots == 0 {
                importErrorMessage = String(localized: "無料の保存上限15件に達したよ。共有したレシピは、無制限版の購入後に読み込めるよ。")
            }
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }
}

private enum LaunchGate: String, Identifiable {
    case privacy
    case onboarding

    var id: String { rawValue }
}
