import SwiftData
import SwiftUI

struct RecipeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Bindable var recipe: Recipe
    @State private var showsEditor = false
    @State private var showsCookingMode = false
    @State private var shoppingMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                RecipeThumbnail(data: recipe.thumbnailData, urlString: recipe.thumbnailURL)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 8) {
                    if recipe.isDraft {
                        Label("共有から保存した未編集レシピ", systemImage: "pencil.circle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    Text(recipe.title)
                        .font(.title.bold())
                    Text(recipe.channelName.isEmpty ? String(localized: "チャンネル未入力") : recipe.channelName)
                        .foregroundStyle(.secondary)
                    Text(
                        String.localizedStringWithFormat(
                            String(localized: "recipe.saved_date"),
                            recipe.createdAt.formatted(date: .abbreviated, time: .omitted)
                        )
                    )
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Button {
                        if let url = URL(string: recipe.videoURL) { openURL(url) }
                    } label: {
                        Label("YouTubeで動画を見る", systemImage: "play.rectangle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }

                detailSection(title: "材料", icon: "basket") {
                    if recipe.sortedIngredients.isEmpty {
                        emptyText("材料はまだ登録されていないよ。")
                    } else {
                        ForEach(recipe.sortedIngredients) { ingredient in
                            HStack(alignment: .firstTextBaseline) {
                                Text(ingredient.name)
                                Spacer()
                                Text(ingredient.amount)
                                    .foregroundStyle(.secondary)
                                Button {
                                    addIngredientToShoppingList(ingredient)
                                } label: {
                                    Image(systemName: "cart.badge.plus")
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel(
                                    String.localizedStringWithFormat(
                                        String(localized: "shopping.add_ingredient_accessibility"),
                                        ingredient.name
                                    )
                                )
                            }
                            Divider()
                        }
                    }

                    Button {
                        addIngredientsToShoppingList()
                    } label: {
                        Label("材料をすべて買い物リストに追加", systemImage: "cart.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(recipe.sortedIngredients.isEmpty)

                    if recipe.sortedIngredients.isEmpty {
                        Text("レシピを編集して材料を登録すると追加できるよ。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                detailSection(title: "作り方", icon: "list.number") {
                    if recipe.sortedCookingSteps.isEmpty {
                        emptyText("作り方はまだ登録されていないよ。")
                    } else {
                        ForEach(Array(recipe.sortedCookingSteps.enumerated()), id: \.element.id) { index, step in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.subheadline.bold())
                                    .frame(width: 28, height: 28)
                                    .background(.tint.opacity(0.14), in: Circle())
                                Text(step.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    Button {
                        showsCookingMode = true
                    } label: {
                        Label("調理モードを開始", systemImage: "cooktop")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(recipe.sortedCookingSteps.isEmpty)

                    if recipe.sortedCookingSteps.isEmpty {
                        Text("レシピを編集して作り方を登録すると開始できるよ。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !recipe.memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    detailSection(title: "メモ", icon: "note.text") {
                        Text(recipe.memo)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("レシピ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    recipe.isFavorite.toggle()
                    recipe.updatedAt = .now
                    try? modelContext.save()
                } label: {
                    Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(recipe.isFavorite ? .red : .primary)
                }
                .accessibilityLabel(
                    recipe.isFavorite
                        ? String(localized: "お気に入りから外す")
                        : String(localized: "お気に入りに追加")
                )

                if let url = URL(string: recipe.videoURL) {
                    ShareLink(item: url, subject: Text(recipe.title)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("動画リンクを共有")
                }

                Button("編集") { showsEditor = true }
            }
        }
        .sheet(isPresented: $showsEditor) {
            NavigationStack {
                RecipeEditorView(recipe: recipe)
            }
        }
        .fullScreenCover(isPresented: $showsCookingMode) {
            CookingModeView(recipe: recipe)
        }
        .alert("買い物リスト", isPresented: Binding(
            get: { shoppingMessage != nil },
            set: { if !$0 { shoppingMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(shoppingMessage ?? "")
        }
    }

    private func detailSection<Content: View>(
        title: LocalizedStringKey,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.title3.bold())
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func emptyText(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func addIngredientsToShoppingList() {
        do {
            let result = try ShoppingListService.addIngredients(from: recipe, to: modelContext)
            if result.updatedCount > 0 {
                shoppingMessage = String.localizedStringWithFormat(String(localized: "shopping.updated_count"), result.affectedCount, result.updatedCount)
            } else {
                shoppingMessage = String.localizedStringWithFormat(String(localized: "shopping.added_count"), result.addedCount)
            }
        } catch {
            modelContext.rollback()
            shoppingMessage = String(localized: "買い物リストに追加できなかったよ。もう一度試してね。")
        }
    }

    private func addIngredientToShoppingList(_ ingredient: Ingredient) {
        do {
            let result = try ShoppingListService.addIngredient(
                ingredient,
                from: recipe,
                to: modelContext
            )
            if result.updatedCount > 0 {
                shoppingMessage = String.localizedStringWithFormat(String(localized: "shopping.ingredient_updated"), ingredient.name)
            } else {
                shoppingMessage = String.localizedStringWithFormat(String(localized: "shopping.ingredient_added"), ingredient.name)
            }
        } catch {
            modelContext.rollback()
            shoppingMessage = String(localized: "買い物リストに追加できなかったよ。もう一度試してね。")
        }
    }
}
