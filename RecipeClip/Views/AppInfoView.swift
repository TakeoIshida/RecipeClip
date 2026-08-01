import SwiftUI

struct AppInfoView: View {
    var body: some View {
        List {
            Section("レシピクリップについて") {
                Label("YouTubeの料理動画を、自分用のレシピとして端末に保存するアプリだよ。", systemImage: "fork.knife")
                LabeledContent("バージョン", value: versionText)
            }

            Section("使い方とデータ") {
                NavigationLink {
                    GuideReplayView()
                } label: {
                    Label("使い方ガイドを見る", systemImage: "questionmark.circle")
                }

                NavigationLink {
                    BackupRestoreView()
                } label: {
                    Label("バックアップと復元", systemImage: "externaldrive")
                }
            }

            Section("プライバシー") {
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Label("プライバシーポリシー", systemImage: "hand.raised")
                }

                Text("料理名、材料、手順、メモ、お気に入り、買い物リストは、この端末内だけに保存するよ。アカウント登録、広告、アクセス解析、トラッキングは使っていないよ。")
                Text("動画情報の取得時は、動画IDをYouTube／Googleへ送信するよ。通信に伴い、GoogleがIPアドレス、端末・アプリ情報、リクエスト日時などを扱う場合があるよ。自分で貼り付けた説明欄は端末内で処理し、説明欄そのものは保存しないよ。")
                Text("保存したデータは、レシピ一覧と買い物リストから削除できるよ。アプリを削除すると端末内のデータも削除されるため、必要に応じてバックアップを書き出してね。")
            }

            Section("外部サービス") {
                Text("本アプリはYouTube API Servicesを使用するよ。本アプリを利用すると、YouTube利用規約にも同意したものとみなされるよ。")
                Link(destination: URL(string: "https://www.youtube.com/t/terms")!) {
                    Label("YouTube 利用規約", systemImage: "arrow.up.right.square")
                }
                Link(destination: URL(string: "https://policies.google.com/privacy")!) {
                    Label("Google プライバシーポリシー", systemImage: "arrow.up.right.square")
                }
                Link(destination: URL(string: "https://security.google.com/settings/security/permissions")!) {
                    Label("Google セキュリティ設定", systemImage: "arrow.up.right.square")
                }
            }

            Section {
                Text("このアプリはYouTubeまたはGoogleが提供・承認する公式アプリではないよ。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("アプリ情報・プライバシー")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section("保存する情報") {
                Text("料理名、動画URL、チャンネル名、材料、手順、メモ、買い物リスト、お気に入り状態、サムネイルは端末内に保存するよ。運営者が管理するサーバーへの送信、アカウントとの関連付け、広告目的の利用は行わないよ。")
            }

            Section("YouTube・Googleとの通信") {
                Text("動画情報を取得するため、指定された動画IDをYouTubeおよびGoogleのサービスへ送信し、動画タイトル、チャンネル名、サムネイルを取得するよ。この通信に伴い、GoogleがIPアドレス、端末・アプリ情報、リクエスト日時などを取り扱う場合があるよ。通信にはCookieを保存しない一時セッションを使うよ。")
                Text("自分で貼り付けた動画説明欄は端末内のレシピ作成にだけ使い、説明欄そのものは保存または外部送信しないよ。")
                Link("YouTube 利用規約", destination: URL(string: "https://www.youtube.com/t/terms")!)
                Link("Google プライバシーポリシー", destination: URL(string: "https://policies.google.com/privacy")!)
                Link("Google セキュリティ設定", destination: URL(string: "https://security.google.com/settings/security/permissions")!)
            }

            Section("トラッキングと解析") {
                Text("広告SDK、アクセス解析SDK、ユーザーを横断的に追跡する技術は使わないよ。")
            }

            Section("データの削除とバックアップ") {
                Text("保存したレシピと買い物リストはアプリ内から削除できるよ。アプリを端末から削除すると、アプリが保存したデータも削除されるよ。バックアップを書き出した場合は、保存先の管理は自分で行ってね。")
            }

            Section("ポリシーの変更") {
                Text("機能や利用サービスを変更した場合、このポリシーを更新することがあるよ。")
                LabeledContent("最終更新日", value: "2026年8月1日")
            }
        }
        .navigationTitle("プライバシーポリシー")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GuideReplayView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        OnboardingView { dismiss() }
            .navigationBarBackButtonHidden(false)
    }
}
