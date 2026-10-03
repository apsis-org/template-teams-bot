# CLAUDE.md

このファイルは Claude Code がこのリポジトリで作業する際のガイドラインです。

## プロジェクト概要

TypeScript + Azure Functions v4 + Terraform で構築する Microsoft Teams Bot テンプレートリポジトリ。

## コマンド

```bash
# ビルド（Vite+ / tsdown によるバンドル）
pnpm run build          # dist/ にバンドル出力
pnpm run watch          # ウォッチモード

# ローカル起動
pnpm start              # ビルド後に Azure Functions Core Tools で起動
                        # エンドポイント: http://localhost:7071/api/messages

# コード品質（Vite+ 統合）
pnpm run lint           # Oxlint
pnpm run fmt            # Oxfmt（フォーマット）
pnpm test               # Vitest（1回実行）
pnpm run test:watch     # Vitest（ウォッチモード）

# Terraform（環境ディレクトリで実行）
cd infra/envs/stg    # または infra/envs/prod
terraform init
terraform plan
terraform apply
```

## アーキテクチャ

```
Teams クライアント → Azure Bot Service → Azure Functions → Bot ロジック
```

### 主要ファイル

| ファイル | 役割 |
|----------|------|
| `src/functions/messages.ts` | Azure Functions HTTP トリガー（エントリーポイント） |
| `src/bot/bot.ts` | `TeamsActivityHandler` を継承したボットロジック |
| `src/bot/adapter.ts` | `CloudAdapter` の設定・エラーハンドリング |
| `infra/main.tf` | Azure リソース定義（共通モジュール） |
| `infra/envs/stg/` | stg 環境の Terraform root |
| `infra/envs/prod/` | prod 環境の Terraform root |
| `infra/modules/function_app/` | Function App / Storage / App Service Plan |
| `infra/modules/bot_service/` | Azure Bot Service + Teams チャンネル |
| `infra/modules/monitoring/` | Application Insights + Log Analytics |
| `appPackage/manifest.json` | Teams アプリマニフェスト |

## 開発ガイドライン

### TypeScript

- `strict: true` を維持すること
- `any` 型は使わない。やむを得ない場合は `unknown` を使う
- モジュールは ESM（`"type": "module"`、`"module": "ESNext"`、`"moduleResolution": "Bundler"`）
- バンドラー（tsdown）が解決するため相対インポートに `.js` 拡張子は不要
- Node.js 組み込みモジュールは `node:` プレフィックスを使う（`import { Readable } from "node:stream"`）
- ビルド・lint・format・test はすべて `vite.config.ts` で一元管理（Vite+ 統合）

### ボットロジックの追加

`src/bot/bot.ts` の `TeamsBot` クラスに追加する。`onMessage` ハンドラー内でコマンドを分岐させるパターンを踏襲すること。

```typescript
this.onMessage(async (context, next) => {
  const text = context.activity.text?.trim() ?? "";
  // ロジックを追加
  await next(); // 必ず呼ぶ
});
```

#### メッセージテキストの改行

Teams はボットのテキストを **Markdown として解釈**するため、改行は以下のいずれかで書く：

- `\n\n`（段落区切り。通常はこちらを使う）
- `  \n`（末尾半角スペース2個 + `\n` でハード改行。段落間隔なしで改行したい場合）

`\n` 単発は Markdown では空白扱いで改行されない。複数行メッセージや箇条書きを組み立てる際は `\n\n` を基本とすること。

### 利用可能スコープ

本ボットは **team / groupChat のみ対応**（個人チャット非対応）。

- `appPackage/manifest.json` の `bots[].scopes` / `commandLists[].scopes` に `personal` を含めない
- `src/bot/bot.ts` 側でも `onMessage` / `onMembersAdded` 冒頭で `context.activity.conversation.conversationType === "personal"` を判定し、案内メッセージを返して早期 return する防御的実装を維持すること

### ビルド設定

