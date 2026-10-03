# インフラ構築ガイド

このドキュメントは、テンプレートから新しいプロジェクトを作成した際に **1回だけ** 実行するインフラ構築手順です。
他の開発者はルートの [README.md](../README.md) の「ローカル開発」セクションから始めてください。

## ディレクトリ構成

環境ごとにディレクトリが分かれており、state が完全に分離されています。

```
infra/
  envs/
    terraform.tfvars.example      ← project_name を設定（stg/prod 共通）
    terraform.tfvars              ← ↑を cp して作成（.gitignore 済み）
    stg/
      main.tf                     ← stg 環境の root
      terraform.tfvars → ../terraform.tfvars（シンボリックリンク）
    prod/
      main.tf                     ← prod 環境の root
      terraform.tfvars → ../terraform.tfvars（シンボリックリンク）
  main.tf                         ← 共通モジュール（直接実行しない）
```

## 事前準備: 組織共通のセットアップ（組織で1回のみ）

GitHub Actions から Azure へデプロイするためのサービスプリンシパルと、その認証情報を保管する組織共通の Key Vault を用意します。
**組織で1回だけ**行う作業で、このテンプレートから2つ目以降のボットを作る場合は不要です（④の Key Vault 名だけ確認してください）。

Azure Portal（サブスクリプションの Owner 権限が必要）で以下を行ってください：

**① サービスプリンシパルの作成**
1. Microsoft Entra ID → アプリの登録 → 新規登録
2. 名前: `sp-github-actions`、登録
3. 証明書とシークレット → 新しいクライアントシークレット → 追加
4. 表示された**値**をメモ（一度しか表示されません）

**② ロールの割り当て**
1. サブスクリプション → アクセス制御 (IAM) → ロール割り当ての追加
2. ロール: **共同作成者**、メンバー: `sp-github-actions` を選択
3. 保存

**③ 組織共通 Key Vault の作成**
1. リソースグループ `rg-shared` を作成
2. Key Vault を作成（例: `kv-<組織名>-gh-actions`）、リージョン: `Japan East`、アクセス許可モデル: Azure RBAC
3. シークレットを登録：
   - `sp-github-actions-client-id`：クライアント ID
   - `sp-github-actions-client-secret`：クライアントシークレット
4. 開発者全員に **キー コンテナー シークレット責任者** ロールを付与

**④ Key Vault 名を控える**

③で作成した Key Vault 名は、後述の「2. project_name の設定」で `infra/envs/terraform.tfvars` の `shared_key_vault_name` に設定します。

```hcl
shared_key_vault_name = "kv-<組織名>-gh-actions"
```

## Terraform によるインフラ構築

stg / prod の各環境ディレクトリで `terraform plan` / `terraform apply` を実行すると、以下のリソースが **環境ごとに独立して** 作成されます。

| リソース | stg | prod |
|----------|-----|------|
| Resource Group | `rg-<project>-stg` | `rg-<project>-prod` |
| Function App | `func-<project>-stg` | `func-<project>-prod` |
| Bot Service | `bot-<project>-stg` | `bot-<project>-prod` |
| Key Vault | `kv-<project>-stg` | `kv-<project>-prod` |
| App Registration | `app-<project>-stg-bot` | `app-<project>-prod-bot` |

ボットの認証情報（`MicrosoftAppId` / `MicrosoftAppPassword`）はメッセージングエンドポイントと1対1で紐づくため、環境・プロジェクトごとに別々の認証情報が必要です。
`terraform apply` がこれらの生成から Key Vault への保存まで自動で行います。

### 料金目安

| リソース | プラン | 料金 |
|----------|--------|------|
| Function App | Flex Consumption (FC1) | 月25万回実行 + 100,000 GB-s まで無料 |
| Bot Service | F0 | 無料 |
| Storage Account | Standard LRS | 数円〜数十円/月 |
| Key Vault | Standard | 1万操作あたり約4円（ほぼ発生しない） |
| Application Insights | — | 5GB/月まで無料 |
| Log Analytics | — | 5GB/月まで無料 |
| Azure AD App Registration | — | 無料 |

社内ボット程度の利用量であれば、月額はほぼ0円（Storage の数円程度）です。

### 1. Azure にログイン

```bash
az login
```

### 2. project_name の設定

```bash
cp infra/envs/terraform.tfvars.example infra/envs/terraform.tfvars
```

`infra/envs/terraform.tfvars` を開き、以下を設定してください（stg / prod 共通で使用されます）。

