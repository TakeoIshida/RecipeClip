import SwiftData
import SwiftUI
import UIKit

@main
struct RecipeClipApp: App {
    private let modelContainer: ModelContainer

    init() {
        SharedModelContainer.repairPrivacyPolicyConsentSharingIfNeeded()

        do {
            modelContainer = try SharedModelContainer.make(
                inMemory: AppStoreScreenshotScene.current != nil
            )
        } catch {
            fatalError("SwiftDataの準備に失敗しました: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            if let scene = AppStoreScreenshotScene.current {
                AppStoreScreenshotRoot(scene: scene)
            } else {
                AppRootView()
            }
        }
        .modelContainer(modelContainer)
    }
}

/// App Store用の画面を、通常の保存データに触れずに再現する撮影専用モード。
/// `--app-store-screenshot <scene>` で起動する。
enum AppStoreScreenshotScene: String, CaseIterable {
    case recipes
    case organizedEditor = "organized-editor"
    case detail
    case shopping
    case cooking

    static var current: Self? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flagIndex = arguments.firstIndex(of: "--app-store-screenshot"),
              arguments.indices.contains(flagIndex + 1) else {
            return nil
        }
        return Self(rawValue: arguments[flagIndex + 1])
    }
}

private struct AppStoreScreenshotRoot: View {
    let scene: AppStoreScreenshotScene
    private let recipes: [AppStoreSampleRecipe]
    private let shoppingItems: [AppStoreSampleShoppingItem]

    init(scene: AppStoreScreenshotScene) {
        self.scene = scene
        let recipes = AppStoreSampleData.makeRecipes()
        self.recipes = recipes
        self.shoppingItems = AppStoreSampleData.makeShoppingItems(featured: recipes[0])
    }

    private var featuredRecipe: AppStoreSampleRecipe? {
        recipes.first { $0.id == AppStoreSampleData.featuredRecipeID } ?? recipes.first
    }

    var body: some View {
        destination
    }

    @ViewBuilder
    private var destination: some View {
        switch scene {
        case .recipes:
            AppStoreRecipeListView(recipes: recipes)
        case .organizedEditor:
            if let featuredRecipe {
                AppStoreOrganizedEditorView(recipe: featuredRecipe)
            }
        case .detail:
            if let featuredRecipe {
                AppStoreRecipeDetailView(recipe: featuredRecipe)
            }
        case .shopping:
            AppStoreShoppingListView(items: shoppingItems)
        case .cooking:
            if let featuredRecipe {
                AppStoreCookingModeView(recipe: featuredRecipe)
            }
        }
    }
}

private struct AppStoreRecipeListView: View {
    let recipes: [AppStoreSampleRecipe]

    var body: some View {
        TabView {
            NavigationStack {
                List(recipes) { recipe in
                    HStack(spacing: 12) {
                        RecipeThumbnail(data: recipe.thumbnailData, urlString: nil)
                            .frame(width: 112, height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(recipe.title)
                                    .font(.headline)
                                    .lineLimit(2)
                                if recipe.isFavorite {
                                    Image(systemName: "heart.fill")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                            }
                            Text(recipe.channelName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
                .navigationTitle("レシピクリップ")
                .searchable(text: .constant(""), prompt: "料理名・チャンネル・材料")
                .safeAreaInset(edge: .top, spacing: 0) {
                    Picker("表示", selection: .constant(RecipeFilter.all)) {
                        Text("すべて").tag(RecipeFilter.all)
                        Text("お気に入り").tag(RecipeFilter.favorites)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.bar)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Image(systemName: "info.circle")
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Image(systemName: "plus")
                    }
                }
            }
            .tabItem { Label("レシピ", systemImage: "fork.knife") }

            Color.clear
                .tabItem { Label("買い物リスト", systemImage: "cart") }
                .badge(4)
        }
    }
}

private struct AppStoreOrganizedEditorView: View {
    let recipe: AppStoreSampleRecipe

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("自動整理が完了したよ")
                                .font(.headline)
                            Text("説明文から材料5件・手順4件を整理")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "sparkles")
                            .font(.title2)
                            .foregroundStyle(.tint)
                    }
                }
                .listRowBackground(Color.accentColor.opacity(0.10))

