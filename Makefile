# Hikari Yaps — build & packaging
#
# This machine's Command Line Tools install is broken (a stale
# PackageDescription.private.swiftinterface and a duplicated SwiftBridging
# modulemap left over from an older CLT). The two exports below work around
# it without touching system files:
#   * SWIFTPM_CUSTOM_LIBS_DIR — corrected manifest libraries (stale private
#     interfaces removed)
#   * SWIFT_EXEC — a swiftc wrapper that appends a VFS overlay masking the
#     duplicate modulemap
# If you install full Xcode (or Apple fixes the CLT), delete TOOLCHAIN_FIX
# below and everything still works.

TOOLCHAIN_FIX := $(HOME)/.hikari-swiftpm-libs
export SWIFTPM_CUSTOM_LIBS_DIR := $(TOOLCHAIN_FIX)
export SWIFT_EXEC := $(TOOLCHAIN_FIX)/swiftc

APP_NAME := HikariYaps
BUNDLE   := dist/iVoz.app
CONTENTS := $(BUNDLE)/Contents
BINARY   := .build/release/$(APP_NAME)

.PHONY: all build app run install icon clean toolchain-fix

all: app

toolchain-fix:
	@test -x $(TOOLCHAIN_FIX)/swiftc || ./Packaging/setup-toolchain-fix.sh

build: toolchain-fix
	swift build -c release

app: build icon
	rm -rf $(BUNDLE)
	mkdir -p $(CONTENTS)/MacOS $(CONTENTS)/Resources $(CONTENTS)/Frameworks
	cp $(BINARY) $(CONTENTS)/MacOS/$(APP_NAME)
	cp Packaging/Info.plist $(CONTENTS)/Info.plist
	printf 'APPL????' > $(CONTENTS)/PkgInfo
	cp dist/AppIcon.icns $(CONTENTS)/Resources/AppIcon.icns
	@if [ -d .build/release/$(APP_NAME)_$(APP_NAME).bundle ]; then \
		cp -R .build/release/$(APP_NAME)_$(APP_NAME).bundle $(CONTENTS)/Resources/; \
	fi
	@# llama.framework backs local LLM (Smart Cleanup) inference — WhisperKit
	@# needs no such step since Core ML models are downloaded at runtime, not
	@# linked as a framework.
	ditto .build/release/llama.framework $(CONTENTS)/Frameworks/llama.framework
	install_name_tool -add_rpath @executable_path/../Frameworks $(CONTENTS)/MacOS/$(APP_NAME)
	codesign --force --deep --sign - $(BUNDLE)
	@echo "✓ Built $(BUNDLE)"

icon: dist/AppIcon.icns

dist/AppIcon.icns: Packaging/make-icon.swift
	mkdir -p dist
	rm -rf dist/AppIcon.iconset
	swift -vfsoverlay $(TOOLCHAIN_FIX)/mask.yaml Packaging/make-icon.swift dist/AppIcon.iconset
	iconutil -c icns dist/AppIcon.iconset -o dist/AppIcon.icns

run: app
	open $(BUNDLE)

install: app
	mkdir -p /Applications/iSuite
	rm -rf "/Applications/iSuite/iVoz.app"
	ditto $(BUNDLE) "/Applications/iSuite/iVoz.app"
	@echo "✓ Installed to /Applications/iSuite/iVoz.app"

clean:
	rm -rf .build dist
