# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
make generate  # Generate Xcode project from project.yml (requires xcodegen)
make open      # Generate and open in Xcode
make build     # Build release binary
make test      # Run unit tests
make clean     # Clean all build artifacts
make archive   # Create .xcarchive for release
make dmg       # Create DMG installer (requires archive first)
```

**Requirements:** macOS 14.0+, Xcode 15.0+, XcodeGen (`brew install xcodegen`)

## Architecture

PixLit is a macOS menu bar clipboard utility using **MVVM** with SwiftUI. Core flow: Global hotkey → native macOS screen selection → Vision OCR → text to clipboard.

- **Views/** - Stateless SwiftUI presentation components
- **ViewModels/** - @MainActor state management with @Published properties
- **Services/** - Actor-based business logic (thread-safe)

### Key Patterns

**Actor-based concurrency:** `OCRService` and `ScreenCaptureService` are actors ensuring thread-safe operations without manual locking.

**Global hotkey:** `HotkeyService` uses Carbon `RegisterEventHotKey` for Cmd+Shift+2 shortcut.

**Screen capture pipeline:** `screencapture -ic` → clipboard image → Vision OCR → text to clipboard.

**Menu bar integration:** `AppDelegate` manages NSStatusItem + NSPopover lifecycle. Uses `.accessory` activation policy (no Dock icon), switches to `.regular` only when Settings window is shown.

### Key Files

- `AppDelegate.swift` - Menu bar setup, popover management, hotkey registration
- `MainViewModel.swift` - Central state management for capture workflow
- `OCRService.swift` - Vision framework text recognition
- `ScreenCaptureService.swift` - Screen capture + OCR pipeline
- `HotkeyService.swift` - Carbon global hotkey wrapper
- `LaunchAtLoginManager.swift` - ServiceManagement integration for auto-launch

## Configuration

- **Info.plist:** `LSUIElement=true` hides app from Dock
- **Entitlements:** Hardened Runtime enabled, network client access (no sandbox)
- **project.yml:** XcodeGen configuration (bundle ID: `com.pixlit.app`)

## Git Hooks

Husky enforces conventional commits:

- `feat:`, `fix:`, `docs:`, `style:`, `refactor:`, `test:`, `chore:`
- Example: `feat(settings): add auto-launch toggle`

Prettier runs on staged `*.{js,json,md}` files via lint-staged.