                Section("基本情報") {
                    TextField("料理名（必須）", text: .constant(recipe.title))
                    TextField("動画チャンネル", text: .constant(recipe.channelName))
                }

                Section("材料") {
                    ForEach(recipe.ingredients) { ingredient in
                        HStack {
                            TextField("材料", text: .constant(ingredient.name))
                            TextField("分量", text: .constant(ingredient.amount))
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 110)
                        }
                    }
                    Label("材料を追加", systemImage: "plus.circle")
                        .foregroundStyle(.tint)
                }

                Section("作り方") {
                    ForEach(Array(recipe.steps.enumerated()), id: \.element.id) { index, step in
                        HStack(alignment: .top) {
                            Text("\(index + 1)")
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            Text(step.text)
                        }
                    }
                }
            }
            .navigationTitle("レシピを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Text("キャンセル") }
                ToolbarItem(placement: .confirmationAction) { Text("保存").bold() }
            }
        }
    }
}

private struct AppStoreRecipeDetailView: View {
    let recipe: AppStoreSampleRecipe

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    RecipeThumbnail(data: recipe.thumbnailData, urlString: nil)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(recipe.title)
                            .font(.title.bold())
                        Text(recipe.channelName)
                            .foregroundStyle(.secondary)
                        Button(action: {}) {
                            Label("YouTubeで動画を見る", systemImage: "play.rectangle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Label("材料", systemImage: "basket")
                            .font(.title3.bold())
                        ForEach(recipe.ingredients.prefix(4)) { ingredient in
                            HStack {
                                Text(ingredient.name)
                                Spacer()
                                Text(ingredient.amount).foregroundStyle(.secondary)
                                Image(systemName: "cart.badge.plus").foregroundStyle(.tint)
                            }
                            Divider()
                        }
                        Button(action: {}) {
                            Label("材料をすべて買い物リストに追加", systemImage: "cart.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle("レシピ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .primaryAction) { Text("編集") } }
        }
    }
}

private struct AppStoreShoppingListView: View {
    let items: [AppStoreSampleShoppingItem]

    var body: some View {
        TabView(selection: .constant(1)) {
            Color.clear
                .tabItem { Label("レシピ", systemImage: "fork.knife") }
                .tag(0)

            NavigationStack {
                List {
                    Section(String.localizedStringWithFormat(String(localized: "shopping.pending_count"), 4)) {
                        ForEach(items.filter { !$0.isPurchased }) { item in
                            row(item)
                        }
                    }
                    Section(String.localizedStringWithFormat(String(localized: "shopping.purchased_count"), 1)) {
                        ForEach(items.filter(\.isPurchased)) { item in
                            row(item)
                        }
                    }
                }
                .navigationTitle("買い物リスト")
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Image(systemName: "ellipsis.circle")
                        Image(systemName: "plus")
                    }
                }
            }
            .tabItem { Label("買い物リスト", systemImage: "cart") }
            .badge(4)
            .tag(1)
        }
    }

    private func row(_ item: AppStoreSampleShoppingItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(item.isPurchased ? Color.accentColor : .secondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name).strikethrough(item.isPurchased)
                    Spacer()
                    Text(item.amount).foregroundStyle(.secondary)
                }
                if let source = item.sourceRecipeTitle {
                    Label(source, systemImage: "fork.knife")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 3)
    }
}

