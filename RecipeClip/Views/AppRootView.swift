import SwiftData
import SwiftUI

struct AppRootView: View {
    @Query private var shoppingItems: [ShoppingItem]
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
                }
            case .onboarding:
                OnboardingView {
                    launchGate = nil
                }
            }
        }
    }
}

private enum LaunchGate: String, Identifiable {
    case privacy
    case onboarding

    var id: String { rawValue }
}
