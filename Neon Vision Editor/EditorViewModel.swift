import SwiftUI
import Combine
import UniformTypeIdentifiers
import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct TabData: Identifiable {
    let id = UUID()
    var name: String
    var content: String
    var language: String
    var fileURL: URL?
    var languageLocked: Bool = false
    var isDirty: Bool = false
}

@MainActor
class EditorViewModel: ObservableObject {
    @Published var tabs: [TabData] = []
    @Published var selectedTabID: UUID?
    @Published var showSidebar: Bool = true
    @Published var isBrainDumpMode: Bool = false
    @Published var showingRename: Bool = false
    @Published var renameText: String = ""
    @Published var isLineWrapEnabled: Bool = true
    
    var selectedTab: TabData? {
        get { tabs.first(where: { $0.id == selectedTabID }) }
        set { selectedTabID = newValue?.id }
    }
    
    private let languageMap: [String: String] = [
        "swift": "swift",
        "py": "python",
        "js": "javascript",
        "html": "html",
        "css": "css",
        "c": "c",
        "cpp": "cpp",
        "h": "c",
        //"cs": "csharp",  // Removed this line as per instructions
        "json": "json",
        "md": "markdown",
        "sh": "bash",
        "bash": "bash",
        "zsh": "zsh"
    ]
    
    init() {
        addNewTab()
    }
    
    func addNewTab() {
        let newTab = TabData(name: "Untitled \(tabs.count + 1)", content: "", language: "swift", fileURL: nil)
        tabs.append(newTab)
        selectedTabID = newTab.id
    }
    
    func renameTab(tab: TabData, newName: String) {
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs[index].name = newName
        }
    }
    
    func updateTabContent(tab: TabData, content: String) {
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            let previous = tabs[index].content
            tabs[index].content = content
            if content != previous {
                tabs[index].isDirty = true
            }
            
            // Early lock to Swift if clearly Swift-specific tokens are present
            let lower = content.lowercased()
            let swiftStrongTokens: Bool = (
                lower.contains(" import swiftui") ||
                lower.hasPrefix("import swiftui") ||
                lower.contains("@main") ||
                lower.contains(" final class ") ||
                lower.contains("public final class ") ||
                lower.contains(": view") ||
                lower.contains("@published") ||
                lower.contains("@stateobject") ||
                lower.contains("@mainactor") ||
                lower.contains("protocol ") ||
                lower.contains("extension ") ||
                lower.contains("import appkit") ||
                lower.contains("import uikit") ||
                lower.contains("import foundationmodels") ||
                lower.contains("guard ") ||
                lower.contains("if let ")
            )
            if swiftStrongTokens {
                tabs[index].language = "swift"
                tabs[index].languageLocked = true
                return
            }
            
            if !tabs[index].languageLocked {
                // If the tab name has a known extension, honor it and lock
                let nameExt = URL(fileURLWithPath: tabs[index].name).pathExtension.lowercased()
                if let extLang = languageMap[nameExt], !extLang.isEmpty {
                    // If the extension suggests C# but content looks like Swift, prefer Swift and do not lock.
                    if extLang == "csharp" {
                        let looksSwift = lower.contains("import swiftui") || lower.contains(": view") || lower.contains("@main") || lower.contains(" final class ")
                        if looksSwift {
                            tabs[index].language = "swift"
                            tabs[index].languageLocked = true
                        } else {
                            tabs[index].language = extLang
                            tabs[index].languageLocked = true
                        }
                    } else {
                        tabs[index].language = extLang
                        tabs[index].languageLocked = true
                    }
                } else {
                    let result = LanguageDetector.shared.detect(text: content, name: tabs[index].name, fileURL: tabs[index].fileURL)
                    let detected = result.lang
                    let scores = result.scores
                    let current = tabs[index].language
                    let swiftScore = scores["swift"] ?? 0
                    let csharpScore = scores["csharp"] ?? 0

                    // Derive strong Swift tokens and C# context similar to the detector to control switching behavior
                    // (let lower = content.lowercased()) -- removed duplicate since defined above
                    let swiftStrongTokens: Bool = (
                        lower.contains(" final class ") ||
                        lower.contains("public final class ") ||
                        lower.contains(": view") ||
                        lower.contains("@published") ||
                        lower.contains("@stateobject") ||
                        lower.contains("@mainactor") ||
                        lower.contains("protocol ") ||
                        lower.contains("extension ") ||
                        lower.contains("import swiftui") ||
                        lower.contains("import appkit") ||
                        lower.contains("import uikit") ||
                        lower.contains("import foundationmodels") ||
                        lower.contains("guard ") ||
                        lower.contains("if let ")
                    )

                    let hasUsingSystem = lower.contains("\nusing system;") || lower.contains("\nusing system.")
                    let hasNamespace = lower.contains("\nnamespace ")
                    let hasMainMethod = lower.contains("static void main(") || lower.contains("static int main(")
                    let hasCSharpAttributes = (lower.contains("\n[") && lower.contains("]\n") && !lower.contains("@"))
                    let csharpContext = hasUsingSystem || hasNamespace || hasMainMethod || hasCSharpAttributes

                    // Avoid switching from Swift to C# unless there is very strong C# evidence and margin
                    if current == "swift" && detected == "csharp" {
                        let requireMargin = 25
                        if swiftStrongTokens && !csharpContext {
                            // Keep Swift when Swift-only tokens are present and no C# context exists
                        } else if !(csharpContext && csharpScore >= swiftScore + requireMargin) {
                            // Not enough evidence to switch away from Swift
                        } else {
                            tabs[index].language = "csharp"
                            tabs[index].languageLocked = false
                        }
                    } else {
                        // For all other cases, accept the detection
                        tabs[index].language = detected
                        // If Swift is confidently detected or Swift-only tokens are present, lock to prevent flip-flops
                        if detected == "swift" && (result.confidence >= 5 || swiftStrongTokens) {
                            tabs[index].languageLocked = true
                        }
                    }
                }
            }
        }
    }
    
    func updateTabLanguage(tab: TabData, language: String) {
        if let index = tabs.firstIndex(where: { $0.id == tab.id }) {
            tabs[index].language = language
            tabs[index].languageLocked = true
        }
    }
    
    func closeTab(tab: TabData) {
        tabs.removeAll { $0.id == tab.id }
        if tabs.isEmpty {
            addNewTab()
        } else if selectedTabID == tab.id {
            selectedTabID = tabs.first?.id
        }
    }
    
    func saveFile(tab: TabData) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
        if let url = tabs[index].fileURL {
            do {
                try tabs[index].content.write(to: url, atomically: true, encoding: .utf8)
                tabs[index].isDirty = false
            } catch {
                debugLog("Failed to save file.")
            }
        } else {
            saveFileAs(tab: tab)
        }
    }
    
    func saveFileAs(tab: TabData) {
        guard let index = tabs.firstIndex(where: { $0.id == tab.id }) else { return }
#if os(macOS)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = tabs[index].name
        let mdType = UTType(filenameExtension: "md") ?? .plainText
        panel.allowedContentTypes = [
            .text,
            .swiftSource,
            .pythonScript,
            .javaScript,
            .html,
            .css,
            .cSource,
            .json,
            mdType
        ]

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try tabs[index].content.write(to: url, atomically: true, encoding: .utf8)
                tabs[index].fileURL = url
                tabs[index].name = url.lastPathComponent
                tabs[index].isDirty = false
            } catch {
                debugLog("Failed to save file.")
            }
        }
