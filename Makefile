# VoiceInk's local, offline developer commands. Run from this repository's root.
.DEFAULT_GOAL := help
SHELL := /bin/sh
ROOT := $(CURDIR)
DERIVED_DATA := $(ROOT)/.local-build
APP := $(DERIVED_DATA)/Build/Products/Release/VoiceInk.app
INSTALL_DIR ?= /Applications
PYTHON ?= python3
COLOR ?= auto
export COLOR

.PHONY: help doctor check healthcheck build local all rebuild run dev open status logs test test-tools test-snippets test-speech test-language privacy-check clean install open-installed kill-installed reset-permissions

##@ Help & diagnostics
help: ## Show this help (also the default for plain make)
	@awk -f "$(ROOT)/scripts/help.awk" "$(ROOT)/Makefile"

doctor: ## Comprehensive local readiness check; never downloads or changes permissions
	@"$(PYTHON)" -u "$(ROOT)/scripts/dev.py" doctor

check: ## Fast check of macOS, Xcode, compiler, SDK, and build tools
	@"$(PYTHON)" -u "$(ROOT)/scripts/dev.py" check

healthcheck: check ## Alias for check

##@ Build
build: check ## Build the signed Release app without resolving packages
	@xcodebuild -project "$(ROOT)/VoiceInk.xcodeproj" -scheme VoiceInk -configuration Release \
		-derivedDataPath "$(DERIVED_DATA)" -disableAutomaticPackageResolution \
		CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= build
	@"$(PYTHON)" -u "$(ROOT)/scripts/dev.py" built

local: build ## Alias for build
all: build ## Explicitly build everything (plain make shows help)

rebuild: ## Clean, then build; refuses to clean a running app
	@$(MAKE) --no-print-directory clean
	@$(MAKE) --no-print-directory build

##@ Install & permissions
install: build ## Build and install to /Applications (override with INSTALL_DIR=...)
	@"$(PYTHON)" -u "$(ROOT)/scripts/dev.py" install --install-dir "$(INSTALL_DIR)"

open-installed: ## Open the installed app from /Applications (or INSTALL_DIR)
	@"$(PYTHON)" -u "$(ROOT)/scripts/dev.py" open-installed --install-dir "$(INSTALL_DIR)"

kill-installed: ## Stop the installed app; force after 5s (active recording may be lost)
	@"$(PYTHON)" -u "$(ROOT)/scripts/dev.py" kill-installed --install-dir "$(INSTALL_DIR)"

reset-permissions: ## Reset macOS privacy permissions for VoiceInk only; keep settings/history
	@"$(PYTHON)" -u "$(ROOT)/scripts/dev.py" reset-permissions

##@ Run & inspect
run: build ## Build and open VoiceInk; an already running instance stays running
	@"$(PYTHON)" -u "$(ROOT)/scripts/dev.py" open

dev: run ## Alias for run

open: ## Open the existing build without rebuilding
	@"$(PYTHON)" -u "$(ROOT)/scripts/dev.py" open

status: ## Show the app path, running instances, and any open IP sockets
	@"$(PYTHON)" -u "$(ROOT)/scripts/dev.py" status

logs: ## Show the last five minutes of VoiceInk logs
	@/usr/bin/log show --last 5m --style compact --predicate 'process == "VoiceInk"'

##@ Verify offline behavior
privacy-check: ## Check publishable files for private paths, common secrets, and artifacts
	@"$(PYTHON)" "$(ROOT)/scripts/check-public-repo.py"

test: test-tools test-snippets ## Run command tests plus offline, dependency, and signed binary checks
	@"$(PYTHON)" -u "$(ROOT)/scripts/check-offline.py"

test-tools: ## Test command defaults, color modes, diagnostics, and safe cleanup
	@"$(PYTHON)" "$(ROOT)/Tests/Offline/DeveloperCommandsTests.py"
	@"$(PYTHON)" "$(ROOT)/Tests/Offline/PublicRepoTests.py"

test-snippets: ## Test offline prompt expansion and saved snippet behavior
	@"$(PYTHON)" "$(ROOT)/scripts/test-prompt-snippets.py"

test-speech: check ## Test native transcription using installed English assets and a local voice
	@"$(PYTHON)" -u "$(ROOT)/scripts/dev.py" test-speech

test-language: check ## Have macOS download one language with the network guard on: LANGUAGE=de-DE
	@"$(PYTHON)" -u "$(ROOT)/scripts/dev.py" test-language --language "$(LANGUAGE)"

##@ Housekeeping
clean: ## Remove only .local-build; keep source, app settings, and transcription history
	@"$(PYTHON)" -u "$(ROOT)/scripts/dev.py" clean
