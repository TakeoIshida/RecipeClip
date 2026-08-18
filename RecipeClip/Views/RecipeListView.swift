import SwiftData
import SwiftUI

struct RecipeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var recipes: [Recipe] = []
    @State private var searchText = ""
    @State private var filter: RecipeFilter = .all
    @State private var showsEditor = false
    @State private var recipePendingDeletion: Recipe?
    @State private var errorMessage: String?

    private var visibleRecipes: [Recipe] {
        recipes.filter { recipe in
            let matchesFilter = filter == .all || recipe.isFavorite
            return matchesFilter && RecipeFiltering.matches(recipe, query: searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if visibleRecipes.isEmpty {
                    ContentUnavailableView {
                        Label(emptyTitle, systemImage: emptyIcon)
                    } description: {
                        Text(emptyDescription)
                    } actions: {
                        if recipes.isEmpty {
                            Button("最初のレシピを追加") { showsEditor = true }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    List {
                        ForEach(visibleRecipes) { recipe in
                            NavigationLink(value: recipe) {
                                RecipeRow(recipe: recipe)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    recipePendingDeletion = recipe
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("動画レシピ帳")
            .searchable(text: $searchText, prompt: "料理名・チャンネル・材料")
            .safeAreaInset(edge: .top, spacing: 0) {
                Picker("表示", selection: $filter) {
                    ForEach(RecipeFilter.allCases) { item in
                        Text(LocalizedStringKey(item.rawValue)).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        AppInfoView()
                    } label: {
                        Label("アプリ情報", systemImage: "info.circle")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showsEditor = true } label: {
                        Label("レシピを追加", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .sheet(isPresented: $showsEditor) {
                NavigationStack {
                    RecipeEditorView()
                }
            }
            .task {
                reloadRecipes()
                await refreshStaleMetadata()
            }
            .onChange(of: scenePhase) { _, newValue in
                if newValue == .active {
                    reloadRecipes()
                    Task { await refreshStaleMetadata() }
                }
            }
            .onChange(of: showsEditor) { wasPresented, isPresented in
                if wasPresented && !isPresented { reloadRecipes() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .recipeClipBackupDidRestore)) { _ in
                reloadRecipes()
            }
            .confirmationDialog(
                String.localizedStringWithFormat(
                    String(localized: "recipe.delete_confirmation"),
                    recipePendingDeletion?.title ?? String(localized: "レシピ")
                ),
                isPresented: Binding(
                    get: { recipePendingDeletion != nil },
                    set: { if !$0 { recipePendingDeletion = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    if let recipePendingDeletion { delete(recipePendingDeletion) }
                    recipePendingDeletion = nil
                }
                Button("キャンセル", role: .cancel) { recipePendingDeletion = nil }
            } message: {
                Text("材料や作り方も削除されるよ。この操作は取り消せないよ。")
            }
            .alert("操作を完了できなかったよ", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? String(localized: "もう一度試してね。"))
            }
        }
    }

    private var emptyTitle: String {
        if !searchText.isEmpty { return String(localized: "見つからなかったよ") }
        if filter == .favorites { return String(localized: "お気に入りはまだないよ") }
        return String(localized: "レシピを保存しよう")
    }

    private var emptyIcon: String {
        recipes.isEmpty ? "fork.knife.circle" : "magnifyingglass"
    }

    private var emptyDescription: String {
        recipes.isEmpty
            ? String(localized: "YouTubeの料理動画を、いつでも見返せるレシピにしよう。")
            : String(localized: "検索条件や表示の切り替えを変えてみてね。")
    }

    private func delete(_ recipe: Recipe) {
        modelContext.delete(recipe)
        do {
            try modelContext.save()
            reloadRecipes()
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "レシピを削除できなかったよ。もう一度試してね。")
        }
    }

    private func reloadRecipes() {
        let descriptor = FetchDescriptor<Recipe>(
            sortBy: [SortDescriptor(\Recipe.createdAt, order: .reverse)]
        )
        recipes = (try? modelContext.fetch(descriptor)) ?? []
    }

    @MainActor
    private func refreshStaleMetadata() async {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -29, to: .now) else { return }
        let staleRecipes = recipes.filter { ($0.metadataUpdatedAt ?? .distantPast) < cutoff }
        guard !staleRecipes.isEmpty else { return }

        var didUpdate = false
        for recipe in staleRecipes {
            guard let metadata = try? await YouTubeService().fetchMetadata(for: recipe.videoURL) else {
                continue
            }
            recipe.channelName = metadata.channelName
            recipe.thumbnailURL = metadata.thumbnailURL?.absoluteString
            recipe.thumbnailData = metadata.thumbnailData
            recipe.metadataUpdatedAt = .now
            if recipe.isDraft { recipe.title = metadata.title }
            didUpdate = true
        }

        if didUpdate {
            try? modelContext.save()
            reloadRecipes()
        }
    }
}

private struct RecipeRow: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 12) {
            RecipeThumbnail(data: recipe.thumbnailData, urlString: recipe.thumbnailURL)
                .frame(width: 112, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(recipe.title)
                        .font(.headline)
                        .lineLimit(2)
                    if recipe.isFavorite {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                Text(recipe.channelName.isEmpty ? String(localized: "チャンネル未入力") : recipe.channelName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if recipe.isDraft {
                    Text("未編集")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.orange.opacity(0.16), in: Capsule())
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityHint("タップしてレシピの詳細を表示")
    }
}
