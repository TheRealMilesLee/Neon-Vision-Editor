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

> Status: **beta**  
> Platform target: **macOS 26 (Tahoe)**
> Built/tested with Xcode
> Apple Silicon: tested / Intel: not tested

## Download

Prebuilt binaries are available via **GitHub Releases**:

- Latest release: **v0.4.1-beta**
- Architecture: Apple Silicon (Intel not tested)
- Notarization: *not yet*

If you don’t want to build from source, this is the recommended path:

- Download the `.zip` or `.dmg` from **Releases**
- Move the app to `/Applications`

## Quick install (curl)

Install the latest release directly:

```bash
curl -fsSL https://raw.githubusercontent.com/h3pdesign/Neon-Vision-Editor/main/scripts/install.sh | sh
```

Install without admin password prompts (user-local app folder):

```bash
curl -fsSL https://raw.githubusercontent.com/h3pdesign/Neon-Vision-Editor/main/scripts/install.sh | sh -s -- --appdir "$HOME/Applications"
```

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

- Performance: Fast loading, including large text files. 
- Editing: Regex Find/Replace with Replace All. 
- Navigation: Project tree sidebar; Cmd+P Quick Open and file switcher. 
- Vim: Optional Vim mode (basic normal-mode navigation). 
- Languages: Automatic syntax highlighting for common languages (Python, PHP, C/C++, JavaScript, HTML, CSS, and more). 
- UI: Clean, minimal UI optimized for readability; native macOS 26 (Tahoe) look & behavior. 
- Built with: Swift + AppKit.

## Changelog 

### Editor
- Added regex-capable Find/Replace with Replace All and quick toolbar access. 
- Improved focus and editor interaction behavior overall. 
- Added Cmd+P Quick Open plus a quick file switcher panel integration. 
- Extended editor command handling for faster navigation and file switching. 
- Kept fallback behavior to protect caret focus and text input stability. 

### Project navigation
- Added a right-side project structure panel with recursive folder tree browsing. 

### Vim mode
- Added basic Vim navigation and a Quick Open workflow in the editor. 
- Added Vim mode toggle support to the editor command set. 
- Implemented core normal-mode movement keys (h/j/k/l) and insert-mode transitions. 
- Wired Vim mode state updates through notifications for UI/status sync. 

### Windows & UI
- Added a dedicated New Window flow that opens blank/isolated windows. 
- Added richer window controls in the toolbar (including sidebar/window toggles). 
- Improved sidebar and window-state handling across the app. 
- Improved translucency support in editor/window surfaces. 
- Removed the extra inner-edge border and tuned card/container visual balance. 

### Language support & highlighting
- Added/expanded local language detection heuristics. 
- Improved syntax highlighting behavior (including Markdown edge cases). 
- Added comprehensive PHP and CSV language support. 
- Refined JSON/TOML syntax highlighting. 

### Onboarding & docs
- Documented Homebrew installation. 
- Added a first-launch Welcome Tour sheet with richer feature messaging. 
- Kept iOS/iPad paged tour behavior while using a macOS-compatible TabView style. 

### Menus
- Consolidated duplicate View menu entries into the system View menu. 
- Shortened Diagnostics menu labels and entries (compact status/check/RTT text). 

### Internal & distribution
- Refactored the large ContentView into modular files/extensions for easier maintenance and faster iteration. 
- Hardened security and improved App Store distribution readiness.


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
```

## Homebrew install option

If you use Homebrew, you can install via cask:

```bash
brew tap h3pdesign/tap
brew install --cask neon-vision-editor
```

If Homebrew asks for an admin password, it is usually because it installs casks into `/Applications`.
To avoid that, use:

```bash
brew install --cask --appdir="$HOME/Applications" neon-vision-editor
```

## License

Neon Vision Editor is licensed under the MIT License.
See [`LICENSE`](LICENSE).


