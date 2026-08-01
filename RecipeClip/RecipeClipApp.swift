import SwiftData
import SwiftUI

@main
struct RecipeClipApp: App {
    private let modelContainer: ModelContainer = {
        do {
            return try SharedModelContainer.make()
        } catch {
            fatalError("SwiftDataの準備に失敗しました: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(modelContainer)
    }
}
