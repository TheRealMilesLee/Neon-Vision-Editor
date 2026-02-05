import SwiftUI
import FoundationModels
import AppKit

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

@main
struct NeonVisionEditorApp: App {
    @StateObject private var viewModel = EditorViewModel()
    @State private var showGrokError: Bool = false
    @State private var grokErrorMessage: String = ""
    @State private var useAppleIntelligence: Bool = true
    @State private var appleAIStatus: String = "Apple Intelligence: Checking…"
    @State private var appleAIRoundTripMS: Double? = nil
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
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
        }
        .defaultSize(width: 1000, height: 600)
        .commands {
            CommandMenu("File") {
                Button("New Tab") {
                    viewModel.addNewTab()
                }
                .keyboardShortcut("t", modifiers: .command)
                
                Button("Open File...") {
                    viewModel.openFile()
                }
                .keyboardShortcut("o", modifiers: .command)
                
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
                
                Button("Close Tab") {
                    if let tab = viewModel.selectedTab {
                        viewModel.closeTab(tab: tab)
                    }
                }
                .keyboardShortcut("w", modifiers: .command)
                .disabled(viewModel.selectedTab == nil)
            }
            
            CommandMenu("Language") {
                ForEach(["swift", "python", "javascript", "html", "css", "cpp", "csharp", "json", "markdown", "standard", "plain"], id: \.self) { lang in
                    Button(lang.capitalized) {
                        if let tab = viewModel.selectedTab {
                            viewModel.updateTabLanguage(tab: tab, language: lang)
                        }
                    }
                    .disabled(viewModel.selectedTab == nil)
                }
            }
            
            CommandMenu("View") {
                Toggle("Toggle Sidebar", isOn: $viewModel.showSidebar)
                    .keyboardShortcut("s", modifiers: [.command, .option])
                
                Toggle("Brain Dump Mode", isOn: $viewModel.isBrainDumpMode)
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                
                Toggle("Line Wrap", isOn: $viewModel.isLineWrapEnabled)
                    .keyboardShortcut("l", modifiers: [.command, .option])
            }
            
            CommandMenu("Tools") {
                Button("Suggest Code") {
                    Task {
                        if let tab = viewModel.selectedTab {
                            // Choose provider by available tokens (Apple Intelligence preferred) then others
                            let contentPrefix = String(tab.content.prefix(1000))
                            let prompt = "Suggest improvements for this \(tab.language) code: \(contentPrefix)"

                            let grokToken = UserDefaults.standard.string(forKey: "GrokAPIToken") ?? ""
                            let openAIToken = UserDefaults.standard.string(forKey: "OpenAIAPIToken") ?? ""
                            let geminiToken = UserDefaults.standard.string(forKey: "GeminiAPIToken") ?? ""

                            let client: AIClient? = {
                                #if USE_FOUNDATION_MODELS
                                // Prefer Apple Intelligence by default
                                if useAppleIntelligence {
                                    return AIClientFactory.makeClient(for: .appleIntelligence)
                                }
                                #endif
                                // Fallback order: Grok -> OpenAI -> Gemini -> Apple (if compiled) -> nil
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
            
            CommandMenu("Diagnostics") {
                Text(appleAIStatus)
                Divider()
                Button("Re-run Apple Intelligence Health Check") {
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
                .disabled(false)

                if let ms = appleAIRoundTripMS {
                    Text(String(format: "Last round-trip: %.1f ms", ms))
                        .foregroundStyle(.secondary)
                }
            }
        }
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
    