private struct AppStoreCookingModeView: View {
    let recipe: AppStoreSampleRecipe

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: 1, total: Double(recipe.steps.count))
                    .tint(.accentColor)
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 24) {
                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "cooking.step_progress"),
                            1,
                            recipe.steps.count
                        )
                    )
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(recipe.steps[0].text)
                        .font(.system(.title, design: .rounded, weight: .semibold))
                        .lineSpacing(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                }
                .padding(24)

                HStack(spacing: 12) {
                    Label("前へ", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(.tertiary)
                        .buttonStyle(.bordered)
                    Label("次へ", systemImage: "chevron.right")
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(.white)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle(recipe.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Text("閉じる") }
                ToolbarItem(placement: .primaryAction) { Image(systemName: "basket") }
            }
        }
    }
}

private struct AppStoreSampleRecipe: Identifiable {
    let id: UUID
    let title: String
    let channelName: String
    let thumbnailData: Data?
    let isFavorite: Bool
    let ingredients: [AppStoreSampleIngredient]
    let steps: [AppStoreSampleStep]
}

private struct AppStoreSampleIngredient: Identifiable {
    let id = UUID()
    let name: String
    let amount: String
}

private struct AppStoreSampleStep: Identifiable {
    let id = UUID()
    let text: String
}

private struct AppStoreSampleShoppingItem: Identifiable {
    let id = UUID()
    let name: String
    let amount: String
    let isPurchased: Bool
    let sourceRecipeTitle: String?
}

private enum AppStoreSampleData {
    static let featuredRecipeID = UUID(uuidString: "A1100000-0000-4000-8000-000000000001")!

    static func makeShoppingItems(featured: AppStoreSampleRecipe) -> [AppStoreSampleShoppingItem] {
        if Locale.current.language.languageCode?.identifier == "en" {
            return [
                AppStoreSampleShoppingItem(name: "Colorful cherry tomatoes", amount: "8", isPurchased: false, sourceRecipeTitle: featured.title),
                AppStoreSampleShoppingItem(name: "Lemon", amount: "1", isPurchased: false, sourceRecipeTitle: "Sunlit Lemon Pasta"),
                AppStoreSampleShoppingItem(name: "Unsweetened soy milk", amount: "300 ml", isPurchased: false, sourceRecipeTitle: "Creamy Green Soy Soup"),
                AppStoreSampleShoppingItem(name: "Shimeji mushrooms", amount: "1 pack", isPurchased: false, sourceRecipeTitle: "Ginger-Steamed Mushrooms"),
                AppStoreSampleShoppingItem(name: "Toasted sesame seeds", amount: "1 tbsp", isPurchased: true, sourceRecipeTitle: "Sesame Lotus Root")
            ]
        }
        return [
            AppStoreSampleShoppingItem(name: "カラフルミニトマト", amount: "8個", isPurchased: false, sourceRecipeTitle: featured.title),
            AppStoreSampleShoppingItem(name: "レモン", amount: "1個", isPurchased: false, sourceRecipeTitle: "陽だまりレモンの塩パスタ"),
            AppStoreSampleShoppingItem(name: "無調整豆乳", amount: "300ml", isPurchased: false, sourceRecipeTitle: "まろやか豆乳の森色ポタージュ"),
            AppStoreSampleShoppingItem(name: "しめじ", amount: "1パック", isPurchased: false, sourceRecipeTitle: "ふわり生姜のきのこ蒸し"),
            AppStoreSampleShoppingItem(name: "白いりごま", amount: "大さじ1", isPurchased: true, sourceRecipeTitle: "胡麻香る月見れんこん")
        ]
    }

