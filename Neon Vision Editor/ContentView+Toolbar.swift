import SwiftUI
import AppKit

extension ContentView {
    @ToolbarContentBuilder
    var editorToolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Picker("Language", selection: currentLanguageBinding) {
                ForEach(["swift", "python", "javascript", "typescript", "java", "kotlin", "go", "ruby", "rust", "sql", "html", "css", "cpp", "csharp", "objective-c", "json", "xml", "yaml", "toml", "ini", "markdown", "bash", "zsh", "powershell", "standard", "plain"], id: \.self) { lang in
                    let label: String = {
                        switch lang {
                        case "objective-c": return "Objective‑C"
                        case "csharp": return "C#"
                        case "cpp": return "C++"
                        case "json": return "JSON"
                        case "xml": return "XML"
                        case "yaml": return "YAML"
                        case "toml": return "TOML"
                        case "ini": return "INI"
                        case "sql": return "SQL"
                        case "html": return "HTML"
                        case "css": return "CSS"
                        case "standard": return "Standard"
                        default: return lang.capitalized
                        }
                    }()
                    Text(label).tag(lang)
                }
            }
            .labelsHidden()
            .help("Language")
            .controlSize(.large)
            .frame(width: 140)
            .padding(.vertical, 2)

            Button(action: {
                showAISelectorPopover.toggle()
            }) {
                Image(systemName: "brain.head.profile")
            }
            .help("AI Model & Settings")
            .popover(isPresented: $showAISelectorPopover) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Model").font(.headline)
                    Picker("AI Model", selection: $selectedModel) {
                        HStack(spacing: 6) {
                            Image(systemName: "brain.head.profile")
                            Text("Apple Intelligence")
                        }
                        .tag(AIModel.appleIntelligence)
                        Text("Grok").tag(AIModel.grok)
                        Text("OpenAI").tag(AIModel.openAI)
                        Text("Gemini").tag(AIModel.gemini)
                        Text("Anthropic").tag(AIModel.anthropic)
                    }
                    .labelsHidden()
                    .frame(width: 170)
                    .controlSize(.large)

                    Button("API Settings…") {
                        showAISelectorPopover = false
                        showAPISettings = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding(12)
            }

            Text(activeProviderName)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12), in: Capsule())
                .help("Active provider")

            Button(action: {
                currentContentBinding.wrappedValue = ""
                if let tv = NSApp.keyWindow?.firstResponder as? NSTextView {
                    tv.string = ""
                    tv.didChangeText()
                    tv.setSelectedRange(NSRange(location: 0, length: 0))
                    tv.scrollRangeToVisible(NSRange(location: 0, length: 0))
                }
                caretStatus = "Ln 1, Col 1"
            }) {
                Image(systemName: "trash")
            }
            .help("Clear Editor")

            Button(action: {
                isAutoCompletionEnabled.toggle()
            }) {
                Image(systemName: isAutoCompletionEnabled ? "bolt.horizontal.circle.fill" : "bolt.horizontal.circle")
            }
            .help(isAutoCompletionEnabled ? "Disable Code Completion" : "Enable Code Completion")

            Button(action: { viewModel.openFile() }) {
                Image(systemName: "folder")
            }
            .help("Open File…")

            Button(action: {
                openWindow(id: "blank-window")
            }) {
                Image(systemName: "macwindow.badge.plus")
            }
            .help("New Window")

            Button(action: {
                if let tab = viewModel.selectedTab { viewModel.saveFile(tab: tab) }
            }) {
                Image(systemName: "square.and.arrow.down")
            }
            .disabled(viewModel.selectedTab == nil)
            .help("Save File")

            Button(action: {
                viewModel.showSidebar.toggle()
            }) {
                Image(systemName: viewModel.showSidebar ? "sidebar.left" : "sidebar.right")
            }
            .help("Toggle Sidebar")

            Button(action: {
                showProjectStructureSidebar.toggle()
            }) {
                Image(systemName: "sidebar.right")
                    .symbolVariant(showProjectStructureSidebar ? .fill : .none)
            }
            .help("Toggle Project Structure Sidebar")

            Button(action: {
                showFindReplace = true
            }) {
                Image(systemName: "magnifyingglass")
            }
            .keyboardShortcut("f", modifiers: .command)
            .help("Find & Replace")

            Button(action: {
                viewModel.isBrainDumpMode.toggle()
                UserDefaults.standard.set(viewModel.isBrainDumpMode, forKey: "BrainDumpModeEnabled")
            }) {
                Image(systemName: viewModel.isBrainDumpMode ? "note.text" : "note.text")
                    .symbolVariant(viewModel.isBrainDumpMode ? .fill : .none)
            }
            .help("Brain Dump Mode")
            .accessibilityLabel("Brain Dump Mode")

            Button(action: {
                enableTranslucentWindow.toggle()
                UserDefaults.standard.set(enableTranslucentWindow, forKey: "EnableTranslucentWindow")
                NotificationCenter.default.post(name: .toggleTranslucencyRequested, object: enableTranslucentWindow)
            }) {
                Image(systemName: enableTranslucentWindow ? "rectangle.fill" : "rectangle")
            }
            .help("Toggle Translucent Window Background")
            .accessibilityLabel("Translucent Window Background")

            Button(action: { viewModel.isLineWrapEnabled.toggle() }) {
                Image(systemName: viewModel.isLineWrapEnabled ? "text.justify" : "text.alignleft")
            }
            .help(viewModel.isLineWrapEnabled ? "Disable Wrap" : "Enable Wrap")
        }
    }
}
