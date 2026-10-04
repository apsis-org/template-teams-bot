# CLAUDE.md

Guidelines for Claude Code when working in this repository.

## Project overview

A Microsoft Teams Bot template repository built with TypeScript + Azure Functions v4 + Terraform.

## Commands

```bash
# Build (bundled by Vite+ / tsdown)
pnpm run build          # bundle into dist/
pnpm run watch          # watch mode

# Run locally
pnpm start              # build, then start Azure Functions Core Tools
                        # endpoint: http://localhost:7071/api/messages

# Code quality (Vite+)
pnpm run lint           # Oxlint
pnpm run fmt            # Oxfmt (format)
pnpm run typecheck      # tsc --noEmit
pnpm test               # Vitest (single run)
pnpm run test:watch     # Vitest (watch mode)

# Terraform (run inside an environment directory)
cd infra/envs/stg    # or infra/envs/prod
terraform init
terraform plan
terraform apply
```

## Architecture

```
Teams client → Azure Bot Service → Azure Functions → bot logic
```

### Key files

| File                          | Role                                       |
| ----------------------------- | ------------------------------------------ |
| `src/functions/messages.ts`   | Azure Functions HTTP trigger (entry point) |
| `src/bot/bot.ts`              | Bot logic extending `TeamsActivityHandler` |
| `src/bot/adapter.ts`          | `CloudAdapter` setup and error handling    |
| `infra/main.tf`               | Azure resource definitions (shared module) |
| `infra/envs/stg/`             | Terraform root for stg                     |
| `infra/envs/prod/`            | Terraform root for prod                    |
| `infra/modules/function_app/` | Function App / Storage / App Service Plan  |
| `infra/modules/bot_service/`  | Azure Bot Service + Teams channel          |
| `infra/modules/monitoring/`   | Application Insights + Log Analytics       |
| `appPackage/manifest.json`    | Teams app manifest                         |

## Development guidelines

### TypeScript

- Keep `strict: true`
- Never use `any`; use `unknown` when unavoidable
- Modules are ESM (`"type": "module"`, `"module": "ESNext"`, `"moduleResolution": "Bundler"`)
- No `.js` extension on relative imports; the bundler (tsdown) resolves them
- Use the `node:` prefix for Node.js built-ins (`import { Readable } from "node:stream"`)
- Build, lint, format, and test are all configured in `vite.config.ts` (Vite+)

### Adding bot logic

Add it to the `TeamsBot` class in `src/bot/bot.ts`. Follow the existing pattern of branching on commands inside the `onMessage` handler.

```typescript
this.onMessage(async (context, next) => {
  const text = context.activity.text?.trim() ?? "";
  // add logic here
  await next(); // always call this
});
```

#### Line breaks in message text

Teams renders bot text as **Markdown**, so write line breaks as one of:

- `\n\n` (paragraph break; use this by default)
- `  \n` (two trailing spaces + `\n` for a hard break without paragraph spacing)

A single `\n` is treated as whitespace in Markdown and does not break the line. Use `\n\n` as the default when building multi-line messages or bullet lists.

### Supported scopes

This bot supports **team / groupChat only** (no personal chat).

- Do not include `personal` in `bots[].scopes` / `commandLists[].scopes` of `appPackage/manifest.json`
- Keep the defensive check in `src/bot/bot.ts`: at the start of `onMessage` / `onMembersAdded`, test `context.activity.conversation.conversationType === "personal"`, reply with guidance, and return early

### Build configuration

- `pack.entry` in `vite.config.ts` uses the object form `{ index: "src/functions/messages.ts" }` to emit `dist/index.cjs`
- Keep `pack.format` as `"cjs"` (`botbuilder` is CommonJS; bundling as ESM breaks named imports on the Azure Functions runtime)
- Because the package is `"type": "module"` and the output is CJS, the extension is `.cjs`
- Keep `main` in `package.json` (`dist/index.cjs`) in sync with the build output
- TypeScript 7.0 does not provide the programmatic API, so enabling `pack.dts` (type declaration output) breaks the build. This project does not need declaration files; do not enable it (the API is expected back in TypeScript 7.1)

### Azure Functions

- Uses the Azure Functions v4 programming model (registered with `app.http()`)
- `authLevel: "anonymous"` is intentional; the Bot Framework verifies signatures itself
- `route` must be `"messages"` (Azure Functions prepends `/api` automatically; `"api/messages"` would become `/api/api/messages`)
- Keep the extensionBundle version in `host.json` at `[4.*, 5.0.0)`

