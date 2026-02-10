# PixLit

A macOS menu bar utility that extracts text from any screen region using OCR.

## Features

- **Screen Capture OCR** - Select any screen region and extract text instantly
- **Global Hotkey** - Press ⌘⇧2 to capture from anywhere
- **Menu Bar Only** - Runs as a status bar app (no Dock icon)
- **Clipboard Integration** - Extracted text is automatically copied
- **Native APIs** - Uses Vision framework for OCR, zero external dependencies

## Requirements

- macOS 14.0+
- Xcode 15.0+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Quick Start

```bash
# Generate Xcode project and open
make open

# Or step by step:
xcodegen generate
open PixLit.xcodeproj
```

Build and run with `Cmd+R` in Xcode.

## Project Structure

```
PixLit/
├── PixLitApp.swift               # @main entry point
├── AppDelegate.swift             # Menu bar, popover, hotkey setup
├── ContentView.swift             # Main popover UI
├── AppConfig.swift               # App configuration
├── Views/
│   └── SettingsView.swift        # Settings window
├── ViewModels/
│   └── MainViewModel.swift       # Capture state manager
├── Services/
│   ├── OCRService.swift          # Vision text recognition
│   ├── ScreenCaptureService.swift # Capture + OCR pipeline
│   ├── HotkeyService.swift       # Global hotkey (Cmd+Shift+2)
│   ├── LaunchAtLoginManager.swift
│   └── UpdateService.swift       # GitHub release checker
└── Assets.xcassets/
```

## Usage

1. Launch the app — a `text.viewfinder` icon appears in the menu bar
2. Press **⌘⇧2** (or click the icon and use the Capture button)
3. Select a screen region with the crosshair
4. Extracted text is copied to your clipboard

## Build Commands

```bash
make generate  # Generate Xcode project
make open      # Generate and open in Xcode
make build     # Build release
make test      # Run tests
make clean     # Clean build artifacts
make archive   # Create release archive
make dmg       # Create DMG installer
```

## License

MIT