- `project_name`: **必ずプロジェクト固有の値に書き換える**
- `subscription_id`: デプロイ先の Azure サブスクリプション ID
- `shared_key_vault_name`: [事前準備](#事前準備-組織共通のセットアップ組織で1回のみ)で作成した組織共通 Key Vault 名

> ⚠️ **注意**: デフォルト値の `myteamsbot` のまま `terraform apply` するとリソース名に固定され、後からの変更は容易ではありません（Key Vault は削除後 soft-delete 期間中は同名再作成不可、Storage Account 名はグローバルに一意、など）。最初に必ず変更してください。

`project_name` の制約:
- 小文字英数字とハイフンのみ、3〜20 文字
- Azure リソース名のプレフィックス（`rg-<project_name>-<env>` 等）に使用される
- 例: `banking-info-bot`, `payroll-bot`

### 3. stg 環境のインフラ構築

まずは stg 環境のみを構築します。prod はここでは作成しません（stg で動作確認が完了してから後述の手順で展開します）。

```bash
cd infra/envs/stg
terraform init
terraform plan
terraform apply
```

`terraform apply` により、Azure リソースの作成と同時にボット認証情報（`MicrosoftAppId` / `MicrosoftAppPassword`）が Key Vault に自動保存されます。

> **Note:** `terraform destroy` を実行すると Function App ごと削除されます。再度 `terraform apply` した後は GitHub Actions からコードを再デプロイしてください。

## GitHub Actions のデプロイ設定（stg）

`terraform apply` が完了した後に、リポジトリのルートで実行してください。`az login` と `gh auth login` が完了していること。

```bash
cd ../../..    # infra/envs/stg からリポジトリのルートへ戻る
make setup-secrets
# プロンプトで「stg」を選択
```

Key Vault から認証情報を自動取得して以下を GitHub に登録します（Variables は GitHub Environment `stg` に紐づきます）。

| 種別 | 名前 | 内容 |
|------|------|------|
| Secret | `AZURE_CREDENTIALS` | サービスプリンシパルの認証情報（リポジトリ共通） |
| Variable | `AZURE_FUNCTION_APP_NAME` | Function App 名（例: `func-sample-bot-stg`） |
| Variable | `AZURE_RESOURCE_GROUP` | リソースグループ名（例: `rg-sample-bot-stg`） |
| Variable | `MICROSOFT_APP_ID` | Bot 認証用 App ID（Teams アプリパッケージのビルドで使用） |

## stg での動作確認

ここまで完了したら、ルートの [README.md](../README.md) の「デプロイ」に従って stg 環境へコードをデプロイし、Teams から実際にボットが応答することを確認してください。

- GitHub Actions からデプロイ先に `stg` を選択して実行
- Teams アプリパッケージ（`teams-app-stg-*`）を Teams 管理センターにアップロード
- Teams 上でボットにメッセージを送り、想定どおり応答することを確認

## prod 環境への展開

> ⚠️ **stg で動作確認がすべて完了してから実施してください。** stg で問題が見つかった場合は prod を触る前に stg 側で修正・再デプロイ・再確認を行います。

prod 環境は stg と同じ手順を繰り返します。

### 1. prod 環境のインフラ構築

```bash
cd infra/envs/prod
terraform init
terraform plan
terraform apply
```

stg と prod で state が分離されているため、互いに影響しません。

### 2. GitHub Actions のデプロイ設定（prod）

```bash
cd ../../..    # infra/envs/prod からリポジトリのルートへ戻る
make setup-secrets
# プロンプトで「prod」を選択
```

GitHub Environment `prod` に Variables が登録されます。

### 3. prod へのデプロイと動作確認

ルートの [README.md](../README.md) の「デプロイ」に従って、デプロイ先に `prod` を選択して実行し、Teams アプリパッケージ（`teams-app-prod-*`）を Teams 管理センターにアップロードして動作確認してください。

## 参考

通常のデプロイフロー（GitHub Actions → Azure Functions → Teams）では不要ですが、手元で確認したい／特殊なデバッグをしたい場合に使うコマンドをまとめています。

### Terraform 出力値の確認

デプロイ先の URL や ID を手元で確認したいとき、該当 env ディレクトリで `terraform output` を叩きます（`make setup-secrets` は Terraform state から自動で値を読むので、デプロイフロー上は実行不要）。

```bash
cd infra/envs/stg   # または infra/envs/prod
terraform output bot_messaging_endpoint
terraform output microsoft_app_id
terraform output key_vault_name

# sensitive な値（例: App Password）は -raw で取得
terraform output -raw microsoft_app_password
```

### ローカル実行時の Bot Framework 認証情報の取得

ローカルで `pnpm start` を起動し、ngrok 等で Azure Bot Service から自分のマシンへトンネル経由でメッセージを受け取って動作確認したい場合のみ実行します。Agents Playground で済ませる場合や、GitHub Actions 経由のデプロイ運用だけなら不要です。

Key Vault から取得した値で `local.settings.json` の `MicrosoftAppId` / `MicrosoftAppPassword` / `MicrosoftAppTenantId` / `MicrosoftAppType` を更新します（既存の他のキーは保持）。

```bash
make generate-local-settings
```
