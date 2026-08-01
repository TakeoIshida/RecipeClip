# レシピクリップ

YouTubeで見つけた料理動画を、材料・手順・メモと一緒に端末へ保存するiOSアプリです。

## 動作環境

- 開発・ローカルテスト: Xcode 16.4以降
- App Store提出: Xcode 26以降（iOS 26 SDK以降）
- iOS 17.0以降
- SwiftUI / SwiftData

## 起動方法

1. `RecipeClip.xcodeproj` をXcodeで開きます。
2. `RecipeClip` と `RecipeClipShareExtension` の Signing & Capabilities で同じDevelopment Teamを選びます。
3. Apple Developerで使える識別子に合わせ、必要ならBundle IDとApp Groupを変更します。
4. 両ターゲットのApp Groupsに `group.com.ishidatakeo.RecipeClip` が設定されていることを確認します。
5. `RecipeClip` スキームを選び、iPhoneまたはシミュレーターで実行します。

App Groupの値を変更する場合は、両ターゲットのentitlementsと
`Shared/SharedModelContainer.swift` の `appGroupIdentifier` を同じ値にしてください。

## 無料のレシピ自動作成

YouTubeリンクを追加画面へ貼り付けると動画情報を自動取得します。続けて動画の説明欄を
コピーして貼り付けると、ボタン操作なしで材料・手順・メモへ整理します。
説明欄をAPIから取得して派生データを作ることはYouTube APIポリシーで禁止されているため、
ユーザーが明示的に貼り付けた文章だけを端末内で解析します。

YouTube Data APIキー、有料AI API、アプリ用サーバーは使いません。動画タイトル、チャンネル、
サムネイルはYouTubeの公開oEmbedから取得します。

- Xcode 26／iOS 26以降かつApple Intelligence対応端末：端末内AIで構造化
- それ以外の端末：見出しや単位を判定する無料のルール解析
- 説明欄に材料や手順がない場合：同じ画面で手入力

現在のiOS 17対応は維持しています。Foundation Modelsのコードは、対応SDKでビルドした場合だけ
自動的に組み込まれます。

## 買い物リスト

レシピ詳細のボタンから、登録済みの材料をまとめて買い物リストへ追加できます。
同じレシピを再度追加すると、同名材料は増殖させず最新の分量に更新します。
別レシピ由来の同名材料は、分量を誤って合算しないよう別項目として保持します。
購入チェック、手動追加、個別削除、購入済みの一括削除に対応しています。

## テスト

```sh
xcodebuild test \
  -project RecipeClip.xcodeproj \
  -scheme RecipeClip \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

YouTube URLの正規化、oEmbed通信、無料ルール解析、取得失敗、SwiftData保存、並び順、検索、
買い物リストの登録・更新・削除をテストしています。

## App Store公開前チェックリスト

- Apple Developer Programへ加入し、本体とShare ExtensionのSigningを設定する
- App IDとApp GroupをDeveloper Portalでも作成し、両ターゲットへ割り当てる
- `PRIVACY_POLICY.md` の問い合わせ先を記入し、誰でも閲覧できるHTTPSページとして公開する
- App Store ConnectのプライバシーポリシーURLとサポートURLを設定する
- 初回起動の同意画面でポリシー本文と外部リンクが開けることを確認する
- App PrivacyはGoogleによる取扱いを含め、「おおよその位置情報」と「製品の操作」を、アプリ機能目的・ユーザーに関連付けない・トラッキングなしとして申告する
- アプリ名、サブタイトル、説明、キーワード、カテゴリ、年齢区分、著作権表記を登録する
- 必要なiPhone／iPadのスクリーンショットを実機表示から作成する
- Xcode 26以降でArchiveし、Validate Appを通してからTestFlightで実機確認する
- 審査メモに「ログイン不要」「YouTube共有メニューの確認手順」「レシピ自動作成の操作」を記載する

保存したYouTubeのチャンネル名とサムネイルは、YouTubeポリシーに合わせて29日を超えると
アプリ復帰時に更新します。料理名はユーザーが編集するレシピ名として扱い、自動更新では上書きしません。
