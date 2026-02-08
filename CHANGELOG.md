# Changelog

All notable changes to **Neon Vision Editor** are documented in this file.

The format follows *Keep a Changelog*. Versions use semantic versioning with prerelease tags.

## [v0.4.2-beta] - 2026-02-08

### Fixed
- Scoped toolbar and menu commands to the active window to avoid cross-window side effects.
- Routed command actions to the focused window's `EditorViewModel` in multi-window workflows.
- Unified state persistence for Brain Dump mode and translucent window background toggles.
- Removed duplicate `Cmd+F` shortcut binding conflict between toolbar and command menu.
- Stabilized command/event handling across macOS and iOS builds.

### Notes
- No pull requests were associated with the commits included in this release tag.

## [v0.2.3-alpha] - 2026-01-23

### Improved
- Improved line numbering behavior for more consistent rendering.
- Added syntax highlighting support for **Bash** and **Zsh**.
- Added a function to open multiple files at once.

### Fixed
- Fixed line number rendering issues during scrolling and in larger files.

## [v0.2.2-alpha] - 2026-01-22

### Enhanced
- Added automatic language selection using the Apple FM model.
- Updated toolbar layout and implemented AI selector support.

## [v0.2.1-alpha] - 2026-01-21

### Improved
- Updated UI with sidebar/layout fixes.
- Fixed language selector behavior for syntax highlighting.
- Improved focus behavior for text view interactions.
