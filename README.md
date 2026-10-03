# Teams Bot Template

TypeScript + Azure Functions + Terraform で構築する Microsoft Teams Bot テンプレートです。

## ツールスタック

| ツール                        | 役割                                                     |
| ----------------------------- | -------------------------------------------------------- |
| [Vite+](https://viteplus.dev) | ビルド・lint・format・test の統合ツールチェーン（alpha） |
| tsdown / Rolldown             | バンドラー（Vite+ 経由）                                 |
| Oxlint                        | Linter（Vite+ 経由）                                     |
| Oxfmt                         | フォーマッター（Vite+ 経由）                             |
| Vitest                        | テスト（Vite+ 経由）                                     |
| Terraform                     | Azure インフラ管理                                       |

## アーキテクチャ

```
Teams クライアント
    ↓ メッセージ
Azure Bot Service（チャンネル登録）
    ↓ Bot Framework プロトコル
Azure Functions（HTTP トリガー）
    ↓
Bot ロジック（TypeScript）
```

### コード構造とリクエストフロー

Teams からのメッセージは以下の順に処理されます。

```
src/functions/messages.ts  ← HTTP リクエスト受信（エントリーポイント）
    ↓
src/bot/adapter.ts         ← 認証・署名検証（CloudAdapter）
    ↓
src/bot/bot.ts             ← メッセージ処理（ボットロジック）
```

| ファイル                    | 役割                           | 編集           |
| --------------------------- | ------------------------------ | -------------- |
| `src/bot/bot.ts`            | メッセージ処理（ロジック本体） | **ここを編集** |
| `src/bot/adapter.ts`        | 認証・署名検証                 | 触らない       |
| `src/functions/messages.ts` | HTTP エントリーポイント        | 触らない       |

Teams からのメッセージは種類（テキスト、メンバー追加など）に関係なく、すべて `POST /api/messages` に届きます。`TeamsActivityHandler` が `activity.type` を見て `onMessage` や `onMembersAdded` などのハンドラーに振り分け、テキストコマンドの分岐は `bot.ts` の `onMessage` 内で if/else で行います。

#### コマンドが増えたら

コマンドが少ないうちは `bot.ts` に直書きで十分ですが、増えてきたら `commands/` ディレクトリに分割してください。

```
src/bot/
├── bot.ts              ← ハンドラー登録（振り分けだけ）
├── adapter.ts
└── commands/           ← コマンドごとにファイル分割
    ├── hello.ts
    └── help.ts
```

## Azureリソース構成

| リソース                           | 説明                                |
| ---------------------------------- | ----------------------------------- |
| Azure Functions (Flex Consumption) | Bot のメッセージ処理エンドポイント  |
| Azure Bot Service                  | Teams チャンネル登録・認証          |
| Azure AD App Registration          | Bot 認証用のアプリ登録              |
| Application Insights               | ログ・監視                          |
| Log Analytics Workspace            | Application Insights のバックエンド |
| Storage Account                    | Functions の実行基盤                |
| Azure Key Vault                    | ボット認証情報の管理                |

## 前提条件

- [Node.js 24](https://nodejs.org/)
- [pnpm 9+](https://pnpm.io/installation)
- [Azure CLI](https://learn.microsoft.com/ja-jp/cli/azure/install-azure-cli)
- [tfenv](https://github.com/tfutils/tfenv)（Terraform バージョン管理）
- [Azure Functions Core Tools v4](https://learn.microsoft.com/ja-jp/azure/azure-functions/functions-run-local)
- [jq](https://jqlang.github.io/jq/)
- Azure サブスクリプション

### インストール（macOS）

```bash
brew install azure-cli
brew install tfenv
tfenv install  # infra/.terraform-version のバージョンをインストール
brew tap azure/functions
brew install azure/functions/azure-functions-core-tools@4
brew install jq
```

## ローカル開発

### 1. セットアップ

```bash
pnpm install
cp local.settings.json.example local.settings.json
```

> **Note:** Azure Functions Core Tools (`func start`) は起動時に `local.settings.json` を読み込み、`Values` 内のキーを環境変数（`process.env.*`）として注入します（`.env` ではなくこのファイルが Azure Functions の規約です）。ローカルテストでは認証情報は空のままで動作しますが、`local.settings.json` ファイル自体がないと起動できません。このファイルは後の手順で実際の認証情報が書き込まれるため `.gitignore` で管理外にしており、`cp` で初回に作成する必要があります。

### 2. ボットロジックの実装

`src/bot/bot.ts` の `TeamsBot` クラスを編集してロジックを追加します。

```typescript
this.onMessage(async (context, next) => {
  const text = context.activity.text?.trim() ?? "";
  // ここにロジックを追加
  await next();
});
```

### 3. ビルド・起動

```bash
pnpm start        # ビルド後に Azure Functions Core Tools で起動
                  # エンドポイント: http://localhost:7071/api/messages
```

### 4. Agents Playground でのテスト

[Agents Playground](https://learn.microsoft.com/ja-jp/microsoftteams/platform/toolkit/debug-your-agents-playground) はローカルで動作するボットにメッセージを送り、応答を確認できるテストツールです。Microsoft 365 のアカウントやトンネリング、アプリ登録なしでテストできます。

```bash
# pnpm start でボットを起動した状態で、別のターミナルから実行
BOT_ENDPOINT=http://localhost:7071/api/messages npx @microsoft/teams-app-test-tool
```

ブラウザが開き、Teams 風のチャット画面が表示されます。下部の入力欄から `hello` や `ヘルプ` などを送信し、ボットが応答することを確認してください。それ以外のメッセージはエコーバックされます。

> **Note:** デフォルトの接続先は `http://localhost:3978/api/messages` のため、`BOT_ENDPOINT` 環境変数で Azure Functions のポート（7071）を指定しています。

### 5. その他のコマンド

```bash
pnpm run build        # バンドル（dist/ に出力）
pnpm run watch        # ウォッチモード
pnpm run lint         # Oxlint
pnpm run fmt          # Oxfmt（フォーマット）
pnpm run typecheck    # tsc --noEmit（型チェック）
pnpm test             # Vitest（1回実行）
pnpm run test:watch   # Vitest（ウォッチモード）
```

## ボットのカスタマイズ

### 1. ボット名の設定（初回のみ）

```bash
make setup-manifest
```

### 2. manifest.json の編集

`appPackage/manifest.json` を用途に合わせて編集してください（会社情報、コマンド一覧など）。

## インフラ構築（初回のみ）

Azure リソースの作成は、テンプレートから新しいプロジェクトを作成した際に **1回だけ** 実行します。
手順は [infra/README.md](infra/README.md) を参照してください。

## デプロイ

### Function App のデプロイ（GitHub Actions）

GitHub Actions の UI から手動でデプロイします。

1. GitHub リポジトリの **Actions** タブを開く
2. **Deploy to Azure Functions** ワークフローを選択
3. **Run workflow** をクリック
4. デプロイ先（`stg` / `prod`）を選択
5. `appPackage/` 配下（`manifest.json` やアイコン画像）を変更した場合は **「Teams アプリも更新する」** にチェックを入れて実行

> **前提:** デプロイには GitHub Actions から Azure への認証設定が必要です。先に [infra/README.md](infra/README.md) のインフラ構築を完了してください。

### Teams アプリの登録・更新（手動）

Teams アプリのカタログへの登録は手動で行います（Graph API が CI/CD からの自動デプロイに対応していないため）。

#### ZIP パッケージの取得

上記のデプロイで「Teams アプリも更新する」にチェックを入れて実行すると、GitHub Actions の Artifacts に ZIP が保存されます。Actions の実行結果ページを開き、**`teams-app-` で始まる方**（例: `teams-app-stg-1`）をダウンロードしてください。`deploy-package` はデプロイ時に内部で使用されるもので、ダウンロード不要です。

#### アイコン要件

Teams アプリには2つの PNG アイコンが必要です。

| アイコン      | サイズ       | 用途                   |
| ------------- | ------------ | ---------------------- |
| `color.png`   | 192 x 192 px | ストア、フライアウト等 |
| `outline.png` | 32 x 32 px   | アプリバー等           |

- ロゴは中央の 120 x 120 px セーフエリア内に収める
- 角丸・ボーダーは Teams が自動付与するため、正方形のまま提出する
- コントラスト比 4.5:1 以上を推奨

詳細は [Microsoft 公式ガイドライン](https://learn.microsoft.com/en-us/microsoftteams/platform/concepts/design/design-teams-app-icon-store-appbar)を参照。

#### Teams 管理センターからアップロード

1. [Teams 管理センター](https://admin.teams.microsoft.com/) を開く
2. **Teams のアプリ** > **アプリを管理** を選択
3. 初回: **アップロード** > ZIP ファイルを選択して登録
4. 更新: 該当アプリを選択して削除 > **アップロード** で ZIP を再登録

登録後、以下の方法でボットを使用できます：

- **チャンネル**: ボットをチームにインストール後、`@ボット名 hello` のようにメンションして使用
- **グループチャット**: ボットをグループチャットに追加後、メッセージを送信して使用

> **Note:** 本ボットは個人チャット（1対1チャット）には対応していません。

ボット名は `appPackage/manifest.json` の `name.short` で定義されています。デフォルトでは stg 環境に `@Teams Bot [stg] hello`、prod 環境に `@Teams Bot hello` のようにメンションします。変更する場合は `manifest.json` の `name.short` を編集してください。

### トラブルシューティング

#### `ManifestFileNotFound: The provided stream does not contain a "manifest.json" file.`

ZIP 内に `manifest.json` が存在しないか、ファイル名が異なっている。以下を確認：

- ZIP を解凍して `manifest.json` がルートに存在するか
- ビルド過程でファイル名が変わっていないか

#### `Schema validation failed at '<property>': Property "<property>" has not been defined and the schema does not allow additional properties.`

`manifest.json` に、スキーマバージョンで許可されていないプロパティが含まれている。`$schema` が指す[スキーマ定義](https://learn.microsoft.com/en-us/microsoftteams/platform/resources/schema/manifest-schema)を確認し、不要なプロパティを削除する。

#### `SyntaxError: Named export 'XXX' not found. The requested module 'botbuilder' is a CommonJS module`

`botbuilder` は CommonJS モジュールのため、ESM 形式でバンドルすると Azure Functions ランタイム上で named import が失敗する。ビルド出力は CJS 形式（`format: "cjs"`）にすること。`vite.config.ts` の `pack.format` が `"esm"` になっていないか確認する。

## ボットの動作

### Teams 上での挙動

ボットはインストールされた場所にのみ反応します。利用可能なスコープはチーム（チャンネル）とグループチャットのみです。

| 場所             | 反応条件                                                                       |
| ---------------- | ------------------------------------------------------------------------------ |
| チャンネル       | `@ボット名 hello` のようにメンションが必要                                     |
| グループチャット | ボットをグループに追加後、メッセージで反応                                     |
| 1対1チャット     | 非対応（メッセージを送ると、チームまたはグループチャットで使うよう案内を返す） |

個人チャット非対応は、`appPackage/manifest.json` の `scopes`（`personal` を含めない）と、`src/bot/bot.ts` での `conversationType === "personal"` 判定の二重で担保しています。

### デフォルトのコマンド

| メッセージ             | 応答                                                 |
| ---------------------- | ---------------------------------------------------- |
| `hello` / `こんにちは` | 「こんにちは、{送信者名} さん！」                    |
| `help` / `ヘルプ`      | コマンド一覧のヘルプカード（Adaptive Card）          |
| それ以外               | 「受け取ったメッセージ: "{送信内容}"」とエコーバック |

英字コマンド（`hello` / `help`）は大文字・小文字を区別しません。

## ライセンス

MIT