- `vite.config.ts` の `pack.entry` はオブジェクト形式 `{ index: "src/functions/messages.ts" }` で `dist/index.js` を出力
- `fixedExtension: false` を指定（`platform: "node"` のデフォルトは `true` で `.mjs` 出力になるため）
- `package.json` の `main`（`dist/index.js`）とビルド出力を一致させること

### Azure Functions

- Azure Functions v4 プログラミングモデルを使用（`app.http()` で登録）
- `authLevel: "anonymous"` は Bot Framework が独自に署名検証するため意図的な設定
- `route` は `"messages"` とする（Azure Functions が自動で `/api` プレフィックスを付与するため、`"api/messages"` にすると `/api/api/messages` になる）
- `host.json` の extensionBundle バージョンは `[4.*, 5.0.0)` を維持

### Terraform

- 環境ごとにディレクトリ分離: `infra/envs/stg/`, `infra/envs/prod/`（state が完全に分離）
- `infra/` 直下は共通モジュール。直接 `terraform apply` しない
- モジュール分割: `function_app` / `bot_service` / `monitoring` / `key_vault`
- リソース名はすべて `prefix`（`${project_name}-${environment}`）を使って命名
- 機密値（パスワード等）は `sensitive = true` を付ける
- Function App は Flex Consumption（FC1）プラン。`azurerm_function_app_flex_consumption` リソースを使用
- Bot 認証タイプは `SingleTenant`（MultiTenant は Azure により廃止）
- `azurerm_bot_service_azure_bot.display_name` は `appPackage/manifest.json` の `name.short` を `jsondecode` で読み込み、`__ENV_SUFFIX__` を `build-teams-app.yml` と同じ規則で置換して導出する。ボット表示名のハードコードは禁止（manifest を Single Source of Truth として扱う）

### GitHub Actions

- Azure 認証はサービスプリンシパル（`AZURE_CREDENTIALS`）を使用。Key Vault から自動取得
- `deploy-functions.yml`: `workflow_dispatch` のみ。Function App へのデプロイと Teams アプリパッケージのビルドを選択実行
- `build-teams-app.yml`: Teams アプリの ZIP パッケージを生成し Artifact として保存。Teams 管理センターへのアップロードは手動

## 環境変数

ローカル開発は `local.settings.json`（`.gitignore` 済み）、本番は Function App の App Settings で管理。

| 変数名 | 説明 |
|--------|------|
| `MicrosoftAppId` | Bot 認証用 App ID |
| `MicrosoftAppPassword` | Bot 認証用シークレット |
| `MicrosoftAppType` | `SingleTenant` / `UserAssignedMSI`（MultiTenant は廃止） |
| `MicrosoftAppTenantId` | SingleTenant 時のテナント ID |

## 注意事項

- `local.settings.json` は絶対にコミットしない
- `*.tfvars` も `.gitignore` 済みのため、コミットしない
- `appPackage/manifest.json` のプレースホルダー（`__BOT_ID__` 等）はデプロイ時に自動置換される
- Terraform の `azurerm_bot_service_azure_bot` の `location` は `"global"` 固定（Azure の仕様）

### 機密ファイルの取り扱い（Claude Code 権限）

`.claude/settings.json` で `.env` 系 / `.tfvars` 系 / `local.settings.json` の読み込みをブロックしている。**読もうとしないこと**。

- **allow**
  - `.env.example`
  - `**/*.tfvars.example`
  - `local.settings.json.example`
- **deny（Read）**
  - `.env` / `*.env` / `.env.local` / `.env.development(.*)` / `.env.production(.*)` / `.env.staging(.*)` / `.env.test(.*)` / `.env.*.local`
  - `**/*.tfvars` / `**/*.tfvars.json` / `**/*.auto.tfvars` / `**/*.auto.tfvars.json`
  - `local.settings.json`
- **deny（Bash）**: 上記ファイルに対する `cat` / `head` / `tail` / `less` / `more` / `grep` / `sed` / `awk` / `vim` / `nano` / `bat`

環境変数や Terraform 変数の中身を確認したい場合は `.env.example` / `*.tfvars.example` / `local.settings.json.example` を参照し、実ファイルの値はユーザーに確認すること。
