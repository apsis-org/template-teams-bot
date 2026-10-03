.PHONY: setup-manifest build-package setup-secrets generate-local-settings

## Teams アプリのボット名等を設定（初回のみ）
setup-manifest:
	./scripts/setup-manifest.sh

## Teams アプリパッケージ（ZIP）を生成
build-package:
	./scripts/build-package.sh

## GitHub Actions の Secrets / Variables を登録
setup-secrets:
	./scripts/setup-github-secrets.sh

## Key Vault からローカル設定ファイルを生成
generate-local-settings:
	./scripts/generate-local-settings.sh
