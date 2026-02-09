# Changelog

All notable changes to **Neon Vision Editor** are documented in this file.

The format follows *Keep a Changelog*. Versions use semantic versioning with prerelease tags.

## [v0.4.4-beta] - 2026-02-09

### Added
- Inline code completion ghost text with Tab-to-accept behavior.
- Starter templates for all languages and a toolbar insert button.
- Welcome tour release highlights and a full toolbar/shortcut guide.
- Language detection tests and a standalone test target.

### Improved
- Language detection coverage and heuristics, including C and C# recognition.

### Fixed
- Language picker behavior to lock the selected language and prevent unwanted resets.

## [v0.4.3-beta] - 2026-02-08

### Added
- Syntax highlighting for **COBOL**, **Dotenv**, **Proto**, **GraphQL**, **reStructuredText**, and **Nginx**.
- Language picker/menu entries for the new languages.
- Sample fixtures for manual verification of detection and highlighting.
- macOS document-type registration for supported file extensions.

### Improved
- Extension and dotfile language detection for `.cob`, `.cbl`, `.cobol`, `.env*`, `.proto`, `.graphql`, `.gql`, `.rst`, and `.conf`.
- Opening files from Finder/Open With now reuses the active window when available.

## [v0.4.2-beta] - 2026-02-08

### Added
- Syntax highlighting profiles for **Vim** (`.vim`), **Log** (`.log`), and **Jupyter Notebook JSON** (`.ipynb`).
- Language picker/menu entries for `vim`, `log`, and `ipynb` across toolbar and app command menus.

### Improved
- Extension and dotfile language detection for `.vim`, `.log`, `.ipynb`, and `.vimrc`.
- Header-file default mapping by treating `.h` as `cpp` for more practical C/C++ highlighting.

### Fixed
- Scoped toolbar and menu commands to the active window to avoid cross-window side effects.
- Routed command actions to the focused window's `EditorViewModel` in multi-window workflows.
- Unified state persistence for Brain Dump mode and translucent window background toggles.
- Removed duplicate `Cmd+F` shortcut binding conflict between toolbar and command menu.
- Stabilized command/event handling across macOS and iOS builds.

## [v0.4.1-beta] - 2026-02-07

### Improved
- Prepared App Store security and distribution readiness for the `v0.4.1-beta` release.
- Added release/distribution documentation and checklist updates for submission flow.

## [v0.4.0-beta] - 2026-02-07

### Improved
- Improved editor UX across macOS, iOS, and iPadOS layouts.
- Refined cross-platform editor behavior and UI polish for the first beta line.

## [v0.3.3-alpha] - 2026-02-06

### Documentation
- Updated README content and presentation.

## [v0.3.2-alpha] - 2026-02-06

### Changed
- Refactored the editor architecture by splitting `ContentView` into focused files/extensions.

### Added
- Right-side project structure sidebar with recursive folder tree browsing.
- Dedicated blank-window flow with isolated editor state.
- Enhanced find/replace controls (regex, case-sensitive, replace-all status).

### Fixed
- Markdown highlighting over-coloring edge cases.
- Window/sidebar translucency consistency and post-refactor access-control issues.

## [v0.3.1-alpha] - 2026-02-06

### Fixed
- Line number ruler scrolling and update behavior.
- Translucency rendering conflicts in line-number drawing.

## [v0.3.0-alpha] - 2026-02-06

### Changed
- Established the `v0.3.x` alpha release line.
- Consolidated docs/release presentation updates and baseline packaging cleanup for the next iteration.

## [v0.2.9-alpha] - 2026-02-05

### Improved
- Improved Apple Foundation Models integration and streaming reliability.
- Added stronger availability checks and fallback behavior for model completion.

### Fixed
- Fixed streaming delta handling and optional-unwrapping issues in Apple FM output flow.

## [v0.2.8-1-alpha] - 2026-02-05

### Notes
- Re-tag of the Apple Foundation Models integration/stability update line.
- No functional differences documented from `v0.2.9-alpha` content.

## [v0.2.8-alpha] - 2026-02-05

### Improved
- Improved Apple Foundation Models integration and health-check behavior.
- Added synchronous and streaming completion APIs with graceful fallback.

### Fixed
- Fixed stream content delta computation and robustness in partial-response handling.

## [v0.2.7-alpha] - 2026-02-04

### Added
- Added Grok and Gemini provider support for inline code completion.

### Fixed
- Fixed exhaustive switch coverage in AI client factory/provider routing.

## [v0.2.6-alpha] - 2026-01-31

### Changed
- Packaged and uploaded the next alpha iteration for distribution.

## [v0.2.5-alpha] - 2026-01-25

### Improved
- Delayed hover popovers to reduce accidental toolbar popups.
- Improved auto language detection after drag-and-drop editor input.

## [v0.2.4-alpha] - 2026-01-25

### Changed
- Integrated upstream/mainline changes as part of alpha iteration merge.

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
