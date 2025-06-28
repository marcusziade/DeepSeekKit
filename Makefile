.PHONY: build test clean release docker-build docker-test docs cli-install

# Default target
all: build

# Build the project
build:
	swift build

# Build for release
release:
	swift build -c release

# Run tests
test:
	swift test --enable-code-coverage

# Clean build artifacts
clean:
	swift package clean
	rm -rf .build

# Generate documentation
docs:
	swift package --allow-writing-to-directory ./docs \
		generate-documentation --target DeepSeekKit \
		--disable-indexing \
		--output-path ./docs

# Install CLI tool
cli-install: release
	cp .build/release/deepseek-cli /usr/local/bin/
	@echo "✅ CLI installed to /usr/local/bin/deepseek-cli"

# Docker build
docker-build:
	docker build -t deepseek-kit .

# Docker test
docker-test:
	docker-compose run --rm test

# Docker CLI
docker-cli:
	docker-compose run --rm cli

# Format code
format:
	swift-format -i -r Sources Tests

# Lint code
lint:
	swiftlint lint --strict

# Run example
example:
	DEEPSEEK_API_KEY=$${DEEPSEEK_API_KEY} swift run deepseek-cli chat "Hello"