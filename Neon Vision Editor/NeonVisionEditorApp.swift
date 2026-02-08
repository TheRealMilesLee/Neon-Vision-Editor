import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif
#if os(macOS)
import AppKit
#endif

#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var viewModel: EditorViewModel?

    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor in
            for url in urls {
                self.viewModel?.openFile(url: url)
            }
        }
    }
}

private struct DetachedWindowContentView: View {
    @StateObject private var viewModel = EditorViewModel()
    @Binding var showGrokError: Bool
    @Binding var grokErrorMessage: String

    var body: some View {
        ContentView()
            .environmentObject(viewModel)
            .environment(\.showGrokError, $showGrokError)
            .environment(\.grokErrorMessage, $grokErrorMessage)
            .frame(minWidth: 600, minHeight: 400)
    }
}
#endif

@main
struct NeonVisionEditorApp: App {
    @StateObject private var viewModel = EditorViewModel()
#if os(macOS)
    @Environment(\.openWindow) private var openWindow
    @State private var useAppleIntelligence: Bool = true
    @State private var appleAIStatus: String = "Apple Intelligence: Checking…"
    @State private var appleAIRoundTripMS: Double? = nil
    @State private var enableTranslucentWindow: Bool = UserDefaults.standard.bool(forKey: "EnableTranslucentWindow")
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
#endif
    @State private var showGrokError: Bool = false
    @State private var grokErrorMessage: String = ""

    private var appleAIStatusMenuLabel: String {
        if appleAIStatus.contains("Ready") { return "AI: Ready" }
        if appleAIStatus.contains("Checking") { return "AI: Checking" }
        if appleAIStatus.contains("Unavailable") { return "AI: Unavailable" }
        if appleAIStatus.contains("Error") { return "AI: Error" }
        return "AI: Status"
    }

    init() {
        SecureTokenStore.migrateLegacyUserDefaultsTokens()
        // Safety reset: avoid stale NORMAL-mode state making editor appear non-editable.
        UserDefaults.standard.set(false, forKey: "EditorVimModeEnabled")
    }

    var body: some Scene {
#if os(macOS)
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear { appDelegate.viewModel = viewModel }
                .environment(\.showGrokError, $showGrokError)
                .environment(\.grokErrorMessage, $grokErrorMessage)
                .frame(minWidth: 600, minHeight: 400)
                .task {
                    #if USE_FOUNDATION_MODELS
                    do {
                        let start = Date()
                        _ = try await AppleFM.appleFMHealthCheck()
                        let end = Date()
                        appleAIStatus = "Apple Intelligence: Ready"
                        appleAIRoundTripMS = end.timeIntervalSince(start) * 1000.0
                    } catch {
                        appleAIStatus = "Apple Intelligence: Error — \(error.localizedDescription)"
                        appleAIRoundTripMS = nil
                    }
                    #else
                    appleAIStatus = "Apple Intelligence: Unavailable (build without USE_FOUNDATION_MODELS)"
                    #endif
                }
                .onReceive(NotificationCenter.default.publisher(for: .toggleTranslucencyRequested)) { notif in
                    if let enabled = notif.object as? Bool {
                        enableTranslucentWindow = enabled
                        if let window = NSApp.windows.first {
                            window.isOpaque = !enabled
                            window.backgroundColor = enabled ? .clear : NSColor.windowBackgroundColor
                            window.titlebarAppearsTransparent = enabled
                        }
                    }
                }
                .onAppear {
                    if let window = NSApp.windows.first {
                        window.isOpaque = !enableTranslucentWindow
                        window.backgroundColor = enableTranslucentWindow ? .clear : NSColor.windowBackgroundColor
                        window.titlebarAppearsTransparent = enableTranslucentWindow
                    }
                }
        }
        .defaultSize(width: 1000, height: 600)