    static func makeRecipes() -> [AppStoreSampleRecipe] {
        if Locale.current.language.languageCode?.identifier == "en" {
            return makeEnglishRecipes()
        }
        return [
            makeRecipe(
                id: featuredRecipeID,
                title: "星降るトマトの焼きリゾット",
                subtitle: "RecipeClip キッチン",
                colors: [UIColor(red: 0.97, green: 0.35, blue: 0.24, alpha: 1), UIColor(red: 1.00, green: 0.72, blue: 0.30, alpha: 1)],
                ingredients: [("ごはん", "茶碗1杯"), ("カラフルミニトマト", "8個"), ("モッツァレラチーズ", "60g"), ("玉ねぎ", "1/4個"), ("野菜ブイヨン", "150ml")],
                steps: ["玉ねぎをみじん切りにし、ミニトマトは半分に切る。", "フライパンで玉ねぎを透き通るまで炒め、ごはんとブイヨンを加える。", "水分が少し残るまで煮て、トマトとチーズを散らす。", "ふたをして2分蒸し焼きにし、チーズがとろけたら完成。"],
                memo: "トマトの色を残すため、最後に加えるのがポイント。",
                favorite: true,
                offset: 600
            ),
            makeRecipe(title: "柚子香る彩り野菜の炊き込みごはん", colors: [.systemGreen, .systemYellow], ingredients: [("米", "2合"), ("柚子", "1/2個")], steps: ["具材を切る。", "炊飯器で炊く。"], favorite: true, offset: 500),
            makeRecipe(title: "まろやか豆乳の森色ポタージュ", colors: [UIColor(red: 0.30, green: 0.65, blue: 0.43, alpha: 1), UIColor(red: 0.72, green: 0.86, blue: 0.54, alpha: 1)], ingredients: [("無調整豆乳", "300ml"), ("ブロッコリー", "1/2株")], steps: ["野菜を柔らかく煮る。", "豆乳とあわせる。"], offset: 400),
            makeRecipe(title: "胡麻香る月見れんこん", colors: [UIColor(red: 0.58, green: 0.38, blue: 0.24, alpha: 1), UIColor(red: 0.94, green: 0.72, blue: 0.36, alpha: 1)], ingredients: [("れんこん", "200g"), ("白いりごま", "大さじ1")], steps: ["れんこんを焼く。", "ごまだれを絡める。"], offset: 300),
            makeRecipe(title: "陽だまりレモンの塩パスタ", colors: [.systemYellow, .systemOrange], ingredients: [("スパゲッティ", "160g"), ("レモン", "1個")], steps: ["麺をゆでる。", "レモンソースとあえる。"], favorite: true, offset: 200),
            makeRecipe(title: "ふわり生姜のきのこ蒸し", colors: [UIColor(red: 0.55, green: 0.32, blue: 0.20, alpha: 1), UIColor(red: 0.82, green: 0.60, blue: 0.35, alpha: 1)], ingredients: [("しめじ", "1パック"), ("生姜", "1かけ")], steps: ["きのこをほぐす。", "生姜と酒で蒸す。"], offset: 100)
        ]
    }

