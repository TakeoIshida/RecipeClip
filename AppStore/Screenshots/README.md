# RecipeClip App Storeスクリーンショット

## 自動撮影

Xcodeと対応するiOS SimulatorをインストールしたMacで、リポジトリ直下から実行する。

```sh
chmod +x AppStore/Screenshots/capture.sh
AppStore/Screenshots/capture.sh
```

既定の `iPhone 16 Pro Max` がない場合は、手元にあるSimulator名を渡す。

```sh
AppStore/Screenshots/capture.sh "iPhone 17 Pro Max"
```

iPad版は、第2引数で出力セット名を分けて撮影する。`iPad Pro (12.9-inch) (6th generation)` の2048×2732pxは、13インチ用に受け付けられる縦長サイズ。

```sh
AppStore/Screenshots/capture.sh "iPad Pro (12.9-inch) (6th generation)" "ipad-13"
```

英語版は第3・第4引数に言語とロケールを指定する。撮影用の架空レシピも英語へ切り替わる。

```sh
AppStore/Screenshots/capture.sh "iPhone 16 Pro Max" "en-US" "en" "en_US"
```

`AppStore/Screenshots/output` に次の順番でPNGが生成される。

1. `01-recipes.png` — レシピ一覧
2. `02-organized-editor.png` — 説明文から自動整理した編集画面
3. `03-detail.png` — レシピ詳細
4. `04-shopping.png` — 買い物リスト
5. `05-cooking.png` — 調理モード

## 撮影モードの仕様

`--app-store-screenshot <scene>` を付けて起動すると、撮影専用のメモリ内データベースを使う。ユーザーの通常データは読み書きせず、プライバシー同意とオンボーディングも撮影時だけ迂回する。

使えるscene名は `recipes`、`organized-editor`、`detail`、`shopping`、`cooking` の5つ。Xcodeから手動確認する場合は Scheme > Run > Arguments へ、例えば次を追加する。

```text
--app-store-screenshot
detail
```

## 権利・表示の方針

- レシピ名、材料、手順、チャンネル名は撮影用に作った架空の内容。
- サムネイルは写真やYouTube画像を取得せず、アプリ内で色と図形だけを描画して生成。
- 第三者のロゴ、人物、キャラクター、商品パッケージは表示しない。
- 撮影はライトモード、9:41、バッテリー100%に固定し、5枚を同じSimulatorで取得する。日本語が既定で、引数で英語にも切り替えられる。

生成後は5枚のピクセルサイズが同一で、個人情報、デバッグ表示、ローディング表示が映り込んでいないことを目視で確認する。
