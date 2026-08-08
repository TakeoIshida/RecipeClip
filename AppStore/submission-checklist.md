# App Store提出チェックリスト

## コードとビルド

- [x] Bundle ID: `com.ishidatakeo.RecipeClip`
- [x] Share Extension Bundle ID: `com.ishidatakeo.RecipeClip.ShareExtension`
- [x] App Group: `group.com.ishidatakeo.RecipeClip`
- [x] バージョン 1.0 / ビルド 2
- [x] アプリアイコン 1024 x 1024、アルファなし
- [x] 輸出コンプライアンス: 非免除暗号化の使用なし
- [x] プライバシーマニフェストを本体とExtensionに同梱
- [x] APIキー・有料AIキー・独自サーバーの秘密情報なし
- [ ] Xcode 26以降とiOS 26 SDK以降でビルド
- [x] ClickGirlで使用中のApple Team ID `JS3245KG7Q`をデプロイ設定に反映
- [ ] Apple Developerで本体・ExtensionのApp IDと配布用署名を有効化
- [ ] App IDとApp GroupをDeveloper Portalで登録
- [ ] Release ArchiveをValidate Appで検証
- [ ] TestFlightで実機確認
- [x] Xcode 26でテスト・Archive・アップロードするGitHub Actionsを準備

## App Store Connect

- [ ] アプリ名の予約・重複確認
- [ ] SKUを決定（例: `recipeclip-ios-001`）
- [ ] バンドルIDを選択
- [ ] 一次カテゴリを「フード／ドリンク」に設定
- [ ] 年齢区分の最新質問票に回答
- [ ] 価格を日本100円相当の価格ポイントに設定
- [ ] 公開地域を確定
- [ ] App Privacyを`privacy-answers.md`に沿って入力
- [ ] サポートURLを公開・入力
- [ ] プライバシーポリシーURLを公開・入力
- [ ] 著作権表記を入力
- [ ] 審査連絡先（氏名、電話、メール）を入力
- [ ] 審査メモを貼り付け

## スクリーンショット

- [x] レシピ一覧
- [x] 説明欄から自動整理した編集画面
- [x] 材料・手順が入ったレシピ詳細
- [x] 買い物リスト
- [x] 調理モード
- [x] iPhone 6.9インチ用 1290 x 2796px
- [x] iPad 13インチ用 2048 x 2732px
- [x] 架空レシピとコード描画サムネイルのみを掲載
- [x] 個人情報・通知・実データなし、時刻9:41で統一を目視確認

## 手動QA

- [ ] 新規インストールから同意画面・初回ガイドを確認
- [ ] 通常URL、短縮URL、Shorts、埋め込みURLを確認
- [ ] オフラインで手入力保存できることを確認
- [ ] Share Extension保存がアプリ復帰後すぐ表示されることを確認
- [ ] 買い物リストの個別・一括追加と重複更新を確認
- [ ] バックアップ後に復元し、内容が一致することを確認
- [ ] 調理モードの自動ロック防止と終了を確認
- [ ] Dynamic Type、VoiceOver、ダークモードを確認
- [ ] iOS 17と最新iOSの実機またはシミュレータで確認
