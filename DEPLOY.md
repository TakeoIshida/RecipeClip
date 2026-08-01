# GitHub ActionsでApp Store Connectへデプロイ

## 目的

このMacで動くXcode 16.4では2026年のApp Store提出要件を満たせないため、ClickGirlで実績のあるGitHub Actions方式をレシピクリップ用に移植している。

Workflow: `.github/workflows/deploy.yml`

## Apple Developer側で事前に作成するもの

1. App ID: `com.ishidatakeo.RecipeClip`
2. Share Extension App ID: `com.ishidatakeo.RecipeClip.ShareExtension`
3. App Group: `group.com.ishidatakeo.RecipeClip`
4. 両方のApp IDでApp Groupsを有効化し、上記App Groupを割り当てる
5. App Store ConnectでBundle ID `com.ishidatakeo.RecipeClip`のアプリを作成する

Team IDはClickGirlで使用中の`JS3245KG7Q`を設定済み。

## GitHub Secrets

ClickGirlと同じGitHubアカウントで配布する場合、証明書とApp Store Connect API Keyは同じ値を登録できる。Secretの値自体はリポジトリに保存しないこと。

| Secret | 内容 |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | Apple Distribution証明書（P12）のBase64 |
| `P12_PASSWORD` | P12のパスワード |
| `KEYCHAIN_PASSWORD` | Actions内の一時キーチェーン用任意文字列 |
| `ASC_KEY_ID` | App Store Connect API Key ID |
| `ASC_ISSUER_ID` | App Store Connect Issuer ID |
| `ASC_API_KEY_BASE64` | App Store Connect `.p8`キーのBase64 |

## GitHubリポジトリ作成後

```sh
git remote add origin <RECIPECLIP_REPOSITORY_URL>
git push -u origin main
gh workflow run deploy.yml --repo TakeoIshida/<RECIPECLIP_REPOSITORY_NAME>
```

Workflowは次の順番で実行する。

1. Xcode 26を選択
2. Apple Distribution証明書とApp Store Connect API Keyを一時設定
3. 16件の単体テストを実行
4. 本体とShare Extensionを自動署名でArchive
5. IPAを書き出し
6. App Store Connectへアップロード

## バージョン

初回は`1.0 (1)`。一度でもApp Store Connectへアップロードした後は、再アップロードの前に`CURRENT_PROJECT_VERSION`を増やす。

## 注意

- 初回はGitHub Actionsが自動プロビジョニングプロファイルを作成できる権限のApp Store Connect API Keyを使う。
- 自動署名でプロファイルを作れない場合は、本体用とShare Extension用の2つのApp Store配布プロファイルをSecret化し、`ExportOptions.plist`を手動署名に切り替える。
- App GroupのCapability登録がないとArchiveは失敗する。
- Workflowを実行する前に、必ずビルド番号が未使用か確認する。