        WindowGroup("New Window", id: "blank-window") {
            DetachedWindowContentView(
                showGrokError: $showGrokError,
                grokErrorMessage: $grokErrorMessage
            )
        }
        .defaultSize(width: 1000, height: 600)

        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Window") {
                    openWindow(id: "blank-window")
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("New Tab") {
                    viewModel.addNewTab()
                }
                .keyboardShortcut("t", modifiers: .command)
            }

            CommandGroup(after: .newItem) {
                Button("Open File...") {
                    viewModel.openFile()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    if let tab = viewModel.selectedTab {
                        viewModel.saveFile(tab: tab)
                    }
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(viewModel.selectedTab == nil)

                Button("Save As...") {
                    if let tab = viewModel.selectedTab {
                        viewModel.saveFileAs(tab: tab)
                    }
                }
                .disabled(viewModel.selectedTab == nil)

                Button("Rename") {
                    viewModel.showingRename = true
                    viewModel.renameText = viewModel.selectedTab?.name ?? "Untitled"
                }
                .disabled(viewModel.selectedTab == nil)

                Divider()

                Button("Close Tab") {
                    if let tab = viewModel.selectedTab {
                        viewModel.closeTab(tab: tab)
                    }
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(viewModel.selectedTab == nil)
            }

            CommandMenu("Language") {
                ForEach(["swift", "python", "javascript", "typescript", "php", "java", "kotlin", "go", "ruby", "rust", "sql", "html", "css", "cpp", "csharp", "objective-c", "json", "xml", "yaml", "toml", "csv", "ini", "markdown", "bash", "zsh", "powershell", "standard", "plain"], id: \.self) { lang in
                    let label: String = {
                        switch lang {
                        case "php": return "PHP"
                        case "objective-c": return "Objective-C"
                        case "csharp": return "C#"
                        case "cpp": return "C++"
                        case "json": return "JSON"
                        case "xml": return "XML"
                        case "yaml": return "YAML"
                        case "toml": return "TOML"
                        case "csv": return "CSV"
                        case "ini": return "INI"
                        case "sql": return "SQL"
                        case "html": return "HTML"
                        case "css": return "CSS"
                        case "standard": return "Standard"
                        default: return lang.capitalized
                        }
                    }()
                    Button(label) {
                        if let tab = viewModel.selectedTab {
                            viewModel.updateTabLanguage(tab: tab, language: lang)
                        }
                    }
                    .disabled(viewModel.selectedTab == nil)
                }
            }

            CommandMenu("AI") {
                Button("API Settings…") {
                    NotificationCenter.default.post(name: .showAPISettingsRequested, object: nil)
                }

                Divider()

                Button("Use Apple Intelligence") {
                    NotificationCenter.default.post(name: .selectAIModelRequested, object: AIModel.appleIntelligence.rawValue)
                }
                Button("Use Grok") {
                    NotificationCenter.default.post(name: .selectAIModelRequested, object: AIModel.grok.rawValue)
                }
                Button("Use OpenAI") {
                    NotificationCenter.default.post(name: .selectAIModelRequested, object: AIModel.openAI.rawValue)
                }
                Button("Use Gemini") {
                    NotificationCenter.default.post(name: .selectAIModelRequested, object: AIModel.gemini.rawValue)
                }
                Button("Use Anthropic") {
                    NotificationCenter.default.post(name: .selectAIModelRequested, object: AIModel.anthropic.rawValue)
                }
            }

            CommandGroup(after: .toolbar) {
                Toggle("Toggle Sidebar", isOn: $viewModel.showSidebar)
                    .keyboardShortcut("s", modifiers: [.command, .option])

                Button("Toggle Project Structure Sidebar") {
                    NotificationCenter.default.post(name: .toggleProjectStructureSidebarRequested, object: nil)
                }

                Toggle("Brain Dump Mode", isOn: $viewModel.isBrainDumpMode)
                    .keyboardShortcut("d", modifiers: [.command, .shift])

                Toggle("Line Wrap", isOn: $viewModel.isLineWrapEnabled)
                    .keyboardShortcut("l", modifiers: [.command, .option])

                Button("Toggle Translucent Window Background") {
                    NotificationCenter.default.post(name: .toggleTranslucencyRequested, object: !enableTranslucentWindow)
                }

                Divider()

                Button("Show Welcome Tour") {
                    NotificationCenter.default.post(name: .showWelcomeTourRequested, object: nil)
                }
            }

            CommandMenu("Editor") {
                Button("Quick Open…") {
                    NotificationCenter.default.post(name: .showQuickSwitcherRequested, object: nil)
                }
                .keyboardShortcut("p", modifiers: .command)

                Button("Clear Editor") {
                    NotificationCenter.default.post(name: .clearEditorRequested, object: nil)
                }

                Button("Toggle Code Completion") {
                    NotificationCenter.default.post(name: .toggleCodeCompletionRequested, object: nil)
                }

                Button("Find & Replace") {
                    NotificationCenter.default.post(name: .showFindReplaceRequested, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)

                Divider()

                Button("Toggle Vim Mode") {
                    NotificationCenter.default.post(name: .toggleVimModeRequested, object: nil)
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
            }

            CommandMenu("Tools") {
                Button("Suggest Code") {
                    Task {
                        if let tab = viewModel.selectedTab {
                            let contentPrefix = String(tab.content.prefix(1000))
                            let prompt = "Suggest improvements for this \(tab.language) code: \(contentPrefix)"

                            let grokToken = SecureTokenStore.token(for: .grok)
                            let openAIToken = SecureTokenStore.token(for: .openAI)
                            let geminiToken = SecureTokenStore.token(for: .gemini)

                            let client: AIClient? = {
                                #if USE_FOUNDATION_MODELS
                                if useAppleIntelligence {
                                    return AIClientFactory.makeClient(for: AIModel.appleIntelligence)
                                }
                                #endif
                                if !grokToken.isEmpty { return AIClientFactory.makeClient(for: .grok, grokAPITokenProvider: { grokToken }) }
                                if !openAIToken.isEmpty { return AIClientFactory.makeClient(for: .openAI, openAIKeyProvider: { openAIToken }) }
                                if !geminiToken.isEmpty { return AIClientFactory.makeClient(for: .gemini, geminiKeyProvider: { geminiToken }) }
                                #if USE_FOUNDATION_MODELS
                                return AIClientFactory.makeClient(for: .appleIntelligence)
                                #else
                                return nil
                                #endif
                            }()

                            guard let client else { grokErrorMessage = "No AI provider configured."; showGrokError = true; return }

                            var aggregated = ""
                            for await chunk in client.streamSuggestions(prompt: prompt) { aggregated += chunk }

                            viewModel.updateTabContent(tab: tab, content: tab.content + "\n\n// AI Suggestion:\n" + aggregated)
                        }
                    }
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(viewModel.selectedTab == nil)

                Toggle("Use Apple Intelligence", isOn: $useAppleIntelligence)
            }

            CommandMenu("Diag") {
                Text(appleAIStatusMenuLabel)
                Divider()
                Button("Run AI Check") {
                    Task {
                        #if USE_FOUNDATION_MODELS
                        do {
                            let start = Date()
                            _ = try await AppleFM.appleFMHealthCheck()
                            let end = Date()
                            appleAIStatus = "Apple Intelligence: Ready"
                            appleAIRoundTripMS = end.timeIntervalSince(start) * 1000.0
                        } catch {
                            appleAIStatus = "Apple Intelligence: Error — \(error.localizedDescription)"
                            appleAIRoundTripMS = nil
                        }
                        #else
                        appleAIStatus = "Apple Intelligence: Unavailable (build without USE_FOUNDATION_MODELS)"
                        appleAIRoundTripMS = nil
                        #endif
                    }
                }

                if let ms = appleAIRoundTripMS {
                    Text(String(format: "RTT: %.1f ms", ms))
                        .foregroundStyle(.secondary)
                }
            }
        }
#else
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environment(\.showGrokError, $showGrokError)
                .environment(\.grokErrorMessage, $grokErrorMessage)
        }
#endif
    }
}

struct ShowGrokErrorKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

struct GrokErrorMessageKey: EnvironmentKey {
    static let defaultValue: Binding<String> = .constant("")
}

extension EnvironmentValues {
    var showGrokError: Binding<Bool> {
        get { self[ShowGrokErrorKey.self] }
        set { self[ShowGrokErrorKey.self] = newValue }
    }

    var grokErrorMessage: Binding<String> {
        get { self[GrokErrorMessageKey.self] }
        set { self[GrokErrorMessageKey.self] = newValue }
    }
}
