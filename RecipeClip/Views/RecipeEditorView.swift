import SwiftData
import SwiftUI

struct IngredientDraft: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var amount: String
}

struct CookingStepDraft: Identifiable, Equatable {
    var id = UUID()
    var text: String
}

struct RecipeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let recipe: Recipe?
    private let metadataFetcher: any YouTubeMetadataFetching
    private let initialVideoURL: String
    private let initialTitle: String
    private let initialChannelName: String
    private let initialMemo: String
    private let initialIngredients: [IngredientDraft]
    private let initialCookingSteps: [CookingStepDraft]

    @State private var videoURL: String
    @State private var title: String
    @State private var channelName: String
    @State private var thumbnailURL: String?
    @State private var thumbnailData: Data?
    @State private var sourceDescription = ""
    @State private var metadataUpdatedAt: Date?
    @State private var memo: String
    @State private var ingredients: [IngredientDraft]
    @State private var cookingSteps: [CookingStepDraft]
    @State private var isLoading = false
    @State private var isAutoFilling = false
    @State private var statusMessage: String?
    @State private var showsSaveError = false
    @State private var showsDiscardConfirmation = false
    @State private var lastAutomaticallyLoadedURL: String?
    @State private var lastAutomaticallyParsedDescription = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case videoURL
    }

    init(
        recipe: Recipe? = nil,
        metadataFetcher: any YouTubeMetadataFetching = YouTubeService()
    ) {
        self.recipe = recipe
        self.metadataFetcher = metadataFetcher
        let initialVideoURL = recipe?.videoURL ?? ""
        let initialTitle = recipe?.title ?? ""
        let initialChannelName = recipe?.channelName ?? ""
        let initialMemo = recipe?.memo ?? ""
        let initialIngredients = recipe?.sortedIngredients.map {
            IngredientDraft(name: $0.name, amount: $0.amount)
        } ?? []
        let initialCookingSteps = recipe?.sortedCookingSteps.map {
            CookingStepDraft(text: $0.text)
        } ?? []
        self.initialVideoURL = initialVideoURL
        self.initialTitle = initialTitle
        self.initialChannelName = initialChannelName
        self.initialMemo = initialMemo
        self.initialIngredients = initialIngredients
        self.initialCookingSteps = initialCookingSteps
        _videoURL = State(initialValue: initialVideoURL)
        _title = State(initialValue: initialTitle)
        _channelName = State(initialValue: initialChannelName)
        _thumbnailURL = State(initialValue: recipe?.thumbnailURL)
        _thumbnailData = State(initialValue: recipe?.thumbnailData)
        _metadataUpdatedAt = State(initialValue: recipe?.metadataUpdatedAt)
        _memo = State(initialValue: initialMemo)
        _ingredients = State(initialValue: initialIngredients)
        _cookingSteps = State(initialValue: initialCookingSteps)
        _lastAutomaticallyLoadedURL = State(
            initialValue: (try? YouTubeURLNormalizer.normalize(initialVideoURL))?.absoluteString
        )
    }

    var body: some View {
        Form {
            Section("YouTube動画") {
                TextField("https://youtu.be/…", text: $videoURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textContentType(.URL)
                    .submitLabel(.go)
                    .focused($focusedField, equals: .videoURL)
                    .onSubmit {
                        guard canLoadVideo else { return }
                        Task { await loadMetadata() }
                    }

                if !videoURL.isEmpty && !isValidYouTubeURL {
                    Label("YouTubeの動画URLを入力してね。Shortsや短縮URLにも対応しているよ。", systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await loadMetadata() }
                } label: {
                    HStack {
                        if isLoading { ProgressView() }
                        Label("動画情報を再取得", systemImage: "arrow.clockwise.circle")
                    }
                }
                .disabled(isLoading || isAutoFilling || !canLoadVideo)

                if let statusMessage {
                    Label(statusMessage, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if thumbnailData != nil || thumbnailURL != nil {
                    RecipeThumbnail(data: thumbnailData, urlString: thumbnailURL)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .listRowInsets(EdgeInsets())
                }
            }

            Section {
                Label("リンクを貼ると動画情報を自動取得するよ。次にYouTubeの説明欄をコピーして下へ貼ると、レシピも自動で作るよ。", systemImage: "sparkles")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField(
                    "材料や作り方が書かれた説明欄を貼り付け",
                    text: $sourceDescription,
                    axis: .vertical
                )
                .lineLimit(6...16)

                Button {
                    Task { await autoFillRecipe() }
                } label: {
                    HStack {
                        if isAutoFilling { ProgressView() }
                        Label("説明欄からもう一度自動作成", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(
                    isAutoFilling
                        || isLoading
                        || !canLoadVideo
                        || sourceDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            } header: {
                Text("レシピ自動作成")
            } footer: {
                Text("iOS 26の対応端末ではApple Intelligenceを使い、それ以外では無料のルール解析で整理するよ。")
            }

            Section("基本情報") {
                TextField("料理名（必須）", text: $title)
                TextField("動画チャンネル", text: $channelName)
            }

            Section {
                ForEach($ingredients) { $ingredient in
                    HStack {
                        TextField("材料", text: $ingredient.name)
                        TextField("分量", text: $ingredient.amount)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 110)
                    }
                }
                .onDelete { ingredients.remove(atOffsets: $0) }
                .onMove { ingredients.move(fromOffsets: $0, toOffset: $1) }

                Button {
                    ingredients.append(IngredientDraft(name: "", amount: ""))
                } label: {
                    Label("材料を追加", systemImage: "plus.circle")
                }
            } header: {
                HStack {
                    Text("材料")
                    Spacer()
                    if !ingredients.isEmpty { EditButton() }
                }
            }

            Section {
                ForEach(Array(cookingSteps.indices), id: \.self) { index in
                    HStack(alignment: .top) {
                        Text("\(index + 1)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 28)
                        TextField("手順", text: $cookingSteps[index].text, axis: .vertical)
                            .lineLimit(2...6)
                    }
                }
                .onDelete { cookingSteps.remove(atOffsets: $0) }
                .onMove { cookingSteps.move(fromOffsets: $0, toOffset: $1) }

                Button {
                    cookingSteps.append(CookingStepDraft(text: ""))
                } label: {
                    Label("手順を追加", systemImage: "plus.circle")
                }
            } header: {
                HStack {
                    Text("作り方")
                    Spacer()
                    if !cookingSteps.isEmpty { EditButton() }
                }
            }

            Section("メモ") {
                TextField("コツ、代用した材料など", text: $memo, axis: .vertical)
                    .lineLimit(4...10)
            }
        }
        .navigationTitle(recipe == nil ? "レシピを追加" : "レシピを編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { requestDismissal() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
                    .disabled(!canSave || isLoading || isAutoFilling)
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
        .task(id: videoURL) {
            await automaticallyLoadPastedURL(videoURL)
        }
        .task(id: sourceDescription) {
            await automaticallyParsePastedDescription(sourceDescription)
        }
        .confirmationDialog(
            "入力中の内容を破棄する？",
            isPresented: $showsDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("変更を破棄", role: .destructive) { dismiss() }
            Button("編集を続ける", role: .cancel) {}
        } message: {
            Text("まだ保存していない変更があるよ。")
        }
        .alert("保存できなかったよ", isPresented: $showsSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(statusMessage ?? String(localized: "入力内容を確認してね。"))
        }
    }

    private var canSave: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return isValidYouTubeURL
    }

    private var isValidYouTubeURL: Bool {
        (try? YouTubeURLNormalizer.normalize(videoURL)) != nil
    }

    private var canLoadVideo: Bool {
        isValidYouTubeURL && !videoURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasUnsavedChanges: Bool {
        videoURL != initialVideoURL
            || title != initialTitle
            || channelName != initialChannelName
            || memo != initialMemo
            || !sourceDescription.isEmpty
            || ingredients != initialIngredients
            || cookingSteps != initialCookingSteps
    }

    private func requestDismissal() {
        if hasUnsavedChanges {
            showsDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    @MainActor
    private func loadMetadata() async {
        isLoading = true
        statusMessage = String(localized: "動画情報を取得しているよ…")
        defer { isLoading = false }

        do {
            let metadata = try await metadataFetcher.fetchMetadata(for: videoURL)
            videoURL = metadata.canonicalURL.absoluteString
            title = metadata.title
            channelName = metadata.channelName
            thumbnailURL = metadata.thumbnailURL?.absoluteString
            thumbnailData = metadata.thumbnailData
            metadataUpdatedAt = .now
            lastAutomaticallyLoadedURL = metadata.canonicalURL.absoluteString
            statusMessage = String(localized: "動画情報を取得したよ。")
        } catch {
            if let canonicalURL = try? YouTubeURLNormalizer.normalize(videoURL) {
                videoURL = canonicalURL.absoluteString
                lastAutomaticallyLoadedURL = canonicalURL.absoluteString
            }
            statusMessage = (error as? LocalizedError)?.errorDescription ?? "動画情報を取得できなかったよ。手入力で続けられるよ。"
        }
    }

    @MainActor
    private func automaticallyLoadPastedURL(_ rawValue: String) async {
        do {
            try await Task.sleep(nanoseconds: 450_000_000)
        } catch {
            return
        }
        guard !Task.isCancelled,
              let canonicalURL = try? YouTubeURLNormalizer.normalize(rawValue),
              canonicalURL.absoluteString != lastAutomaticallyLoadedURL else {
            return
        }

        lastAutomaticallyLoadedURL = canonicalURL.absoluteString
        statusMessage = String(localized: "リンクを確認しているよ…")
        await loadMetadata()
    }

    @MainActor
    private func automaticallyParsePastedDescription(_ rawValue: String) async {
        do {
            try await Task.sleep(nanoseconds: 650_000_000)
        } catch {
            return
        }

        let description = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !Task.isCancelled,
              !description.isEmpty,
              description != lastAutomaticallyParsedDescription,
              canLoadVideo,
              !isAutoFilling else {
            return
        }

        while isLoading {
            do {
                try await Task.sleep(nanoseconds: 100_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
        }

        lastAutomaticallyParsedDescription = description
        await autoFillRecipe()
    }

    @MainActor
    private func autoFillRecipe() async {
        isAutoFilling = true
        statusMessage = String(localized: "貼り付けた説明欄を整理しているよ…")
        defer { isAutoFilling = false }

        guard let canonicalURL = try? YouTubeURLNormalizer.normalize(videoURL) else {
            statusMessage = YouTubeError.unsupportedURL.localizedDescription
            return
        }
        videoURL = canonicalURL.absoluteString

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let metadata = try? await metadataFetcher.fetchMetadata(for: videoURL) {
            title = metadata.title
            channelName = metadata.channelName
            thumbnailURL = metadata.thumbnailURL?.absoluteString
            thumbnailData = metadata.thumbnailData
            metadataUpdatedAt = .now
        }

        let description = sourceDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else {
            statusMessage = String(localized: "YouTubeの説明欄を貼り付けてから、もう一度押してね。")
            return
        }
        lastAutomaticallyParsedDescription = description

        statusMessage = String(localized: "材料と作り方を整理しているよ…")
        let extracted = await RecipeAutomaticExtractor.extract(
            from: description,
            fallbackTitle: title
        )

        if !extracted.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            title = extracted.title
        }
        ingredients = extracted.ingredients.map {
            IngredientDraft(name: $0.name, amount: $0.amount)
        }
        cookingSteps = extracted.steps.map { CookingStepDraft(text: $0) }
        if !extracted.memo.isEmpty { memo = extracted.memo }

        if ingredients.isEmpty && cookingSteps.isEmpty {
            statusMessage = String(localized: "説明欄に材料や手順を見つけられなかったよ。必要なところだけ手入力してね。")
        } else {
            switch extracted.method {
            case .appleIntelligence:
                statusMessage = String(localized: "Apple Intelligenceでレシピを自動作成したよ。内容を確認して保存してね。")
            case .ruleBased:
                statusMessage = String(localized: "説明欄から無料でレシピを自動作成したよ。内容を確認して保存してね。")
            }
        }
    }

    private func save() {
        do {
            let canonicalURL = try YouTubeURLNormalizer.normalize(videoURL)
            let existingRecipes = try modelContext.fetch(FetchDescriptor<Recipe>())
            if existingRecipes.contains(where: {
                $0.id != recipe?.id && $0.videoURL == canonicalURL.absoluteString
            }) {
                throw RecipeEditorError.duplicateVideo
            }
            let cleanIngredients = ingredients
                .map { IngredientDraft(name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines), amount: $0.amount.trimmingCharacters(in: .whitespacesAndNewlines)) }
                .filter { !$0.name.isEmpty }
                .enumerated()
                .map { Ingredient(name: $0.element.name, amount: $0.element.amount, sortOrder: $0.offset) }
            let cleanSteps = cookingSteps
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .enumerated()
                .map { CookingStep(text: $0.element, sortOrder: $0.offset) }

            if let recipe {
                let oldIngredients = recipe.ingredients
                let oldSteps = recipe.cookingSteps
                recipe.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                recipe.videoURL = canonicalURL.absoluteString
                recipe.channelName = channelName.trimmingCharacters(in: .whitespacesAndNewlines)
                recipe.thumbnailURL = thumbnailURL
                recipe.thumbnailData = thumbnailData
                recipe.memo = memo.trimmingCharacters(in: .whitespacesAndNewlines)
                recipe.ingredients = cleanIngredients
                recipe.cookingSteps = cleanSteps
                recipe.isDraft = false
                recipe.updatedAt = .now
                recipe.metadataUpdatedAt = metadataUpdatedAt
                oldIngredients.forEach(modelContext.delete)
                oldSteps.forEach(modelContext.delete)
            } else {
                let newRecipe = Recipe(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    videoURL: canonicalURL.absoluteString,
                    channelName: channelName.trimmingCharacters(in: .whitespacesAndNewlines),
                    thumbnailURL: thumbnailURL,
                    thumbnailData: thumbnailData,
                    memo: memo.trimmingCharacters(in: .whitespacesAndNewlines),
                    ingredients: cleanIngredients,
                    cookingSteps: cleanSteps,
                    metadataUpdatedAt: metadataUpdatedAt
                )
                modelContext.insert(newRecipe)
            }

            try modelContext.save()
            dismiss()
        } catch {
            statusMessage = error.localizedDescription
            showsSaveError = true
        }
    }
}

private enum RecipeEditorError: LocalizedError {
    case duplicateVideo

    var errorDescription: String? {
        "この動画はすでに保存されているよ。一覧から開いて編集してね。"
    }
}
