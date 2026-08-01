import SwiftUI

struct PrivacyConsentView: View {
    let onAccept: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.tint)
                        .frame(maxWidth: .infinity)

                    Text("はじめる前に")
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity, alignment: .center)

                    consentRow(
                        icon: "iphone",
                        title: "レシピは端末内に保存",
                        description: "料理名、材料、手順、メモ、買い物リストは運営者のサーバーへ送信しないよ。"
                    )
                    consentRow(
                        icon: "network",
                        title: "動画情報はYouTubeから取得",
                        description: "動画IDを送信してタイトル、チャンネル、サムネイルを取得するよ。GoogleがIPアドレスなどを扱う場合があるよ。"
                    )
                    consentRow(
                        icon: "wand.and.stars",
                        title: "説明欄の解析は端末内",
                        description: "自分で貼り付けた説明欄だけを解析し、説明欄そのものは保存しないよ。"
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        NavigationLink("レシピクリップのプライバシーポリシー") {
                            PrivacyPolicyView()
                        }
                        Link("Google プライバシーポリシー", destination: URL(string: "https://policies.google.com/privacy")!)
                        Link("YouTube 利用規約", destination: URL(string: "https://www.youtube.com/t/terms")!)
                        Text("「同意してはじめる」を押すと、上記の内容とYouTube利用規約に同意したものとみなされるよ。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button(action: onAccept) {
                        Text("同意してはじめる")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(24)
            }
            .navigationTitle("プライバシー")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }

    private func consentRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(description)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
