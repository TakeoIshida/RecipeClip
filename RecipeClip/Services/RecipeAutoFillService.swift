import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

struct ExtractedRecipeData: Equatable {
    struct IngredientData: Equatable {
        let name: String
        let amount: String
    }

    enum Method: Equatable {
        case appleIntelligence
        case ruleBased
    }

    let title: String
    let ingredients: [IngredientData]
    let steps: [String]
    let memo: String
    let method: Method
}

enum RecipeAutomaticExtractor {
    static func extract(from description: String, fallbackTitle: String) async -> ExtractedRecipeData {
#if canImport(FoundationModels)
        if #available(iOS 26.0, *),
           let generated = try? await AppleIntelligenceRecipeExtractor.extract(
               from: description,
               fallbackTitle: fallbackTitle
           ) {
            return generated
        }
#endif
        return RecipeRuleParser.parse(description, fallbackTitle: fallbackTitle)
    }
}

enum RecipeRuleParser {
    private enum Section {
        case none
        case ingredients
        case steps
        case memo
    }

    static func parse(_ description: String, fallbackTitle: String) -> ExtractedRecipeData {
        let lines = description
            .components(separatedBy: .newlines)
            .map(cleanLine)
            .filter { !$0.isEmpty }

        var section: Section = .none
        var ingredients: [ExtractedRecipeData.IngredientData] = []
        var steps: [String] = []
        var memoLines: [String] = []

        for line in lines {
            if isIngredientHeading(line) {
                section = .ingredients
                continue
            }
            if isStepHeading(line) {
                section = .steps
                continue
            }
            if isMemoHeading(line) {
                section = .memo
                continue
            }
            guard !isNoise(line) else { continue }

            switch section {
            case .ingredients:
                if let ingredient = parseIngredient(line) { ingredients.append(ingredient) }
            case .steps:
                let step = stripListPrefix(line)
                if !step.isEmpty { steps.append(step) }
            case .memo:
                memoLines.append(stripListPrefix(line))
            case .none:
                if looksLikeIngredient(line), let ingredient = parseIngredient(line) {
                    ingredients.append(ingredient)
                } else if looksLikeNumberedStep(line) {
                    steps.append(stripListPrefix(line))
                }
            }
        }

        return ExtractedRecipeData(
            title: fallbackTitle,
            ingredients: deduplicatedIngredients(ingredients),
            steps: deduplicated(steps),
            memo: deduplicated(memoLines).joined(separator: "\n"),
            method: .ruleBased
        )
    }

    private static func cleanLine(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedHeading(_ line: String) -> String {
        line.lowercased().trimmingCharacters(
            in: CharacterSet(charactersIn: "【】[]■□◆◇▼▽●○・:： 0123456789.-")
        )
    }

    private static func isIngredientHeading(_ line: String) -> Bool {
        let value = normalizedHeading(line)
        return value == "材料" || value.hasPrefix("材料（") || value.hasPrefix("材料(")
            || value == "ingredients" || value.hasPrefix("ingredients ")
    }

    private static func isStepHeading(_ line: String) -> Bool {
        let value = normalizedHeading(line)
        return ["作り方", "作りかた", "手順", "調理手順", "つくり方", "recipe", "directions"]
            .contains(where: { value == $0 || value.hasPrefix($0 + "（") || value.hasPrefix($0 + "(") })
    }

    private static func isMemoHeading(_ line: String) -> Bool {
        let value = normalizedHeading(line)
        return ["ポイント", "コツ", "補足", "メモ", "注意", "notes", "tips"].contains(value)
    }

    private static func isNoise(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        return lowercased.hasPrefix("http://")
            || lowercased.hasPrefix("https://")
            || lowercased.hasPrefix("#")
            || lowercased.contains("チャンネル登録")
            || lowercased.contains("subscribe")
            || lowercased.contains("sns")
    }

    private static func looksLikeIngredient(_ line: String) -> Bool {
        line.range(
            of: #"\d+(?:[.,]\d+)?\s*(?:g|kg|ml|l|cc|個|本|枚|杯|束|袋|缶|パック|大さじ|小さじ|適量|少々)"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func looksLikeNumberedStep(_ line: String) -> Bool {
        line.range(of: #"^(?:\d+[.)、．:]|[①-⑳])\s*"#, options: .regularExpression) != nil
    }

    private static func parseIngredient(_ line: String) -> ExtractedRecipeData.IngredientData? {
        let clean = stripListPrefix(line)
        guard !clean.isEmpty else { return nil }

        let separators = ["……", "…", "：", ":", "\t"]
        for separator in separators where clean.contains(separator) {
            let parts = clean.components(separatedBy: separator)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if parts.count >= 2 {
                return .init(name: parts[0], amount: parts.dropFirst().joined(separator: " "))
            }
        }

        if let range = clean.range(
            of: #"\s{2,}|\s+(?=\d|適量|少々|お好み)"#,
            options: .regularExpression
        ) {
            let name = String(clean[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            let amount = String(clean[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty { return .init(name: name, amount: amount) }
        }

        return .init(name: clean, amount: "")
    }

    private static func stripListPrefix(_ line: String) -> String {
        line.replacingOccurrences(
            of: #"^(?:[-*・●○■□◆◇▶▷✓]+|\d+[.)、．:]|[①-⑳])\s*"#,
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespaces)
    }

    private static func deduplicated(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    private static func deduplicatedIngredients(
        _ values: [ExtractedRecipeData.IngredientData]
    ) -> [ExtractedRecipeData.IngredientData] {
        var seen = Set<String>()
        return values.filter { seen.insert($0.name + "\u{0}" + $0.amount).inserted }
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
private enum AppleIntelligenceRecipeExtractor {
    @Generable
    struct GeneratedRecipe {
        @Guide(description: "料理名。説明欄から分からない場合は動画タイトルを使う")
        var title: String

        @Guide(description: "材料と分量", .maximumCount(40))
        var ingredients: [GeneratedIngredient]

        @Guide(description: "調理する順番に並べた簡潔な手順", .maximumCount(30))
        var steps: [String]

        @Guide(description: "コツや注意点。なければ空文字")
        var memo: String
    }

    @Generable
    struct GeneratedIngredient {
        var name: String
        var amount: String
    }

    static func extract(from description: String, fallbackTitle: String) async throws -> ExtractedRecipeData? {
        let model = SystemLanguageModel.default
        guard model.isAvailable, model.supportsLocale(Locale(identifier: "ja_JP")) else { return nil }

        let session = LanguageModelSession(instructions: """
            あなたは料理動画の説明欄をレシピへ変換します。
            入力に明記されていない材料、分量、手順を推測して追加しないでください。
            URL、宣伝、ハッシュタグ、チャプター時刻は除外してください。
            出力は日本語にしてください。
            """)
        let response = try await session.respond(
            to: """
            動画タイトル: \(fallbackTitle)

            動画説明欄:
            \(description)
            """,
            generating: GeneratedRecipe.self
        )
        let generated = response.content
        return ExtractedRecipeData(
            title: generated.title,
            ingredients: generated.ingredients.map { .init(name: $0.name, amount: $0.amount) },
            steps: generated.steps,
            memo: generated.memo,
            method: .appleIntelligence
        )
    }
}
#endif
