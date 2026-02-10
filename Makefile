.PHONY: build test clean archive open dmg generate help

# Project settings
PROJECT_NAME = PixLit
SCHEME = $(PROJECT_NAME)
CONFIGURATION = Release
BUILD_DIR = build
ARCHIVE_PATH = $(BUILD_DIR)/$(PROJECT_NAME).xcarchive
EXPORT_PATH = $(BUILD_DIR)/export

# Optional: pass VERSION=x.y.z to inject version into the build
ifdef VERSION
VERSION_FLAGS = MARKETING_VERSION=$(VERSION) CURRENT_PROJECT_VERSION=$(VERSION)
endif

# Default target
help:
	@echo "Available targets:"
	@echo "  generate  - Generate Xcode project using xcodegen"
	@echo "  open      - Open project in Xcode"
	@echo "  build     - Build the project"
	@echo "  test      - Run tests"
	@echo "  clean     - Clean build artifacts"
	@echo "  archive   - Create release archive"
	@echo "  dmg       - Create DMG installer"
	@echo ""
	@echo "Options:"
	@echo "  VERSION=x.y.z  - Set version for archive/dmg targets"

# Generate Xcode project
generate:
	xcodegen generate

# Open in Xcode
open: generate
	open $(PROJECT_NAME).xcodeproj

# Build
build: generate
	xcodebuild -project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-derivedDataPath $(BUILD_DIR) \
		build

# Run tests
test: generate
	xcodebuild -project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR) \
		test

# Clean
clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(PROJECT_NAME).xcodeproj
	xcodebuild clean 2>/dev/null || true

# Archive for release
archive: generate
	xcodebuild -project $(PROJECT_NAME).xcodeproj \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION) \
		-archivePath $(ARCHIVE_PATH) \
		CODE_SIGN_IDENTITY="-" \
		$(VERSION_FLAGS) \
		archive

# Create DMG
dmg: archive
	VERSION=$(VERSION) npm run build:dmg
