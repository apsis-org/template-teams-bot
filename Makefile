.PHONY: setup-manifest build-package setup-secrets generate-local-settings

## Set the bot name etc. in the Teams app manifest (first time only)
setup-manifest:
	./scripts/setup-manifest.sh

## Build the Teams app package (ZIP)
build-package:
	./scripts/build-package.sh

## Register GitHub Actions Secrets / Variables
setup-secrets:
	./scripts/setup-github-secrets.sh

## Generate the local settings file from Key Vault
generate-local-settings:
	./scripts/generate-local-settings.sh
