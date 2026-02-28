# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**mLink** is a native macOS Markdown editor with a split-pane editing experience (left editor, right live preview). It supports multiple tabs, recent files, favorites, and synchronized scrolling between editor and preview.

- **Language**: Swift 6.2
- **Platform**: macOS 13.0+
- **Build System**: Swift Package Manager
- **UI Framework**: AppKit (programmatic UI, no Storyboards)

## Common Commands

### Build and Run

```bash
# Build (Debug)
swift build

# Run the app
swift run

# Build (Release)
swift build -c release
```

### Testing

```bash
# Run all tests
swift test

# Run a specific test
swift test --filter DocumentStoreTests
swift test --filter MarkdownRendererTests
```

### Packaging

```bash
# Create macOS app bundle (outputs to dist/mLink.app)
./scripts/package_app.sh

# Open the packaged app
open dist/mLink.app
```

## Architecture

### Entry Point

The app uses a programmatic entry point (`Sources/mlink/App/Main.swift`) instead of `@NSApplicationMain`:
- Sets up `NSApplication`, `AppDelegate`, and calls `app.run()`

### Core Components

**MainWindowController** (`Sources/mlink/App/MainWindowController.swift`)
- Central controller managing the entire window lifecycle
- Contains: tab bar, editor scroll view, preview web view, split view
- Manages multiple `EditorTab` instances (internal class)
- Handles file operations through `DocumentStore`
- Coordinates scrolling sync between editor and preview via JavaScript injection

**AppDelegate** (`Sources/mlink/App/AppDelegate.swift`)
- Creates `MainWindowController` on launch
- Sets up main menu (File, Edit) with keyboard shortcuts
- Menu actions delegate to `MainWindowController`

### Editor System

**EditorViewController** (`Sources/mlink/Editor/EditorViewController.swift`)
- Manages the text editor with line numbers
- Uses `NSTextView` with custom `LineNumberRulerView` as vertical ruler

**EditorHighlighter** (`Sources/mlink/Editor/EditorHighlighter.swift`)
- Applies Markdown syntax highlighting via `NSAttributedString` attributes
- Called on text changes with debouncing

**LineNumberRulerView** (`Sources/mlink/Editor/LineNumberRulerView.swift`)
- Custom ruler view for line numbers alongside the editor

### Preview System

**PreviewViewController** (`Sources/mlink/Preview/PreviewViewController.swift`)
- Wraps a `WKWebView` for Markdown preview

**MarkdownRenderer** (`Sources/mlink/Preview/MarkdownRenderer.swift`)
- Converts Markdown to HTML (uses native Markdown parsing)
- Wraps output in styled HTML template

### Persistence Layer

**DocumentStore** (`Sources/mlink/Persistence/DocumentStore.swift`)
- Simple file I/O for reading/writing UTF-8 documents
- Used by `MainWindowController` for open/save operations

**QuickAccessStore** (`Sources/mlink/Persistence/QuickAccessStore.swift`)
- Manages recent files and favorites via `UserDefaults`
- Keys: `mlink.quick_access.recent_paths`, `mlink.quick_access.favorite_paths`
- Max 20 recent items, stores standardized file paths

**SplitLayoutStore** (`Sources/mlink/Persistence/SplitLayoutStore.swift`)
- Persists editor/preview split ratio via `UserDefaults`
- Key: `mlink.split.ratio`

### Styling

**Theme** (`Sources/mlink/Utilities/Theme.swift`)
- Centralized colors and fonts for the editor
- Uses `NSColor` and `NSFont` constants

## Key Patterns

### Tab Management
- `EditorTab` is an internal class in `MainWindowController` holding: `id` (UUID), `text`, `url`, `isDirty`
- Tabs are displayed as buttons in a horizontal scroll view
- Clicking a tab title switches to that tab; clicking "x" closes it
- Dirty state shows as a dot (•) in the tab title

### Scroll Synchronization
- Editor scroll events trigger JavaScript `window.scrollTo()` in the preview WebView
- Scroll ratio is calculated from editor's scroll position relative to document height

### Debounced Updates
- Text changes are debounced (0.1s) before applying syntax highlighting and updating preview
- Uses `DispatchWorkItem` stored in `debounceWorkItem` property

### UserDefaults Keys
- `mlink.quick_access.recent_paths`: Array of recent file paths
- `mlink.quick_access.favorite_paths`: Array of favorite file paths
- `mlink.split.ratio`: Double for split view divider position (0.0-1.0)

## Testing

Tests are in `Tests/mlinkTests/` using XCTest:
- Tests use `@testable import mlink` to access internal members
- Temporary files are created in `NSTemporaryDirectory()` with cleanup in `defer`

## File Structure

```
Sources/mlink/
  App/
    Main.swift                 # Entry point
    AppDelegate.swift          # App lifecycle, menu setup
    MainWindowController.swift # Main window, tabs, editor, preview
  Editor/
    EditorViewController.swift # Text editor management
    EditorHighlighter.swift    # Markdown syntax highlighting
    LineNumberRulerView.swift  # Line number gutter
    EditorTextView.swift       # Custom text view
  Preview/
    PreviewViewController.swift # WebView wrapper
    MarkdownRenderer.swift      # Markdown to HTML conversion
  Persistence/
    DocumentStore.swift        # File I/O
    QuickAccessStore.swift     # Recent/favorites storage
    SplitLayoutStore.swift     # Split ratio persistence
  Utilities/
    Theme.swift                # Colors and fonts
```
