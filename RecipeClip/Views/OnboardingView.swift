import SwiftUI

enum OnboardingState {
    static let currentVersion = 1
    static let key = "completedOnboardingVersion"

    static var isCompleted: Bool {
        UserDefaults.standard.integer(forKey: key) >= currentVersion
    }

    static func complete() {
        UserDefaults.standard.set(currentVersion, forKey: key)
    }
}

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var page = 0

    private let pages = [
        GuidePage(
            symbol: "square.and.arrow.up",
            tint: .red,
            title: "YouTubeからすぐ保存",
            message: "料理動画の共有ボタンを押して「動画レシピ帳」を選ぶだけ。動画名とチャンネルを下書き保存できるよ。",
            tip: "共有先に見当たらないときは「その他」から追加してね。"
        ),
        GuidePage(
            symbol: "wand.and.stars",
            tint: .purple,
            title: "説明欄からレシピを作成",
            message: "動画の説明欄をコピーして編集画面へ貼り付けよう。貼った瞬間に、材料と手順を端末内で自動整理するよ。",
            tip: "取得できない内容は、そのまま手入力で直せるよ。"
        ),
        GuidePage(
            symbol: "cart.badge.plus",
            tint: .green,
            title: "料理も買い物も迷わない",
            message: "詳細画面から材料を買い物リストへ一括追加。料理を始めたら調理モードで、大きな手順を1つずつ確認できるよ。",
            tip: "大切なデータはアプリ情報からバックアップしてね。"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < pages.count - 1 {
                    Button("スキップ") { finish() }
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 28) {
                        Spacer()
                        Image(systemName: item.symbol)
                            .font(.system(size: 68, weight: .semibold))
                            .foregroundStyle(item.tint)
                            .frame(width: 132, height: 132)
                            .background(item.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 32))
                            .accessibilityHidden(true)

                        VStack(spacing: 14) {
                            Text(item.title)
                                .font(.largeTitle.bold())
                                .multilineTextAlignment(.center)
                            Text(item.message)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                            Label(item.tip, systemImage: "lightbulb.fill")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 28)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if page == pages.count - 1 {
                    finish()
                } else {
                    withAnimation { page += 1 }
                }
            } label: {
                Text(page == pages.count - 1 ? LocalizedStringKey("はじめる") : LocalizedStringKey("次へ"))
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .background(Color(.systemBackground))
    }

    private func finish() {
        OnboardingState.complete()
        onComplete()
    }
}

private struct GuidePage {
    let symbol: String
    let tint: Color
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let tip: LocalizedStringKey
}