#else
        // iOS/iPadOS: explicit Save As panel is not available here yet.
        // Keep document dirty so user can export/share via future document APIs.
        debugLog("Save As is currently only available on macOS.")
#endif
    }
    
    func openFile() {
#if os(macOS)
        let panel = NSOpenPanel()
        // Allow opening any file type, including hidden dotfiles like .zshrc
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.showsHiddenFiles = true

        if panel.runModal() == .OK, let url = panel.url {
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                let extLang = languageMap[url.pathExtension.lowercased()]
                let detectedLang = extLang ?? LanguageDetector.shared.detect(text: content, name: url.lastPathComponent, fileURL: url).lang
                let newTab = TabData(name: url.lastPathComponent,
                                     content: content,
                                     language: detectedLang,
                                     fileURL: url,
                                     languageLocked: extLang != nil,
                                     isDirty: false)
                tabs.append(newTab)
                selectedTabID = newTab.id
            } catch {
                debugLog("Failed to open file.")
            }
        }
#else
        // iOS/iPadOS: document picker flow can be added here.
        debugLog("Open File panel is currently only available on macOS.")
#endif
    }
    
    func openFile(url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let extLang = languageMap[url.pathExtension.lowercased()]
            let detectedLang = extLang ?? LanguageDetector.shared.detect(text: content, name: url.lastPathComponent, fileURL: url).lang
            let newTab = TabData(name: url.lastPathComponent,
                                 content: content,
                                 language: detectedLang,
                                 fileURL: url,
                                 languageLocked: extLang != nil,
                                 isDirty: false)
            tabs.append(newTab)
            selectedTabID = newTab.id
        } catch {
            debugLog("Failed to open file.")
        }
    }

    func markTabSaved(tabID: UUID, fileURL: URL? = nil) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        if let fileURL {
            tabs[index].fileURL = fileURL
            tabs[index].name = fileURL.lastPathComponent
        }
        tabs[index].isDirty = false
    }
    
    func wordCount(for text: String) -> Int {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
    }

    private func debugLog(_ message: String) {
#if DEBUG
        print(message)
#endif
    }
}