    private static func makeEnglishRecipes() -> [AppStoreSampleRecipe] {
        [
            makeRecipe(
                id: featuredRecipeID,
                title: "Starry Tomato Baked Risotto",
                subtitle: "RecipeClip Kitchen",
                colors: [UIColor(red: 0.97, green: 0.35, blue: 0.24, alpha: 1), UIColor(red: 1.00, green: 0.72, blue: 0.30, alpha: 1)],
                ingredients: [("Cooked rice", "1 bowl"), ("Colorful cherry tomatoes", "8"), ("Mozzarella", "60 g"), ("Onion", "1/4"), ("Vegetable stock", "150 ml")],
                steps: ["Finely chop the onion and halve the cherry tomatoes.", "Sauté the onion until translucent, then add the rice and stock.", "Simmer until a little liquid remains, then scatter over the tomatoes and cheese.", "Cover and steam for 2 minutes, until the cheese melts."],
                memo: "Add the tomatoes near the end to keep their bright color.",
                favorite: true,
                offset: 600
            ),
            makeRecipe(title: "Citrus Garden Rice", colors: [.systemGreen, .systemYellow], ingredients: [("Rice", "2 cups"), ("Yuzu", "1/2")], steps: ["Cut the vegetables.", "Cook everything in a rice cooker."], favorite: true, offset: 500),
            makeRecipe(title: "Creamy Green Soy Soup", colors: [UIColor(red: 0.30, green: 0.65, blue: 0.43, alpha: 1), UIColor(red: 0.72, green: 0.86, blue: 0.54, alpha: 1)], ingredients: [("Unsweetened soy milk", "300 ml"), ("Broccoli", "1/2 head")], steps: ["Simmer the vegetables until tender.", "Blend with the soy milk."], offset: 400),
            makeRecipe(title: "Sesame Lotus Root", colors: [UIColor(red: 0.58, green: 0.38, blue: 0.24, alpha: 1), UIColor(red: 0.94, green: 0.72, blue: 0.36, alpha: 1)], ingredients: [("Lotus root", "200 g"), ("Toasted sesame seeds", "1 tbsp")], steps: ["Pan-fry the lotus root.", "Coat with sesame sauce."], offset: 300),
            makeRecipe(title: "Sunlit Lemon Pasta", colors: [.systemYellow, .systemOrange], ingredients: [("Spaghetti", "160 g"), ("Lemon", "1")], steps: ["Boil the pasta.", "Toss with lemon sauce."], favorite: true, offset: 200),
            makeRecipe(title: "Ginger-Steamed Mushrooms", colors: [UIColor(red: 0.55, green: 0.32, blue: 0.20, alpha: 1), UIColor(red: 0.82, green: 0.60, blue: 0.35, alpha: 1)], ingredients: [("Shimeji mushrooms", "1 pack"), ("Ginger", "1 clove")], steps: ["Separate the mushrooms.", "Steam with ginger and sake."], offset: 100)
        ]
    }

    private static func makeRecipe(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        colors: [UIColor],
        ingredients: [(String, String)],
        steps: [String],
        memo: String = "作りたての香りを楽しむ、わが家のアレンジ。",
        favorite: Bool = false,
        offset: TimeInterval
    ) -> AppStoreSampleRecipe {
        AppStoreSampleRecipe(
            id: id,
            title: title,
            channelName: subtitle ?? (
                Locale.current.language.languageCode?.identifier == "en"
                    ? "RecipeClip Kitchen"
                    : "RecipeClip キッチン"
            ),
            thumbnailData: thumbnail(colors: colors),
            isFavorite: favorite,
            ingredients: ingredients.map { AppStoreSampleIngredient(name: $0.0, amount: $0.1) },
            steps: steps.map { AppStoreSampleStep(text: $0) }
        )
    }

    /// 第三者の写真・ロゴ・動画サムネイルを使わない、コード描画の抽象的な料理イメージ。
    private static func thumbnail(colors: [UIColor]) -> Data? {
        let size = CGSize(width: 640, height: 360)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.pngData { context in
            let cg = context.cgContext
            let palette = colors.isEmpty ? [UIColor.systemOrange] : colors
            let cgColors = palette.map(\.cgColor) as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: nil)!
            cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])

            cg.setFillColor(UIColor.white.withAlphaComponent(0.92).cgColor)
            cg.fillEllipse(in: CGRect(x: 155, y: 42, width: 330, height: 276))
            cg.setFillColor(palette[0].withAlphaComponent(0.86).cgColor)
            cg.fillEllipse(in: CGRect(x: 205, y: 82, width: 230, height: 196))

            let garnishColors: [UIColor] = [.systemRed, .systemYellow, .systemGreen, .systemOrange]
            for index in 0..<8 {
                let angle = Double(index) * .pi / 4
                let center = CGPoint(x: 320 + cos(angle) * 72, y: 180 + sin(angle) * 58)
                cg.setFillColor(garnishColors[index % garnishColors.count].withAlphaComponent(0.9).cgColor)
                cg.fillEllipse(in: CGRect(x: center.x - 16, y: center.y - 12, width: 32, height: 24))
            }
        }
    }
}
