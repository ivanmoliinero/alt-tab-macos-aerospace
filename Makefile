.DEFAULT_GOAL := build

# Build Debug version locally
.PHONY: build
build:
	@./scripts/build_local.sh --debug

# Build Release version locally
.PHONY: release
release:
	@./scripts/build_local.sh --release

# Install Debug build into /Applications
.PHONY: install
install:
	@./scripts/install_local.sh --debug

# Install Release build into /Applications
.PHONY: install-release
install-release:
	@./scripts/install_local.sh --release

# Run unit tests
.PHONY: test
test:
	@./ai/test.sh

# Run locally built application with debug logs streaming
.PHONY: run
run:
	@./ai/run.sh

# Clean DerivedData build cache
.PHONY: clean
clean:
	@rm -rf DerivedData
	@echo "DerivedData directory removed."

# Display available commands
.PHONY: help
help:
	@echo "Available make targets:"
	@echo "  make build           - Build Debug configuration locally (default)"
	@echo "  make release         - Build Release configuration locally"
	@echo "  make install         - Build & install Debug version to /Applications"
	@echo "  make install-release - Build & install Release version to /Applications"
	@echo "  make test            - Run unit tests (via ai/test.sh)"
	@echo "  make run             - Run app with debug output streaming (via ai/run.sh)"
	@echo "  make clean           - Remove DerivedData cache"
