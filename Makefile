# Makefile for Foreign Affairs Premium Reader macOS App

APP_NAME = ForeignAffairsReader
APP_BUNDLE = $(APP_NAME).app
MACOS_DIR = $(APP_BUNDLE)/Contents/MacOS
RESOURCES_DIR = $(APP_BUNDLE)/Contents/Resources
EXECUTABLE = $(MACOS_DIR)/$(APP_NAME)

SOURCES = $(shell find Sources -type f)

.PHONY: all build run clean icon

all: build

build: $(EXECUTABLE)

$(EXECUTABLE): Package.swift $(SOURCES) AppIcon.icns
	@echo "Building $(APP_NAME) using Swift Package Manager..."
	@swift build -c release
	@mkdir -p $(MACOS_DIR)
	@cp -f .build/release/$(APP_NAME) $(MACOS_DIR)/
	@cp -f Sources/Info.plist $(APP_BUNDLE)/Contents/Info.plist 2>/dev/null || true
	@mkdir -p $(RESOURCES_DIR)
	@cp -f AppIcon.icns $(RESOURCES_DIR)/ 2>/dev/null || true
	@echo "Successfully compiled and bundled $(APP_BUNDLE)!"

run: build
	@echo "Launching $(APP_NAME)..."
	open $(APP_BUNDLE)

clean:
	@echo "Cleaning up build files..."
	@swift package clean 2>/dev/null || true
	rm -rf .build
	rm -rf $(APP_BUNDLE)
	rm -rf AppIcon.iconset
	rm -f AppIcon.icns

# Creates a professional AppIcon.icns from a source high-res icon.png
AppIcon.icns: icon.png
	@echo "Creating macOS AppIcon.icns from icon.png..."
	@mkdir -p AppIcon.iconset
	@sips -z 16 16 icon.png --out AppIcon.iconset/icon_16x16.png >/dev/null
	@sips -z 32 32 icon.png --out AppIcon.iconset/icon_16x16@2x.png >/dev/null
	@sips -z 32 32 icon.png --out AppIcon.iconset/icon_32x32.png >/dev/null
	@sips -z 64 64 icon.png --out AppIcon.iconset/icon_32x32@2x.png >/dev/null
	@sips -z 128 128 icon.png --out AppIcon.iconset/icon_128x128.png >/dev/null
	@sips -z 256 256 icon.png --out AppIcon.iconset/icon_128x128@2x.png >/dev/null
	@sips -z 256 256 icon.png --out AppIcon.iconset/icon_256x256.png >/dev/null
	@sips -z 512 512 icon.png --out AppIcon.iconset/icon_256x256@2x.png >/dev/null
	@sips -z 512 512 icon.png --out AppIcon.iconset/icon_512x512.png >/dev/null
	@sips -z 1024 1024 icon.png --out AppIcon.iconset/icon_512x512@2x.png >/dev/null
	@iconutil -c icns AppIcon.iconset
	@rm -rf AppIcon.iconset

icon: AppIcon.icns
	@mkdir -p $(RESOURCES_DIR)
	@cp -f AppIcon.icns $(RESOURCES_DIR)/
	@echo "Done! Placed AppIcon.icns inside $(RESOURCES_DIR)/"

