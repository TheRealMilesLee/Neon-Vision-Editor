<h1 align="center">Neon Vision Editor</h1>

<p align="center">
  <img src="NeonVisionEditorIcon.png" alt="Neon Vision Editor Logo" width="200"/>
</p>

<h4 align="center">
  A lightweight, modern macOS text editor focused on speed, readability, and fast automatic syntax highlighting. 
</h4>

<p align="center">
  It is intentionally minimal: quick edits, fast file access, no IDE bloat.
</p>

<p align="center">
Release Download: https://github.com/h3pdesign/Neon-Vision-Editor/releases
</p>

<p align="center">
.  .  .
</p>

> Status: **alpha / beta**  
> Platform target: **macOS 26 (Tahoe)**
> Built/tested with Xcode
> Apple Silicon: tested / Intel: not tested

## Download

Prebuilt binaries are available via **GitHub Releases**:

- Latest release: **v0.3.2-alpha**
- Architecture: Apple Silicon (Intel not tested)
- Notarization: *not yet*

If you don’t want to build from source, this is the recommended path:

- Download the `.zip` or `.dmg` from **Releases**
- Move the app to `/Applications`

#### Gatekeeper (macOS 26 Tahoe)

If macOS blocks the app on first launch:

1. Open **System Settings**
2. Go to **Privacy & Security**
3. Scroll down to the **Security** section
4. You will see a message that *Neon Vision Editor* was blocked
5. Click **Open Anyway**
6. Confirm the dialog

After this, the app will launch normally.
  
## Why this exists

Modern IDEs are powerful but heavy.  
Classic macOS editors are fast but stagnant.

Neon Vision Editor sits in between:
- Open files instantly
- Read code comfortably
- Edit without friction
- Close the app without guilt

No background indexing. No telemetry. No plugin sprawl.

<p align="left">
  <img src="NeonVisionEditorApp.png" alt="Neon Vision Editor App" width="1100"/>
</p>

## Features

- Fast loading, including large text files
- Automatic applied syntax highlighting for common languages  
  (Python, C/C++, JavaScript, HTML, CSS, and others)
- Clean, minimal UI optimized for readability
- Native macOS 26 (Tahoe) look & behavior
- Built with Swift and AppKit

## What’s new (feature-focused) in latest release

### Major editor UX expansion:

- Added regex-capable Find/Replace with Replace All and quick toolbar access.
- Added a right-side project structure panel with recursive folder tree browsing.
- Added a dedicated New Window flow that opens blank/isolated windows.
- Added richer window controls in the toolbar (including sidebar/window toggles).
- Improved translucency support in editor/window surfaces.
- Better sidebar and window-state handling across the app.
- Smarter language/editor behavior:
- Added/expanded local language detection heuristics.
- Improved syntax highlighting behavior (including markdown edge cases).
- Improved focus and editor interaction behavior in general.
- Internal quality improvements:
- Large ContentView refactor into modular files/extensions for easier maintenance and faster iteration.

## Non-goals (by design)

-  **X** No plugin system (for now)
-  **X** No code intelligence (LSP, refactors) but simple autocomplete
-  **X** No Electron, no cross-platform abstraction layer

This is **not** an IDE. That is intentional.

## Requirements

- macOS 26 (Tahoe)
- Xcode compatible with macOS 26 toolchain
- Apple Silicon recommended

## Support

If you find Neon Vision Editor useful and want to support its development:

- Patreon: https://www.patreon.com/h3p
- Other options: https://h3p.me/home

## Build from source

```bash
git clone https://github.com/h3pdesign/Neon-Vision-Editor.git
cd Neon-Vision-Editor
open "Neon Vision Editor.xcodeproj"


