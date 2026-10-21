# Makefile — the project's command contract (AGENTS.md B4).
# Agents and CI call these targets, never the raw commands.

SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

VERSION ?= 0.0.0-dev
SHELL_SOURCES := $(wildcard scripts/*.sh) scripts/pkg/postinstall $(wildcard .claude/hooks/*.sh)

.PHONY: help
help: ## Show the available targets
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) \
	    | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: install
install: ## Install the build prerequisites (Homebrew: libusb, pkg-config)
	@brew list libusb pkg-config >/dev/null 2>&1 || brew install libusb pkg-config

.PHONY: build
build: ## Build in release mode
	swift build -c release

.PHONY: test
test: ## Run the test suite (Swift Testing, no hardware needed)
	swift test

.PHONY: lint
lint: ## Validate scripts, plist, JSON, SVG (shellcheck if installed)
	@for f in $(SHELL_SOURCES); do bash -n "$$f" || exit 1; done && echo "bash -n: ok"
	@plutil -lint local.jog-bridge.plist
	@for f in $$(find Tests .claude -name '*.json') ; do python3 -m json.tool "$$f" >/dev/null || { echo "Invalid JSON: $$f"; exit 1; }; done && echo "json: ok"
	@for f in assets/branding/*.svg; do xmllint --noout "$$f" || exit 1; done && echo "svg: ok"
	@if command -v shellcheck >/dev/null 2>&1; then \
	    shellcheck -x -S warning $(SHELL_SOURCES) && echo "shellcheck: clean"; \
	else \
	    echo "shellcheck not installed — skipped"; \
	fi

.PHONY: typecheck
typecheck: ## Not applicable: the Swift compiler type-checks during the build
	@echo "typecheck: covered by 'make build'"

.PHONY: audit
audit: ## Check that libusb is statically linked (there is no Swift dependency audit)
	@test -x .build/release/jog-bridge || { echo "run 'make build' first"; exit 1; }
	@if otool -L .build/release/jog-bridge | grep -qi libusb; then \
	    echo "The binary depends dynamically on libusb (see ADR 0004)" >&2; exit 1; \
	fi
	@echo "libusb $$(pkg-config --modversion libusb-1.0) statically linked (LGPL 2.1, ADR 0004)"

.PHONY: check
check: lint typecheck test build audit ## Full quality gate
	@echo ""
	@echo "✅ quality gate green"

.PHONY: test-hooks
test-hooks: ## Prove the guardrails (.claude/hooks) actually fire
	@./scripts/test-hooks.sh

.PHONY: dev
dev: ## Run the daemon locally with traffic printed (console plugged in)
	swift run jog-bridge --dump

.PHONY: pkg
pkg: ## Build the .pkg (VERSION=x.y.z)
	./scripts/build-pkg.sh $(VERSION)

.PHONY: panel
panel: ## Run the status panel from the build folder (it inspects the installed agent)
	swift run jog-bridge-panel

.PHONY: icon
icon: ## Regenerate assets/branding/AppIcon.icns from the logo
	./scripts/make-icon.sh

.PHONY: clean
clean: ## Remove build artefacts
	rm -rf .build dist
