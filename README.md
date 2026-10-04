# Teams Bot Template

**English** | [日本語](README.ja.md)

A Microsoft Teams Bot template built with TypeScript, Azure Functions, and Terraform.

## Toolchain

| Tool                          | Role                                                |
| ----------------------------- | --------------------------------------------------- |
| [Vite+](https://viteplus.dev) | Unified toolchain for build, lint, format, and test |
| tsdown / Rolldown             | Bundler (via Vite+)                                 |
| Oxlint                        | Linter (via Vite+)                                  |
| Oxfmt                         | Formatter (via Vite+)                               |
| Vitest                        | Test runner (via Vite+)                             |
| Terraform                     | Azure infrastructure management                     |

## Architecture

```
Teams client
    ↓ message
Azure Bot Service (channel registration)
    ↓ Bot Framework protocol
Azure Functions (HTTP trigger)
    ↓
Bot logic (TypeScript)
```

### Code structure and request flow

A message from Teams is processed in the following order.

```
src/functions/messages.ts  ← receives the HTTP request (entry point)
    ↓
src/bot/adapter.ts         ← authentication / signature verification (CloudAdapter)
    ↓
src/bot/bot.ts             ← message handling (bot logic)
```

| File                        | Role                          | Edit?         |
| --------------------------- | ----------------------------- | ------------- |
| `src/bot/bot.ts`            | Message handling (bot logic)  | **Edit here** |
| `src/bot/adapter.ts`        | Authentication / verification | Leave as is   |
| `src/functions/messages.ts` | HTTP entry point              | Leave as is   |

Every message from Teams, regardless of its kind (text, member added, and so on), arrives at `POST /api/messages`. `TeamsActivityHandler` inspects `activity.type` and dispatches to handlers such as `onMessage` and `onMembersAdded`. Text commands are branched with if/else inside `onMessage` in `bot.ts`.

#### When commands grow

Writing commands directly in `bot.ts` is fine while there are only a few. Once they grow, split them into a `commands/` directory.

```
src/bot/
├── bot.ts              ← handler registration (dispatch only)
├── adapter.ts
└── commands/           ← one file per command
    ├── hello.ts
    └── help.ts
```

## Azure resources

| Resource                           | Description                                 |
| ---------------------------------- | ------------------------------------------- |
| Azure Functions (Flex Consumption) | Message endpoint for the bot                |
| Azure Bot Service                  | Teams channel registration / authentication |
| Azure AD App Registration          | App registration for bot authentication     |
| Application Insights               | Logging / monitoring                        |
| Log Analytics Workspace            | Backend for Application Insights            |
| Storage Account                    | Runtime storage for Functions               |
| Azure Key Vault                    | Stores the bot credentials                  |

## Prerequisites

- [Node.js 24](https://nodejs.org/)
- [pnpm 9+](https://pnpm.io/installation)
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- [tfenv](https://github.com/tfutils/tfenv) (Terraform version manager)
- [Azure Functions Core Tools v4](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local)
- [jq](https://jqlang.github.io/jq/)
- An Azure subscription

### Installation (macOS)

```bash
brew install azure-cli
brew install tfenv
tfenv install  # installs the version pinned in infra/.terraform-version
brew tap azure/functions
brew install azure/functions/azure-functions-core-tools@4
brew install jq
```

## Local development

### 1. Setup

```bash
pnpm install
cp local.settings.json.example local.settings.json
```

> **Note:** Azure Functions Core Tools (`func start`) reads `local.settings.json` on startup and injects the keys under `Values` as environment variables (`process.env.*`). This file, not `.env`, is the Azure Functions convention. For local testing the credentials can stay empty, but the runtime will not start without the file itself. Because real credentials are written to it in a later step, it is excluded from git via `.gitignore`, so you need to create it with `cp` the first time.

### 2. Implement the bot logic

Edit the `TeamsBot` class in `src/bot/bot.ts`.

```typescript
this.onMessage(async (context, next) => {
  const text = context.activity.text?.trim() ?? "";
  // add your logic here
  await next();
});
```

### 3. Build and run

```bash
pnpm start        # builds, then starts Azure Functions Core Tools
                  # endpoint: http://localhost:7071/api/messages
```

### 4. Testing with Agents Playground

[Agents Playground](https://learn.microsoft.com/en-us/microsoftteams/platform/toolkit/debug-your-agents-playground) is a local test tool that sends messages to your running bot and shows the replies. It needs no Microsoft 365 account, tunneling, or app registration.

```bash
# with the bot running via `pnpm start`, run this in another terminal
BOT_ENDPOINT=http://localhost:7071/api/messages npx @microsoft/teams-app-test-tool
```

A browser opens with a Teams-like chat UI. Send `hello` or `help` from the input box and confirm the bot replies. Any other message is echoed back.

> **Note:** The default endpoint is `http://localhost:3978/api/messages`, so the `BOT_ENDPOINT` environment variable points it at the Azure Functions port (7071).

### 5. Other commands

```bash
pnpm run build        # bundle (output to dist/)
pnpm run watch        # watch mode
pnpm run lint         # Oxlint
pnpm run fmt          # Oxfmt (format)
pnpm run typecheck    # tsc --noEmit
pnpm test             # Vitest (single run)
pnpm run test:watch   # Vitest (watch mode)
```

## Customizing the bot

### 1. Set the bot name (first time only)

```bash
make setup-manifest
```

### 2. Edit manifest.json

Edit `appPackage/manifest.json` to fit your use case (developer information, command list, and so on).

#### Automatic version bump of manifest.json

When a commit includes `manifest.json`, the git hook (`.githooks/commit-msg`) bumps its `version` (the Teams app version) automatically. The hook is enabled by the `prepare` script during `pnpm install`.

| Commit message                                                                        | Bumped part | Example       |
| ------------------------------------------------------------------------------------- | ----------- | ------------- |
| `feat!:` / `fix(scope)!:` or any `!`-suffixed type, or `BREAKING CHANGE:` in the body | Major       | 1.0.0 → 2.0.0 |
| `feat:` / `feat(scope):`                                                              | Minor       | 1.0.0 → 1.1.0 |
| Anything else                                                                         | Patch       | 1.0.0 → 1.0.1 |

- Commits that do not touch `manifest.json` are left alone
- If you changed `version` by hand in the commit, that value wins and no automatic bump happens

## Infrastructure setup (first time only)

Azure resources are created **once**, when you create a new project from this template.
See [infra/README.md](infra/README.md) for the procedure.

## Deployment

### Deploying the Function App (GitHub Actions)

Deploy manually from the GitHub Actions UI.

1. Open the **Actions** tab of the GitHub repository
2. Select the **Deploy to Azure Functions** workflow
3. Click **Run workflow**
4. Choose the target environment (`stg` / `prod`)
5. If you changed anything under `appPackage/` (`manifest.json` or the icons), tick **"Also update the Teams app"** before running

> **Prerequisite:** Deployment requires GitHub Actions to authenticate to Azure. Complete the infrastructure setup in [infra/README.md](infra/README.md) first.

### Adding runtime settings (environment variables)

If the bot needs per-environment values such as external API keys, push them to the Function App's App Settings as follows. `.env.example` is the single source of truth for the **list of keys**: only keys listed there are picked up.

1. Add the key to `.env.example` as `KEY=` (leave the value empty; this file is committed)
2. `cp .env.example .env.stg` (or `.env.prod`) and fill in the values (these files are gitignored)
3. Run `make setup-secrets`. The values are registered as Secrets in the GitHub Environment (`stg` / `prod`)
4. Run the Deploy workflow above. After deployment the Secrets are applied to the Function App's App Settings and become available as `process.env.KEY`

For local development, add the same keys under `Values` in `local.settings.json`.

### Registering / updating the Teams app (manual)

Registering the app in the Teams app catalog is a manual step (the Graph API does not support automated deployment from CI/CD).

#### Getting the ZIP package

When you run the deployment with **"Also update the Teams app"** ticked, the ZIP is stored under the Artifacts of the GitHub Actions run. Open the run's summary page and download the artifact whose name **starts with `teams-app-`** (for example `teams-app-stg-1`). `deploy-package` is used internally during deployment and does not need to be downloaded.

#### Icon requirements

A Teams app needs two PNG icons.

| Icon          | Size         | Used in              |
| ------------- | ------------ | -------------------- |
| `color.png`   | 192 x 192 px | Store, flyouts, etc. |
| `outline.png` | 32 x 32 px   | App bar, etc.        |

- Keep the logo inside the central 120 x 120 px safe area
- Submit a plain square; Teams adds rounded corners and borders automatically
- A contrast ratio of 4.5:1 or higher is recommended

See the [official Microsoft guidelines](https://learn.microsoft.com/en-us/microsoftteams/platform/concepts/design/design-teams-app-icon-store-appbar) for details.

#### Uploading from the Teams admin center

1. Open the [Teams admin center](https://admin.teams.microsoft.com/)
2. Go to **Teams apps** > **Manage apps**
3. First time: **Upload** > select the ZIP file
4. Updating: select the existing app and delete it, then **Upload** the new ZIP

After registration, the bot can be used as follows:

- **Channel**: install the bot in a team, then mention it, e.g. `@BotName hello`
- **Group chat**: add the bot to the group chat, then send a message

> **Note:** This bot does not support personal (1:1) chats.

The bot name is defined in `name.short` of `appPackage/manifest.json`. By default you mention it as `@Teams Bot [stg] hello` in the stg environment and `@Teams Bot hello` in prod. To change it, edit `name.short` in `manifest.json`.

### Troubleshooting

#### `ManifestFileNotFound: The provided stream does not contain a "manifest.json" file.`

`manifest.json` is missing from the ZIP or has a different name. Check:

- Unzip the package and confirm `manifest.json` exists at the root
- Confirm the file name was not changed during the build

#### `Schema validation failed at '<property>': Property "<property>" has not been defined and the schema does not allow additional properties.`

`manifest.json` contains a property that is not allowed by its schema version. Check the [schema definition](https://learn.microsoft.com/en-us/microsoftteams/platform/resources/schema/manifest-schema) referenced by `$schema` and remove the offending property.

#### `SyntaxError: Named export 'XXX' not found. The requested module 'botbuilder' is a CommonJS module`

`botbuilder` is a CommonJS module, so bundling as ESM makes named imports fail on the Azure Functions runtime. The build output must be CJS (`format: "cjs"`). Check that `pack.format` in `vite.config.ts` is not set to `"esm"`.

## Bot behavior

### Behavior in Teams

The bot only responds where it is installed. The supported scopes are teams (channels) and group chats.

| Location   | Condition                                                                 |
| ---------- | ------------------------------------------------------------------------- |
| Channel    | Requires a mention, e.g. `@BotName hello`                                 |
| Group chat | Responds to messages once added to the group                              |
| 1:1 chat   | Not supported (replies with guidance to use a team or group chat instead) |

The lack of personal-chat support is enforced twice: by `scopes` in `appPackage/manifest.json` (no `personal`) and by the `conversationType === "personal"` check in `src/bot/bot.ts`.

### Default commands

| Message                | Reply                                          |
| ---------------------- | ---------------------------------------------- |
| `hello` / `こんにちは` | "Hello, {sender name}!"                        |
| `help` / `ヘルプ`      | Help card listing the commands (Adaptive Card) |
| Anything else          | Echoes back: `Received message: "{your text}"` |

The English commands (`hello` / `help`) are case-insensitive. The Japanese aliases are kept as an example of localized commands; remove them if you do not need them.

## Versioning and releases

The template itself is versioned with [release-please](https://github.com/googleapis/release-please). See [Releases](https://github.com/apsis-org/template-teams-bot/releases) and `CHANGELOG.md` for changes.

- Versions are derived from [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) (`feat` → minor, `fix` → patch, `feat!` / `BREAKING CHANGE` → major)
- Repositories created from this template do not receive updates automatically. Check the CHANGELOG and pull in the changes you need
- The template version (tags, `package.json`) and the Teams app version (`version` in `appPackage/manifest.json`, [bumped by the git hook](#automatic-version-bump-of-manifestjson)) are independent

### In repositories created from this template

`.github/workflows/release.yml` is restricted to run only in the template itself (`apsis-org/template-teams-bot`). It will not run in your repository, so delete the following if you do not need them.

- `.github/workflows/release.yml`
- `release-please-config.json`
- `.release-please-manifest.json`
- `CHANGELOG.md`
- `SECURITY.md` / `.github/ISSUE_TEMPLATE/` (written for the template itself; rewrite for your project or delete)

## Contributing

- **Issues**: bug reports and feature requests are welcome. Please use the [issue templates](https://github.com/apsis-org/template-teams-bot/issues/new/choose)
- **Pull requests**: not accepted at the moment. Please open an issue for improvement proposals
- **Vulnerabilities**: do not open a public issue. Follow the private reporting procedure in [SECURITY.md](SECURITY.md)

## License

MIT
