<h1 align="center">Neon Vision Editor</h1>

<p align="center">
  <img src="NeonVisionEditorIcon.png" alt="Neon Vision Editor Logo" width="200"/>
</p>

<h4 align="center">
  A lightweight, modern editor focused on speed, readability, and automatic syntax highlighting.
</h4>

<p align="center">
  Minimal by design: quick edits, fast file access, no IDE bloat.
</p>

<p align="center">
  Release Download: <a href="https://github.com/h3pdesign/Neon-Vision-Editor/releases">GitHub Releases</a>
</p>

> Status: **beta**  
> Latest release: **v0.4.2-beta**  
> Platform target: **macOS 26 (Tahoe)**  
> Apple Silicon: tested / Intel: not tested

## Download

Prebuilt binaries are available on [GitHub Releases](https://github.com/h3pdesign/Neon-Vision-Editor/releases).

- Latest release: **v0.4.2-beta**
- Architecture: Apple Silicon (Intel not tested)
- Notarization: *not yet*

## Getting Started (30 Seconds)

1. Install using `curl` or Homebrew (below), or download the latest `.zip`/`.dmg` from [Releases](https://github.com/h3pdesign/Neon-Vision-Editor/releases).
2. Move `Neon Vision Editor.app` to `/Applications`.
3. Launch the app.
4. Open a file with `Cmd+O`.
5. Use `Cmd+P` for Quick Open and `Cmd+F` for Find & Replace.
6. Toggle Vim mode with `Cmd+Shift+V` if needed.

## Install

### Quick install (curl)

Install the latest release directly:

```bash
curl -fsSL https://raw.githubusercontent.com/h3pdesign/Neon-Vision-Editor/main/scripts/install.sh | sh
```

Install without admin password prompts (user-local app folder):

```bash
curl -fsSL https://raw.githubusercontent.com/h3pdesign/Neon-Vision-Editor/main/scripts/install.sh | sh -s -- --appdir "$HOME/Applications"
```

### Homebrew

```bash
brew tap h3pdesign/tap
brew install --cask neon-vision-editor
```

If Homebrew asks for an admin password, it is usually because casks install into `/Applications`.
Use this to avoid that:

```bash
brew install --cask --appdir="$HOME/Applications" neon-vision-editor
```

### Gatekeeper (macOS 26 Tahoe)

If macOS blocks first launch:

1. Open **System Settings**.
2. Go to **Privacy & Security**.
3. In **Security**, find the blocked app message.
4. Click **Open Anyway**.
5. Confirm the dialog.

## Features

- Fast loading for regular and large text files.
- Regex Find/Replace with Replace All.
- Project tree sidebar plus Quick Open (`Cmd+P`).
- Optional Vim mode (basic normal/insert workflow).
- Automatic syntax highlighting for many languages and formats.
- Native Swift/AppKit editor experience.
- No telemetry.

<p align="left">
  <img src="NeonVisionEditorApp.png" alt="Neon Vision Editor App" width="1100"/>
</p>

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `Cmd+N` | New Window |
| `Cmd+T` | New Tab |
| `Cmd+O` | Open File |
| `Cmd+S` | Save |
| `Cmd+W` | Close Tab |
| `Cmd+P` | Quick Open |
| `Cmd+F` | Find & Replace |
| `Cmd+Shift+V` | Toggle Vim Mode |
| `Cmd+Option+S` | Toggle Sidebar |
| `Cmd+Option+L` | Toggle Line Wrap |
| `Cmd+Shift+D` | Toggle Brain Dump Mode |

## Changelog

### v0.4.2-beta (summary)

- Fixed toolbar/menu actions to target the active window only.
- Fixed multi-window command routing to use the focused window model.
- Unified persistence behavior for Brain Dump and translucent window toggles.
- Removed duplicate `Cmd+F` binding conflict in toolbar wiring.
- Verified command-system changes on macOS and iOS simulator builds.
- Added syntax highlighting support for `vim`, `log`, and `ipynb` files.
- Added extension-based auto-detection for `.vim`, `.log`, `.ipynb`, and `.vimrc`.
- Improved header file default highlighting by mapping `.h` to `cpp`.
- Added language picker entries for **Vim**, **Log**, and **Jupyter Notebook**.
- Fixed drag & drop import of larger text and csv files

Full release history: [`CHANGELOG.md`](CHANGELOG.md)

## Known Limitations

- Not notarized yet.
- Intel Macs are not fully validated.
- Vim support is intentionally basic (not full Vim emulation).
- iOS/iPad editor functionality is still more limited than macOS.

## Privacy & Security

- API keys are stored in Keychain (`SecureTokenStore`), not `UserDefaults`.
- Network traffic uses HTTPS.
- No telemetry.
- Security policy and reporting details: [`SECURITY.md`](SECURITY.md).

## Release Integrity

- Tag: `v0.4.2-beta`
- Tagged commit: `bc7ce77f6e08c3a751b5f80ac60ab2045956e736`
- Verify local tag target:

```bash
git rev-parse --verify v0.4.2-beta
```

- Verify downloaded artifact checksum locally:

```bash
shasum -a 256 <downloaded-file>
```

## Requirements

- macOS 26 (Tahoe)
- Xcode compatible with macOS 26 toolchain
- Apple Silicon recommended

## Build from source

```bash
git clone https://github.com/h3pdesign/Neon-Vision-Editor.git
cd Neon-Vision-Editor
open "Neon Vision Editor.xcodeproj"
```

## Support

If you want to support development:

- [Patreon](https://www.patreon.com/h3p)
- [Other options](https://h3p.me/home)

## License

Neon Vision Editor is licensed under the MIT License.
See [`LICENSE`](LICENSE).
