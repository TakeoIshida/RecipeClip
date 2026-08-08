import SwiftData
import SwiftUI

struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingItem.createdAt) private var items: [ShoppingItem]
    @State private var showsManualEntry = false
    @State private var cleanupAction: CleanupAction?
    @State private var errorMessage: String?

    private var pendingItems: [ShoppingItem] { items.filter { !$0.isPurchased } }
    private var purchasedItems: [ShoppingItem] { items.filter(\.isPurchased) }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView {
                        Label("買い物リストは空だよ", systemImage: "cart")
                    } description: {
                        Text("レシピの詳細から材料をまとめて追加できるよ。")
                    } actions: {
                        Button("材料を手動で追加") { showsManualEntry = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        if !pendingItems.isEmpty {
                            Section {
                                ForEach(pendingItems) { item in
                                    itemRow(item)
                                }
                            } header: {
                                Text(String.localizedStringWithFormat(String(localized: "shopping.pending_count"), pendingItems.count))
                            }
                        }

                        if !purchasedItems.isEmpty {
                            Section {
                                ForEach(purchasedItems) { item in
                                    itemRow(item)
                                }
                            } header: {
                                Text(String.localizedStringWithFormat(String(localized: "shopping.purchased_count"), purchasedItems.count))
                            }
                        }
                    }
                }
            }
            .navigationTitle("買い物リスト")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if !items.isEmpty {
                        Menu {
                            Button("購入済みを削除", systemImage: "checkmark.circle") {
                                cleanupAction = .purchased
                            }
                            .disabled(purchasedItems.isEmpty)

                            Button("すべて削除", systemImage: "trash", role: .destructive) {
                                cleanupAction = .all
                            }
                        } label: {
                            Label("リストを整理", systemImage: "ellipsis.circle")
                        }
                    }

                    Button {
                        showsManualEntry = true
                    } label: {
                        Label("材料を追加", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showsManualEntry) {
                ManualShoppingItemView()
            }
            .confirmationDialog(
                cleanupAction?.title ?? "",
                isPresented: Binding(
                    get: { cleanupAction != nil },
                    set: { if !$0 { cleanupAction = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(cleanupAction?.buttonTitle ?? "削除", role: .destructive) {
                    performCleanup()
                }
                Button("キャンセル", role: .cancel) { cleanupAction = nil }
            } message: {
                Text(cleanupAction?.message ?? "")
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

    private func itemRow(_ item: ShoppingItem) -> some View {
        Button {
            togglePurchased(item)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isPurchased ? Color.accentColor : .secondary)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.name)
                            .strikethrough(item.isPurchased)
                            .foregroundStyle(item.isPurchased ? .secondary : .primary)
                        Spacer()
                        if !item.amount.isEmpty {
                            Text(item.amount)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let source = item.sourceRecipeTitle, !source.isEmpty {
                        Label(source, systemImage: "fork.knife")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: item))
        .accessibilityHint(item.isPurchased ? String(localized: "タップして未購入に戻す") : String(localized: "タップして購入済みにする"))
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                delete(item)
            } label: {
                Label("削除", systemImage: "trash")
            }
        }
    }

    private func accessibilityLabel(for item: ShoppingItem) -> String {
        var parts = [item.name]
        if !item.amount.isEmpty { parts.append(item.amount) }
        if let source = item.sourceRecipeTitle, !source.isEmpty {
            parts.append(
                String.localizedStringWithFormat(String(localized: "shopping.source_recipe"), source)
            )
        }
        parts.append(item.isPurchased ? String(localized: "購入済み") : String(localized: "未購入"))
        return parts.joined(separator: "、")
    }

    private func togglePurchased(_ item: ShoppingItem) {
        item.isPurchased.toggle()
        saveOrRollback(message: String(localized: "購入状態を更新できなかったよ。"))
    }

    private func delete(_ item: ShoppingItem) {
        modelContext.delete(item)
        saveOrRollback(message: String(localized: "材料を削除できなかったよ。"))
    }

    private func performCleanup() {
        let action = cleanupAction
        cleanupAction = nil
        do {
            switch action {
            case .purchased:
                try ShoppingListService.deletePurchased(from: modelContext)
            case .all:
                try ShoppingListService.deleteAll(from: modelContext)
            case nil:
                break
            }
        } catch {
            modelContext.rollback()
            errorMessage = String(localized: "買い物リストを整理できなかったよ。")
        }
    }

    private func saveOrRollback(message: String) {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = message
        }
    }
}

private struct ManualShoppingItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name = ""
    @State private var amount = ""
    @State private var errorMessage: String?
    @FocusState private var isNameFocused: Bool

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("材料") {
                    TextField("材料名（必須）", text: $name)
                        .focused($isNameFocused)
                        .submitLabel(.next)
                    TextField("分量・個数", text: $amount)
                        .submitLabel(.done)
                        .onSubmit { if canSave { save() } }
                }
            }
            .navigationTitle("材料を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear { isNameFocused = true }
            .alert("追加できなかったよ", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? String(localized: "もう一度試してね。"))
            }
        }
    }

    private func save() {
        do {
            try ShoppingListService.addManualItem(name: name, amount: amount, to: modelContext)
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

private enum CleanupAction {
    case purchased
    case all

    var title: String {
        switch self {
        case .purchased: String(localized: "購入済みを削除する？")
        case .all: String(localized: "買い物リストをすべて削除する？")
        }
    }

    var buttonTitle: String {
        switch self {
        case .purchased: String(localized: "購入済みを削除")
        case .all: String(localized: "すべて削除")
        }
    }

    var message: String {
        switch self {
        case .purchased: String(localized: "チェック済みの材料をまとめて削除するよ。")
        case .all: String(localized: "この操作は取り消せないよ。")
        }
    }
}