### Terraform

- One directory per environment: `infra/envs/stg/`, `infra/envs/prod/` (fully separate state)
- `infra/` itself is the shared module; never run `terraform apply` there directly
- Modules: `function_app` / `bot_service` / `monitoring` / `key_vault`
- All resource names use `prefix` (`${project_name}-${environment}`)
- Mark sensitive values (passwords etc.) with `sensitive = true`
- The Function App uses the Flex Consumption (FC1) plan via the `azurerm_function_app_flex_consumption` resource
- The bot authentication type is `SingleTenant` (MultiTenant has been retired by Azure)
- `azurerm_bot_service_azure_bot.display_name` is derived from `name.short` in `appPackage/manifest.json` via `jsondecode`, replacing `__ENV_SUFFIX__` with the same rule as `build-teams-app.yml`. Never hardcode the bot display name (the manifest is the single source of truth)

### GitHub Actions

- Azure authentication uses a service principal (`AZURE_CREDENTIALS`), fetched automatically from Key Vault
- `deploy-functions.yml`: `workflow_dispatch` only. Deploys to the Function App and optionally builds the Teams app package
- `build-teams-app.yml`: builds the Teams app ZIP and stores it as an artifact. Uploading to the Teams admin center is manual
- `ci.yml`: runs lint / format check / typecheck / test / build on PRs and pushes to main
- `release.yml`: creates release PRs and releases via release-please. Guarded by `if: github.repository == 'apsis-org/template-teams-bot'` so it never runs outside the template itself (do not remove this condition)

### Versioning

- The template version is managed by release-please (`release-please-config.json` / `.release-please-manifest.json`)
- Do not edit `version` in `package.json` or `CHANGELOG.md` by hand; release-please updates them
- Commit messages follow Conventional Commits. Mark breaking changes with `feat!:` / `fix!:` or `BREAKING CHANGE:` in the body (a `BREAKING:` type is not recognized by release-please)
- `version` in `appPackage/manifest.json` is the Teams app version and is independent of the template version. When a commit includes `manifest.json`, `.githooks/commit-msg` bumps it based on the commit message (`!` suffix / `BREAKING CHANGE:` → major, `feat` → minor, otherwise → patch). The hook is wired up via `core.hooksPath` by the `prepare` script during `pnpm install`

## Environment variables

Local development uses `local.settings.json` (gitignored); production uses the Function App's App Settings.

| Variable               | Description                                                 |
| ---------------------- | ----------------------------------------------------------- |
| `MicrosoftAppId`       | App ID for bot authentication                               |
| `MicrosoftAppPassword` | Secret for bot authentication                               |
| `MicrosoftAppType`     | `SingleTenant` / `UserAssignedMSI` (MultiTenant is retired) |
| `MicrosoftAppTenantId` | Tenant ID when using SingleTenant                           |

To add bot-specific runtime settings (external API keys etc.), add `KEY=` to `.env.example`. Both `scripts/setup-github-secrets.sh` and the "Apply runtime settings" step in `deploy-functions.yml` read the key list from `.env.example`, so never hardcode key names in scripts or workflows.

## Notes

- Never commit `local.settings.json`
- `*.tfvars` files are gitignored as well; never commit them
- Placeholders in `appPackage/manifest.json` (`__BOT_ID__` etc.) are replaced automatically at deploy time
- `location` of the Terraform `azurerm_bot_service_azure_bot` is fixed to `"global"` (Azure requirement)

### Handling sensitive files (Claude Code permissions)

`.claude/settings.json` blocks reading `.env`-style files, `.tfvars` files, and `local.settings.json`. **Do not try to read them.**

- **allow**
  - `.env.example`
  - `**/*.tfvars.example`
  - `local.settings.json.example`
- **deny (Read)**
  - `.env` / `*.env` / `.env.local` / `.env.development(.*)` / `.env.production(.*)` / `.env.staging(.*)` / `.env.test(.*)` / `.env.*.local`
  - `**/*.tfvars` / `**/*.tfvars.json` / `**/*.auto.tfvars` / `**/*.auto.tfvars.json`
  - `local.settings.json`
- **deny (Bash)**: `cat` / `head` / `tail` / `less` / `more` / `grep` / `sed` / `awk` / `vim` / `nano` / `bat` on the files above

To check the contents of environment variables or Terraform variables, refer to `.env.example` / `*.tfvars.example` / `local.settings.json.example`, and ask the user for the real values.
