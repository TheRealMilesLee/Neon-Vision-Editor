// ContentView.swift
// Main SwiftUI container for Neon Vision Editor. Hosts the single-document editor UI,
// toolbar actions, AI integration, syntax highlighting, line numbers, and sidebar TOC.

// MARK: - Imports
import SwiftUI
import Foundation
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
#if USE_FOUNDATION_MODELS
import FoundationModels
#endif


// Utility: quick width calculation for strings with a given font (AppKit-based)
extension String {
#if os(macOS)
    func width(usingFont font: NSFont) -> CGFloat {
        let attributes = [NSAttributedString.Key.font: font]
        let size = (self as NSString).size(withAttributes: attributes)
        return size.width
    }
#endif
}

// MARK: - Root view for the editor.
//Manages the editor area, toolbar, popovers, and bridges to the view model for file I/O and metrics.
struct ContentView: View {
    // Environment-provided view model and theme/error bindings
    @EnvironmentObject var viewModel: EditorViewModel
    @Environment(\.colorScheme) var colorScheme
#if os(iOS)
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
#endif
#if os(macOS)
    @Environment(\.openWindow) var openWindow
#endif
    @Environment(\.showGrokError) var showGrokError
    @Environment(\.grokErrorMessage) var grokErrorMessage

    // Single-document fallback state (used when no tab model is selected)
    @State var selectedModel: AIModel = .appleIntelligence
    @State var singleContent: String = ""
    @State var singleLanguage: String = "swift"
    @State var caretStatus: String = "Ln 1, Col 1"
    @State var editorFontSize: CGFloat = 14
    @State var lastProviderUsed: String = "Apple"

    // Persisted API tokens for external providers
    @State var grokAPIToken: String = SecureTokenStore.token(for: .grok)
    @State var openAIAPIToken: String = SecureTokenStore.token(for: .openAI)
    @State var geminiAPIToken: String = SecureTokenStore.token(for: .gemini)
    @State var anthropicAPIToken: String = SecureTokenStore.token(for: .anthropic)

    // Debounce handle for inline completion
    @State var lastCompletionWorkItem: DispatchWorkItem?
    @State var isAutoCompletionEnabled: Bool = false
    @State var enableTranslucentWindow: Bool = UserDefaults.standard.bool(forKey: "EnableTranslucentWindow")

    // Added missing popover UI state
    @State var showAISelectorPopover: Bool = false
    @State var showAPISettings: Bool = false

    @State var showFindReplace: Bool = false
    @State var findQuery: String = ""
    @State var replaceQuery: String = ""
    @State var findUsesRegex: Bool = false
    @State var findCaseSensitive: Bool = false
    @State var findStatusMessage: String = ""
    @State var showProjectStructureSidebar: Bool = false
    @State var showCompactSidebarSheet: Bool = false
    @State var projectRootFolderURL: URL? = nil
    @State var projectTreeNodes: [ProjectTreeNode] = []
    @State var pendingCloseTabID: UUID? = nil
    @State var showUnsavedCloseDialog: Bool = false
    @State var showIOSFileImporter: Bool = false
    @State var showIOSFileExporter: Bool = false
    @State var iosExportDocument: PlainTextDocument = PlainTextDocument(text: "")
    @State var iosExportFilename: String = "Untitled.txt"
    @State var iosExportTabID: UUID? = nil
    @State var showQuickSwitcher: Bool = false
    @State var quickSwitcherQuery: String = ""
    @State var vimModeEnabled: Bool = UserDefaults.standard.bool(forKey: "EditorVimModeEnabled")
    @State var vimInsertMode: Bool = true
    @State var droppedFileLoadInProgress: Bool = false
    @State var droppedFileProgressDeterminate: Bool = true
    @State var droppedFileLoadProgress: Double = 0
    @State var droppedFileLoadLabel: String = ""
    @State var largeFileModeEnabled: Bool = false
    @AppStorage("HasSeenWelcomeTourV1") var hasSeenWelcomeTourV1: Bool = false
    @State var showWelcomeTour: Bool = false
#if os(macOS)
    @State private var hostWindowNumber: Int? = nil
#endif

#if USE_FOUNDATION_MODELS
    var appleModelAvailable: Bool { true }
#else
    var appleModelAvailable: Bool { false }
#endif

    var activeProviderName: String { lastProviderUsed }

    /// Prompts the user for a Grok token if none is saved. Persists to Keychain.
    /// Returns true if a token is present/was saved; false if cancelled or empty.
    private func promptForGrokTokenIfNeeded() -> Bool {
        if !grokAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
#if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Grok API Token Required"
        alert.informativeText = "Enter your Grok API token to enable suggestions. You can obtain this from your Grok account."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        input.placeholderString = "sk-..."
        alert.accessoryView = input
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let token = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if token.isEmpty { return false }
            grokAPIToken = token
            SecureTokenStore.setToken(token, for: .grok)
            return true
        }
#endif
        return false
    }

    /// Prompts the user for an OpenAI token if none is saved. Persists to Keychain.
    /// Returns true if a token is present/was saved; false if cancelled or empty.
    private func promptForOpenAITokenIfNeeded() -> Bool {
        if !openAIAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
#if os(macOS)
        let alert = NSAlert()
        alert.messageText = "OpenAI API Token Required"
        alert.informativeText = "Enter your OpenAI API token to enable suggestions."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        input.placeholderString = "sk-..."
        alert.accessoryView = input
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let token = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if token.isEmpty { return false }
            openAIAPIToken = token
            SecureTokenStore.setToken(token, for: .openAI)
            return true
        }
#endif
        return false
    }

    /// Prompts the user for a Gemini token if none is saved. Persists to Keychain.
    /// Returns true if a token is present/was saved; false if cancelled or empty.
    private func promptForGeminiTokenIfNeeded() -> Bool {
        if !geminiAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
#if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Gemini API Key Required"
        alert.informativeText = "Enter your Gemini API key to enable suggestions."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        input.placeholderString = "AIza..."
        alert.accessoryView = input
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let token = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if token.isEmpty { return false }
            geminiAPIToken = token
            SecureTokenStore.setToken(token, for: .gemini)
            return true
        }
#endif
        return false
    }

    /// Prompts the user for an Anthropic API token if none is saved. Persists to Keychain.
    /// Returns true if a token is present/was saved; false if cancelled or empty.
    private func promptForAnthropicTokenIfNeeded() -> Bool {
        if !anthropicAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
#if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Anthropic API Token Required"
        alert.informativeText = "Enter your Anthropic API token to enable suggestions."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        input.placeholderString = "sk-ant-..."
        alert.accessoryView = input
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let token = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if token.isEmpty { return false }
            anthropicAPIToken = token
            SecureTokenStore.setToken(token, for: .anthropic)
            return true
        }
#endif
        return false
    }

    private func performInlineCompletion() {
        Task {
            await performInlineCompletionAsync()
        }
    }

    private func performInlineCompletionAsync() async {
#if os(macOS)
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
        let sel = textView.selectedRange()
        guard sel.length == 0 else { return }
        let loc = sel.location
        guard loc > 0, loc <= (textView.string as NSString).length else { return }
        let nsText = textView.string as NSString

        let prevChar = nsText.substring(with: NSRange(location: loc - 1, length: 1))
        var nextChar: String? = nil
        if loc < nsText.length {
            nextChar = nsText.substring(with: NSRange(location: loc, length: 1))
        }

        // Auto-close braces/brackets/parens if not already closed
        let pairs: [String: String] = ["{": "}", "(": ")", "[": "]"]
        if let closing = pairs[prevChar] {
            if nextChar != closing {
                // Insert closing and move caret back between pair
                let insertion = closing
                textView.insertText(insertion, replacementRange: sel)
                textView.setSelectedRange(NSRange(location: loc, length: 0))
                return
            }
        }

        // If previous char is '{' and language is swift, javascript, c, or cpp, insert code block scaffold
        if prevChar == "{" && ["swift", "javascript", "c", "cpp"].contains(currentLanguage) {
            // Get current line indentation
            let fullText = textView.string as NSString
            let lineRange = fullText.lineRange(for: NSRange(location: loc - 1, length: 0))
            let lineText = fullText.substring(with: lineRange)
            let indentPrefix = lineText.prefix(while: { $0 == " " || $0 == "\t" })

            let indentString = String(indentPrefix)
            let indentLevel = indentString.count
            let indentSpaces = "    " // 4 spaces

            // Build scaffold string
            let scaffold = "\n\(indentString)\(indentSpaces)\n\(indentString)}"

            // Insert scaffold at caret position
            textView.insertText(scaffold, replacementRange: NSRange(location: loc, length: 0))

            // Move caret to indented empty line
            let newCaretLocation = loc + 1 + indentLevel + indentSpaces.count
            textView.setSelectedRange(NSRange(location: newCaretLocation, length: 0))
            return
        }

        // Model-backed completion attempt
        let doc = textView.string
        // Limit the prefix context length to 2000 UTF-16 code units max for performance
        let nsDoc = doc as NSString
        let prefixStart = max(0, loc - 2000)
        let prefixRange = NSRange(location: prefixStart, length: loc - prefixStart)
        let contextPrefix = nsDoc.substring(with: prefixRange)

        let suggestion = await generateModelCompletion(prefix: contextPrefix, language: currentLanguage)

        guard !suggestion.isEmpty else { return }

        // Insert suggestion after caret without duplicating existing text and without scrolling
        await MainActor.run {
            let currentText = textView.string as NSString
            let insertionRange = NSRange(location: sel.location, length: 0)
            // Check for duplication: skip if suggestion prefix matches next characters after caret
            let nextRangeLength = min(suggestion.count, currentText.length - sel.location)
            let nextText = nextRangeLength > 0 ? currentText.substring(with: NSRange(location: sel.location, length: nextRangeLength)) : ""
            if nextText.starts(with: suggestion) {
                // Already present, do nothing
                return
            }
            // Insert the suggestion
            textView.insertText(suggestion, replacementRange: insertionRange)
            // Restore the selection to after inserted text
            textView.setSelectedRange(NSRange(location: sel.location + (suggestion as NSString).length, length: 0))
            // Scroll to visible range of inserted text
            textView.scrollRangeToVisible(NSRange(location: sel.location + (suggestion as NSString).length, length: 0))
        }
#else
        // iOS inline completion hook can be added for UITextView selection APIs.
        return
#endif
    }

    private func externalModelCompletion(prefix: String, language: String) async -> String {
        // Try Grok
        if !grokAPIToken.isEmpty {
            do {
                let url = URL(string: "https://api.x.ai/v1/chat/completions")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(grokAPIToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let prompt = """
                Continue the following \(language) code snippet with a few lines or tokens of code only. Do not add prose or explanations.

                \(prefix)

                Completion:
                """
                let body: [String: Any] = [
                    "model": "grok-2-latest",
                    "messages": [["role": "user", "content": prompt]],
                    "temperature": 0.5,
                    "max_tokens": 64,
                    "n": 1,
                    "stop": [""]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    return sanitizeCompletion(content)
                }
            } catch {
                debugLog("[Completion][Fallback][Grok] request failed")
            }
        }
        // Try OpenAI
        if !openAIAPIToken.isEmpty {
            do {
                let url = URL(string: "https://api.openai.com/v1/chat/completions")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(openAIAPIToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let prompt = """
                Continue the following \(language) code snippet with a few lines or tokens of code only. Do not add prose or explanations.

                \(prefix)

                Completion:
                """
                let body: [String: Any] = [
                    "model": "gpt-4o-mini",
                    "messages": [["role": "user", "content": prompt]],
                    "temperature": 0.5,
                    "max_tokens": 64,
                    "n": 1,
                    "stop": [""]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    return sanitizeCompletion(content)
                }
            } catch {
                debugLog("[Completion][Fallback][OpenAI] request failed")
            }
        }
        // Try Gemini
        if !geminiAPIToken.isEmpty {
            do {
                let model = "gemini-1.5-flash-latest"
                let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
                guard let url = URL(string: endpoint) else { return "" }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(geminiAPIToken, forHTTPHeaderField: "x-goog-api-key")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let prompt = """
                Continue the following \(language) code snippet with a few lines or tokens of code only. Do not add prose or explanations.

                \(prefix)

                Completion:
                """
                let body: [String: Any] = [
                    "contents": [["parts": [["text": prompt]]]],
                    "generationConfig": ["temperature": 0.5, "maxOutputTokens": 64]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let first = candidates.first,
                   let content = first["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let text = parts.first?["text"] as? String {
                    return sanitizeCompletion(text)
                }
            } catch {
                debugLog("[Completion][Fallback][Gemini] request failed")
            }
        }
        // Try Anthropic
        if !anthropicAPIToken.isEmpty {
            do {
                let url = URL(string: "https://api.anthropic.com/v1/messages")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(anthropicAPIToken, forHTTPHeaderField: "x-api-key")
                request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let prompt = """
                Continue the following \(language) code snippet with a few lines or tokens of code only. Do not add prose or explanations.

                \(prefix)

                Completion:
                """
                let body: [String: Any] = [
                    "model": "claude-3-5-haiku-latest",
                    "max_tokens": 64,
                    "temperature": 0.5,
                    "messages": [["role": "user", "content": prompt]]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let contentArr = json["content"] as? [[String: Any]],
                   let first = contentArr.first,
                   let text = first["text"] as? String {
                    return sanitizeCompletion(text)
                }
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? [String: Any],
                   let contentArr = message["content"] as? [[String: Any]],
                   let first = contentArr.first,
                   let text = first["text"] as? String {
                    return sanitizeCompletion(text)
                }
            } catch {
                debugLog("[Completion][Fallback][Anthropic] request failed")
            }
        }
        return ""
    }

    private func appleModelCompletion(prefix: String, language: String) async -> String {
        let client = AppleIntelligenceAIClient()
        var aggregated = ""
        var firstChunk: String?
        for await chunk in client.streamSuggestions(prompt: "Continue the following \(language) code snippet with a few lines or tokens of code only. Do not add prose or explanations.\n\n\(prefix)\n\nCompletion:") {
            if firstChunk == nil, !chunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                firstChunk = chunk
                break
            } else {
                aggregated += chunk
            }
        }
        let candidate = sanitizeCompletion((firstChunk ?? aggregated))
        await MainActor.run { lastProviderUsed = "Apple" }
        return candidate
    }

    private func generateModelCompletion(prefix: String, language: String) async -> String {
        switch selectedModel {
        case .appleIntelligence:
            return await appleModelCompletion(prefix: prefix, language: language)
        case .grok:
            if grokAPIToken.isEmpty {
                let res = await appleModelCompletion(prefix: prefix, language: language)
                await MainActor.run { lastProviderUsed = "Grok (fallback to Apple)" }
                return res
            }
            do {
                let url = URL(string: "https://api.x.ai/v1/chat/completions")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(grokAPIToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let prompt = """
                Continue the following \(language) code snippet with a few lines or tokens of code only. Do not add prose or explanations.

                \(prefix)

                Completion:
                """
                let body: [String: Any] = [
                    "model": "grok-2-latest",
                    "messages": [["role": "user", "content": prompt]],
                    "temperature": 0.5,
                    "max_tokens": 64,
                    "n": 1,
                    "stop": [""]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    await MainActor.run { lastProviderUsed = "Grok" }
                    return sanitizeCompletion(content)
                }
                // If no content, fallback to Apple
                let res = await appleModelCompletion(prefix: prefix, language: language)
                await MainActor.run { lastProviderUsed = "Grok (fallback to Apple)" }
                return res
            } catch {
                debugLog("[Completion][Grok] request failed")
                let res = await appleModelCompletion(prefix: prefix, language: language)
                await MainActor.run { lastProviderUsed = "Grok (fallback to Apple)" }
                return res
            }
        case .openAI:
            if openAIAPIToken.isEmpty {
                let res = await appleModelCompletion(prefix: prefix, language: language)
                await MainActor.run { lastProviderUsed = "OpenAI (fallback to Apple)" }
                return res
            }
            do {
                let url = URL(string: "https://api.openai.com/v1/chat/completions")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(openAIAPIToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let prompt = """
                Continue the following \(language) code snippet with a few lines or tokens of code only. Do not add prose or explanations.

                \(prefix)

                Completion:
                """
                let body: [String: Any] = [
                    "model": "gpt-4o-mini",
                    "messages": [["role": "user", "content": prompt]],
                    "temperature": 0.5,
                    "max_tokens": 64,
                    "n": 1,
                    "stop": [""]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    await MainActor.run { lastProviderUsed = "OpenAI" }
                    return sanitizeCompletion(content)
                }
                let res = await appleModelCompletion(prefix: prefix, language: language)
                await MainActor.run { lastProviderUsed = "OpenAI (fallback to Apple)" }
                return res
            } catch {
                debugLog("[Completion][OpenAI] request failed")
                let res = await appleModelCompletion(prefix: prefix, language: language)
                await MainActor.run { lastProviderUsed = "OpenAI (fallback to Apple)" }
                return res
            }
        case .gemini:
            if geminiAPIToken.isEmpty {
                let res = await appleModelCompletion(prefix: prefix, language: language)
                await MainActor.run { lastProviderUsed = "Gemini (fallback to Apple)" }
                return res
            }
            do {
                let model = "gemini-1.5-flash-latest"
                let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
                guard let url = URL(string: endpoint) else {
                    let res = await appleModelCompletion(prefix: prefix, language: language)
                    await MainActor.run { lastProviderUsed = "Gemini (fallback to Apple)" }
                    return res
                }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(geminiAPIToken, forHTTPHeaderField: "x-goog-api-key")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let prompt = """
                Continue the following \(language) code snippet with a few lines or tokens of code only. Do not add prose or explanations.

                \(prefix)

                Completion:
                """
                let body: [String: Any] = [
                    "contents": [["parts": [["text": prompt]]]],
                    "generationConfig": ["temperature": 0.5, "maxOutputTokens": 64]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let first = candidates.first,
                   let content = first["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let text = parts.first?["text"] as? String {
                    await MainActor.run { lastProviderUsed = "Gemini" }
                    return sanitizeCompletion(text)
                }
                let res = await appleModelCompletion(prefix: prefix, language: language)
                await MainActor.run { lastProviderUsed = "Gemini (fallback to Apple)" }
                return res
            } catch {
                debugLog("[Completion][Gemini] request failed")
                let res = await appleModelCompletion(prefix: prefix, language: language)
                await MainActor.run { lastProviderUsed = "Gemini (fallback to Apple)" }
                return res
            }
        case .anthropic:
            if anthropicAPIToken.isEmpty {
                let res = await appleModelCompletion(prefix: prefix, language: language)
                await MainActor.run { lastProviderUsed = "Anthropic (fallback to Apple)" }
                return res
            }
            do {
                let url = URL(string: "https://api.anthropic.com/v1/messages")!
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue(anthropicAPIToken, forHTTPHeaderField: "x-api-key")
                request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let prompt = """
                Continue the following \(language) code snippet with a few lines or tokens of code only. Do not add prose or explanations.

                \(prefix)

                Completion:
                """
                let body: [String: Any] = [
                    "model": "claude-3-5-haiku-latest",
                    "max_tokens": 64,
                    "temperature": 0.5,
                    "messages": [["role": "user", "content": prompt]]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
                let (data, _) = try await URLSession.shared.data(for: request)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let contentArr = json["content"] as? [[String: Any]],
                   let first = contentArr.first,
                   let text = first["text"] as? String {
                    await MainActor.run { lastProviderUsed = "Anthropic" }
                    return sanitizeCompletion(text)
                }
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? [String: Any],
                   let contentArr = message["content"] as? [[String: Any]],
                   let first = contentArr.first,
                   let text = first["text"] as? String {
                    await MainActor.run { lastProviderUsed = "Anthropic" }
                    return sanitizeCompletion(text)
                }
                let res = await appleModelCompletion(prefix: prefix, language: language)
                await MainActor.run { lastProviderUsed = "Anthropic (fallback to Apple)" }
                return res
            } catch {
                debugLog("[Completion][Anthropic] request failed")
                let res = await appleModelCompletion(prefix: prefix, language: language)
                await MainActor.run { lastProviderUsed = "Anthropic (fallback to Apple)" }
                return res
            }
        }
    }

    private func sanitizeCompletion(_ raw: String) -> String {
        // Remove code fences and prose, keep first few lines of code only
        var result = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove opening and closing code fences if present
        while result.hasPrefix("```") {
            if let fenceEndIndex = result.firstIndex(of: "\n") {
                result = String(result[fenceEndIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                break
            }
        }
        if let closingFenceRange = result.range(of: "```") {
            result = String(result[..<closingFenceRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Take only up to 2 lines to avoid big insertions
        let lines = result.components(separatedBy: .newlines)
        if lines.count > 2 {
            result = lines.prefix(2).joined(separator: "\n")
        }

        return result
    }

    private func debugLog(_ message: String) {
#if DEBUG
        print(message)
#endif
    }

#if os(macOS)
    private func matchesCurrentWindow(_ notif: Notification) -> Bool {
        guard let target = notif.userInfo?[EditorCommandUserInfo.windowNumber] as? Int else {
            return true
        }
        guard let hostWindowNumber else { return false }
        return target == hostWindowNumber
    }

    private func updateWindowRegistration(_ window: NSWindow?) {
        let number = window?.windowNumber
        if hostWindowNumber != number, let old = hostWindowNumber {
            WindowViewModelRegistry.shared.unregister(windowNumber: old)
        }
        hostWindowNumber = number
        if let number {
            WindowViewModelRegistry.shared.register(viewModel, for: number)
        }
    }
#else
    private func matchesCurrentWindow(_ notif: Notification) -> Bool { true }
#endif

    private func withBaseEditorEvents<Content: View>(_ view: Content) -> some View {
        view
            .onReceive(NotificationCenter.default.publisher(for: .caretPositionDidChange)) { notif in
                if let line = notif.userInfo?["line"] as? Int, let col = notif.userInfo?["column"] as? Int {
                    caretStatus = "Ln \(line), Col \(col)"
                }
            }
        .onReceive(NotificationCenter.default.publisher(for: .pastedText)) { notif in
            if let pasted = notif.object as? String {
                let result = LanguageDetector.shared.detect(text: pasted, name: nil, fileURL: nil)
                currentLanguageBinding.wrappedValue = result.lang == "plain" ? "swift" : result.lang
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .droppedFileURL)) { notif in
            guard let fileURL = notif.object as? URL else { return }
            if let preferred = LanguageDetector.shared.preferredLanguage(for: fileURL) {
                currentLanguageBinding.wrappedValue = preferred
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .droppedFileLoadStarted)) { notif in
            droppedFileLoadInProgress = true
            droppedFileProgressDeterminate = (notif.userInfo?["isDeterminate"] as? Bool) ?? true
            droppedFileLoadProgress = 0
            droppedFileLoadLabel = "Reading file"
            largeFileModeEnabled = (notif.userInfo?["largeFileMode"] as? Bool) ?? false
        }
        .onReceive(NotificationCenter.default.publisher(for: .droppedFileLoadProgress)) { notif in
            // Recover even if "started" was missed.
            droppedFileLoadInProgress = true
            let fraction: Double = {
                if let v = notif.userInfo?["fraction"] as? Double { return v }
                if let v = notif.userInfo?["fraction"] as? NSNumber { return v.doubleValue }
                if let v = notif.userInfo?["fraction"] as? Float { return Double(v) }
                if let v = notif.userInfo?["fraction"] as? CGFloat { return Double(v) }
                return droppedFileLoadProgress
            }()
            droppedFileLoadProgress = min(max(fraction, 0), 1)
            if (notif.userInfo?["largeFileMode"] as? Bool) == true {
                largeFileModeEnabled = true
            }
            if let name = notif.userInfo?["fileName"] as? String, !name.isEmpty {
                droppedFileLoadLabel = name
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .droppedFileLoadFinished)) { notif in
            let success = (notif.userInfo?["success"] as? Bool) ?? true
            droppedFileLoadProgress = success ? 1 : 0
            if (notif.userInfo?["largeFileMode"] as? Bool) == true {
                largeFileModeEnabled = true
            }
            if !success, let message = notif.userInfo?["message"] as? String, !message.isEmpty {
                findStatusMessage = "Drop failed: \(message)"
                droppedFileLoadLabel = "Import failed"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (success ? 0.35 : 2.5)) {
                droppedFileLoadInProgress = false
            }
        }
    }

    private func withCommandEvents<Content: View>(_ view: Content) -> some View {
        view
            .onReceive(NotificationCenter.default.publisher(for: .clearEditorRequested)) { notif in
                guard matchesCurrentWindow(notif) else { return }
                clearEditorContent()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleCodeCompletionRequested)) { notif in
                guard matchesCurrentWindow(notif) else { return }
                isAutoCompletionEnabled.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .showFindReplaceRequested)) { notif in
                guard matchesCurrentWindow(notif) else { return }
                showFindReplace = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .showQuickSwitcherRequested)) { notif in
                guard matchesCurrentWindow(notif) else { return }
                quickSwitcherQuery = ""
                showQuickSwitcher = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .showWelcomeTourRequested)) { notif in
                guard matchesCurrentWindow(notif) else { return }
                showWelcomeTour = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleProjectStructureSidebarRequested)) { notif in
                guard matchesCurrentWindow(notif) else { return }
                showProjectStructureSidebar.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleVimModeRequested)) { notif in
                guard matchesCurrentWindow(notif) else { return }
                vimModeEnabled.toggle()
                UserDefaults.standard.set(vimModeEnabled, forKey: "EditorVimModeEnabled")
                UserDefaults.standard.set(vimModeEnabled, forKey: "EditorVimInterceptionEnabled")
                vimInsertMode = !vimModeEnabled
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleSidebarRequested)) { notif in
                guard matchesCurrentWindow(notif) else { return }
                toggleSidebarFromToolbar()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleBrainDumpModeRequested)) { notif in
                guard matchesCurrentWindow(notif) else { return }
                viewModel.isBrainDumpMode.toggle()
                UserDefaults.standard.set(viewModel.isBrainDumpMode, forKey: "BrainDumpModeEnabled")
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleLineWrapRequested)) { notif in
                guard matchesCurrentWindow(notif) else { return }
                viewModel.isLineWrapEnabled.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleTranslucencyRequested)) { notif in
                guard matchesCurrentWindow(notif) else { return }
                if let enabled = notif.object as? Bool {
                    enableTranslucentWindow = enabled
                    UserDefaults.standard.set(enabled, forKey: "EnableTranslucentWindow")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .vimModeStateDidChange)) { notif in
                if let isInsert = notif.userInfo?["insertMode"] as? Bool {
                    vimInsertMode = isInsert
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showAPISettingsRequested)) { notif in
                guard matchesCurrentWindow(notif) else { return }
                showAISelectorPopover = false
                showAPISettings = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .selectAIModelRequested)) { notif in
                guard matchesCurrentWindow(notif) else { return }
                guard let modelRawValue = notif.object as? String,
                      let model = AIModel(rawValue: modelRawValue) else { return }
                selectedModel = model
            }
    }

    private func withTypingEvents<Content: View>(_ view: Content) -> some View {
#if os(macOS)
        view
            .onReceive(NotificationCenter.default.publisher(for: NSText.didChangeNotification)) { _ in
                guard isAutoCompletionEnabled && !viewModel.isBrainDumpMode else { return }
                lastCompletionWorkItem?.cancel()
                let work = DispatchWorkItem {
                    performInlineCompletion()
                }
                lastCompletionWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
            }
#else
        view
#endif
    }

    @ViewBuilder
    private var platformLayout: some View {
#if os(macOS)
        Group {
            if shouldUseSplitView {
                NavigationSplitView {
                    sidebarView
                } detail: {
                    editorView
                }
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 600)
                .background(enableTranslucentWindow ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.clear))
            } else {
                editorView
            }
        }
        .frame(minWidth: 600, minHeight: 400)
#else
        NavigationStack {
            Group {
                if shouldUseSplitView {
                    NavigationSplitView {
                        sidebarView
                    } detail: {
                        editorView
                    }
                    .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 600)
                    .background(enableTranslucentWindow ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.clear))
                } else {
                    editorView
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
#endif
    }

    // Layout: NavigationSplitView with optional sidebar and the primary code editor.
    var body: some View {
        platformLayout
        .alert("AI Error", isPresented: showGrokError) {
            Button("OK") { }
        } message: {
            Text(grokErrorMessage.wrappedValue)
        }
        .navigationTitle("Neon Vision Editor")
        .sheet(isPresented: $showAPISettings) {
            APISupportSettingsView(
                grokAPIToken: $grokAPIToken,
                openAIAPIToken: $openAIAPIToken,
                geminiAPIToken: $geminiAPIToken,
                anthropicAPIToken: $anthropicAPIToken
            )
        }
        .sheet(isPresented: $showFindReplace) {
            FindReplacePanel(
                findQuery: $findQuery,
                replaceQuery: $replaceQuery,
                useRegex: $findUsesRegex,
                caseSensitive: $findCaseSensitive,
                statusMessage: $findStatusMessage,
                onFindNext: { findNext() },
                onReplace: { replaceSelection() },
                onReplaceAll: { replaceAll() }
            )
#if canImport(UIKit)
                .frame(maxWidth: 420)
#else
                .frame(width: 420)
#endif
        }
#if os(iOS)
        .sheet(isPresented: $showCompactSidebarSheet) {
            NavigationStack {
                SidebarView(content: currentContent, language: currentLanguage)
                    .navigationTitle("Sidebar")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showCompactSidebarSheet = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
#endif
        .sheet(isPresented: $showQuickSwitcher) {
            QuickFileSwitcherPanel(
                query: $quickSwitcherQuery,
                items: quickSwitcherItems,
                onSelect: { selectQuickSwitcherItem($0) }
            )
        }
        .sheet(isPresented: $showWelcomeTour) {
            WelcomeTourView {
                hasSeenWelcomeTourV1 = true
                showWelcomeTour = false
            }
        }
        .confirmationDialog("Save changes before closing?", isPresented: $showUnsavedCloseDialog, titleVisibility: .visible) {
            Button("Save") { saveAndClosePendingTab() }
            Button("Don't Save", role: .destructive) { discardAndClosePendingTab() }
            Button("Cancel", role: .cancel) {
                pendingCloseTabID = nil
            }
        } message: {
            if let pendingCloseTabID,
               let tab = viewModel.tabs.first(where: { $0.id == pendingCloseTabID }) {
                Text("\"\(tab.name)\" has unsaved changes.")
            } else {
                Text("This file has unsaved changes.")
            }
        }
#if canImport(UIKit)
        .fileImporter(
            isPresented: $showIOSFileImporter,
            allowedContentTypes: [.text, .plainText, .sourceCode, .json, .xml, .yaml],
            allowsMultipleSelection: false
        ) { result in
            handleIOSImportResult(result)
        }
        .fileExporter(
            isPresented: $showIOSFileExporter,
            document: iosExportDocument,
            contentType: .plainText,
            defaultFilename: iosExportFilename
        ) { result in
            handleIOSExportResult(result)
        }
#endif
        .onAppear {
            // Start with sidebar collapsed by default
            viewModel.showSidebar = false
            showProjectStructureSidebar = false

            // Restore Brain Dump mode from defaults
            if UserDefaults.standard.object(forKey: "BrainDumpModeEnabled") != nil {
                viewModel.isBrainDumpMode = UserDefaults.standard.bool(forKey: "BrainDumpModeEnabled")
            }

            applyWindowTranslucency(enableTranslucentWindow)
            if !hasSeenWelcomeTourV1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showWelcomeTour = true
                }
            }
        }
#if os(macOS)
        .background(
            WindowAccessor { window in
                updateWindowRegistration(window)
            }
            .frame(width: 0, height: 0)
        )
        .onDisappear {
            if let number = hostWindowNumber {
                WindowViewModelRegistry.shared.unregister(windowNumber: number)
            }
        }
#endif
    }

    private var shouldUseSplitView: Bool {
#if os(macOS)
        return viewModel.showSidebar && !viewModel.isBrainDumpMode
#else
        // Keep iPhone layout single-column to avoid horizontal clipping.
        return viewModel.showSidebar && !viewModel.isBrainDumpMode && horizontalSizeClass == .regular
#endif
    }

    // Sidebar shows a lightweight table of contents (TOC) derived from the current document.
    @ViewBuilder
    var sidebarView: some View {
        if viewModel.showSidebar && !viewModel.isBrainDumpMode {
            SidebarView(content: currentContent,
                        language: currentLanguage)
                .frame(minWidth: 200, idealWidth: 250, maxWidth: 600)
                .animation(.spring(), value: viewModel.showSidebar)
                .safeAreaInset(edge: .bottom) {
                    Divider()
                }
                .background(enableTranslucentWindow ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.clear))
        } else {
            EmptyView()
        }
    }

    // Bindings that resolve to the active tab (if present) or fallback single-document state.
    var currentContentBinding: Binding<String> {
        if let tab = viewModel.selectedTab {
            return Binding(
                get: { tab.content },
                set: { newValue in viewModel.updateTabContent(tab: tab, content: newValue) }
            )
        } else {
            return $singleContent
        }
    }

    var currentLanguageBinding: Binding<String> {
        if let selectedID = viewModel.selectedTabID, let idx = viewModel.tabs.firstIndex(where: { $0.id == selectedID }) {
            return Binding(
                get: { viewModel.tabs[idx].language },
                set: { newValue in viewModel.tabs[idx].language = newValue }
            )
        } else {
            return $singleLanguage
        }
    }

    var currentContent: String { currentContentBinding.wrappedValue }
    var currentLanguage: String { currentLanguageBinding.wrappedValue }

    /// Detects language using Apple Foundation Models when available, with a heuristic fallback.
    /// Returns a supported language string used by syntax highlighting and the language picker.
    private func detectLanguageWithAppleIntelligence(_ text: String) async -> String {
        // Supported languages in our picker
        let supported = ["swift", "python", "javascript", "typescript", "php", "java", "kotlin", "go", "ruby", "rust", "sql", "html", "css", "cpp", "objective-c", "csharp", "json", "xml", "yaml", "toml", "csv", "ini", "vim", "log", "ipynb", "markdown", "bash", "zsh", "powershell", "standard", "plain"]

        #if USE_FOUNDATION_MODELS
        // Attempt a lightweight model-based detection via AppleIntelligenceAIClient if available
        do {
            let client = AppleIntelligenceAIClient()
            var response = ""
            for await chunk in client.streamSuggestions(prompt: "Detect the programming or markup language of the following snippet and answer with one of: \(supported.joined(separator: ", ")). If none match, reply with 'swift'.\n\nSnippet:\n\n\(text)\n\nAnswer:") {
                response += chunk
            }
            let detectedRaw = response.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
            if let match = supported.first(where: { detectedRaw.contains($0) }) {
                return match
            }
        }
        #endif

        // Heuristic fallback
        let lower = text.lowercased()
        // Normalize common C# indicators to "csharp" to ensure the picker has a matching tag
        if lower.contains("c#") || lower.contains("c sharp") || lower.range(of: #"\bcs\b"#, options: .regularExpression) != nil || lower.contains(".cs") {
            return "csharp"
        }
        if lower.contains("<?php") || lower.contains("<?=") || lower.contains("$this->") || lower.contains("$_get") || lower.contains("$_post") || lower.contains("$_server") {
            return "php"
        }
        if text.contains(",") && text.contains("\n") {
            let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
            if lines.count >= 2 {
                let commaCounts = lines.prefix(6).map { line in line.filter { $0 == "," }.count }
                if let firstCount = commaCounts.first, firstCount > 0 && commaCounts.dropFirst().allSatisfy({ $0 == firstCount || abs($0 - firstCount) <= 1 }) {
                    return "csv"
                }
            }
        }
        // C# strong heuristic
        if lower.contains("using system") || lower.contains("namespace ") || lower.contains("public class") || lower.contains("public static void main") || lower.contains("static void main") || lower.contains("console.writeline") || lower.contains("console.readline") || lower.contains("class program") || lower.contains("get; set;") || lower.contains("list<") || lower.contains("dictionary<") || lower.contains("ienumerable<") || lower.range(of: #"\[[A-Za-z_][A-Za-z0-9_]*\]"#, options: .regularExpression) != nil {
            return "csharp"
        }
        if lower.contains("import swift") || lower.contains("struct ") || lower.contains("func ") {
            return "swift"
        }
        if lower.contains("def ") || (lower.contains("class ") && lower.contains(":")) {
            return "python"
        }
        if lower.contains("function ") || lower.contains("const ") || lower.contains("let ") || lower.contains("=>") {
            return "javascript"
        }
        // XML
        if lower.contains("<?xml") || (lower.contains("</") && lower.contains(">")) {
            return "xml"
        }
        // YAML
        if lower.contains(": ") && (lower.contains("- ") || lower.contains("\n  ")) && !lower.contains(";") {
            return "yaml"
        }
        // TOML / INI
        if lower.range(of: #"^\[[^\]]+\]"#, options: [.regularExpression, .anchored]) != nil || (lower.contains("=") && lower.contains("\n[")) {
            return lower.contains("toml") ? "toml" : "ini"
        }
        // SQL
        if lower.range(of: #"\b(select|insert|update|delete|create\s+table|from|where|join)\b"#, options: .regularExpression) != nil {
            return "sql"
        }
        // Go
        if lower.contains("package ") && lower.contains("func ") {
            return "go"
        }
        // Java
        if lower.contains("public class") || lower.contains("public static void main") {
            return "java"
        }
        // Kotlin
        if (lower.contains("fun ") || lower.contains("val ")) || (lower.contains("var ") && lower.contains(":")) {
            return "kotlin"
        }
        // TypeScript
        if lower.contains("interface ") || (lower.contains("type ") && lower.contains(":")) || lower.contains(": string") {
            return "typescript"
        }
        // Ruby
        if lower.contains("def ") || (lower.contains("end") && lower.contains("class ")) {
            return "ruby"
        }
        // Rust
        if lower.contains("fn ") || lower.contains("let mut ") || lower.contains("pub struct") {
            return "rust"
        }
        // Objective-C
        if lower.contains("@interface") || lower.contains("@implementation") || lower.contains("#import ") {
            return "objective-c"
        }
        // INI
        if lower.range(of: #"^;.*$"#, options: .regularExpression) != nil || lower.range(of: #"^\w+\s*=\s*.*$"#, options: .regularExpression) != nil {
            return "ini"
        }
        if lower.contains("<html") || lower.contains("<div") || lower.contains("</") {
            return "html"
        }
        // Stricter C-family detection to avoid misclassifying C#
        if lower.contains("#include") || lower.range(of: #"^\s*(int|void)\s+main\s*\("#, options: .regularExpression) != nil {
            return "cpp"
        }
        if lower.contains("class ") && (lower.contains("::") || lower.contains("template<")) {
            return "cpp"
        }
        if lower.contains(";") && lower.contains(":") && lower.contains("{") && lower.contains("}") && lower.contains("color:") {
            return "css"
        }
        // Shell detection (bash/zsh)
        if lower.contains("#!/bin/bash") || lower.contains("#!/usr/bin/env bash") || lower.contains("declare -a") || lower.contains("[[ ") || lower.contains(" ]] ") || lower.contains("$(") {
            return "bash"
        }
        if lower.contains("#!/bin/zsh") || lower.contains("#!/usr/bin/env zsh") || lower.contains("typeset ") || lower.contains("autoload -Uz") || lower.contains("setopt ") {
            return "zsh"
        }
        // Generic POSIX sh fallback
        if lower.contains("#!/bin/sh") || lower.contains("#!/usr/bin/env sh") || lower.contains(" fi") || lower.contains(" do") || lower.contains(" done") || lower.contains(" esac") {
            return "bash"
        }
        // PowerShell detection
        if lower.contains("write-host") || lower.contains("param(") || lower.contains("$psversiontable") || lower.range(of: #"\b(Get|Set|New|Remove|Add|Clear|Write)-[A-Za-z]+\b"#, options: .regularExpression) != nil {
            return "powershell"
        }
        return "standard"
    }

    // MARK: Main editor stack: hosts the NSTextView-backed editor, status line, and toolbar.
    var editorView: some View {
        let content = HStack(spacing: 0) {
            VStack(spacing: 0) {
                if !viewModel.isBrainDumpMode {
                    tabBarView
                }

                // Single editor (no TabView)
                CustomTextEditor(
                    text: currentContentBinding,
                    language: currentLanguage,
                    colorScheme: colorScheme,
                    fontSize: editorFontSize,
                    isLineWrapEnabled: $viewModel.isLineWrapEnabled,
                    isLargeFileMode: largeFileModeEnabled,
                    translucentBackgroundEnabled: enableTranslucentWindow
                )
                .id(currentLanguage)
                .frame(maxWidth: viewModel.isBrainDumpMode ? 800 : .infinity)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, viewModel.isBrainDumpMode ? 100 : 0)
                .padding(.vertical, viewModel.isBrainDumpMode ? 40 : 0)
                .background(
                    Group {
                        if enableTranslucentWindow {
                            Color.clear.background(.ultraThinMaterial)
                        } else {
                            Color.clear
                        }
                    }
                )

                if !viewModel.isBrainDumpMode {
                    wordCountView
                }
            }

            if showProjectStructureSidebar && !viewModel.isBrainDumpMode {
                Divider()
                ProjectStructureSidebarView(
                    rootFolderURL: projectRootFolderURL,
                    nodes: projectTreeNodes,
                    selectedFileURL: viewModel.selectedTab?.fileURL,
                    translucentBackgroundEnabled: enableTranslucentWindow,
                    onOpenFile: { openFileFromToolbar() },
                    onOpenFolder: { openProjectFolder() },
                    onOpenProjectFile: { openProjectFile(url: $0) },
                    onRefreshTree: { refreshProjectTree() }
                )
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 340)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

        let withEvents = withTypingEvents(
            withCommandEvents(
                withBaseEditorEvents(content)
            )
        )

        return withEvents
        .onChange(of: enableTranslucentWindow) { _, newValue in
            applyWindowTranslucency(newValue)
        }
        .toolbar {
            editorToolbarContent
        }
        .overlay(alignment: .topTrailing) {
            if droppedFileLoadInProgress {
                HStack(spacing: 8) {
                    if droppedFileProgressDeterminate {
                        ProgressView(value: droppedFileLoadProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 120)
                    } else {
                        ProgressView()
                            .frame(width: 16)
                    }
                    Text(droppedFileProgressDeterminate ? "\(droppedFileLoadLabel) \(importProgressPercentText)" : "\(droppedFileLoadLabel) Loading…")
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .padding(.top, viewModel.isBrainDumpMode ? 12 : 50)
                .padding(.trailing, 12)
            }
        }
#if os(macOS)
        .toolbarBackground(enableTranslucentWindow ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(nsColor: .windowBackgroundColor)), for: ToolbarPlacement.windowToolbar)
#else
        .toolbarBackground(enableTranslucentWindow ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(.systemBackground)), for: ToolbarPlacement.navigationBar)
#endif
    }

    // Status line: caret location + live word count from the view model.
    @ViewBuilder
    var wordCountView: some View {
        HStack(spacing: 10) {
            if droppedFileLoadInProgress {
                HStack(spacing: 8) {
                    if droppedFileProgressDeterminate {
                        ProgressView(value: droppedFileLoadProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 130)
                    } else {
                        ProgressView()
                            .frame(width: 18)
                    }
                    Text(droppedFileProgressDeterminate ? "\(droppedFileLoadLabel) \(importProgressPercentText)" : "\(droppedFileLoadLabel) Loading…")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .padding(.leading, 12)
            }

            if largeFileModeEnabled {
                Text("Large File Mode")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.secondary.opacity(0.16))
                    )
            }
            Spacer()
            Text(largeFileModeEnabled
                 ? "\(caretStatus)\(vimStatusSuffix)"
                 : "\(caretStatus) • Words: \(viewModel.wordCount(for: currentContent))\(vimStatusSuffix)")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
                .padding(.trailing, 16)
        }
        .background(enableTranslucentWindow ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.clear))
    }

    @ViewBuilder
    var tabBarView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(viewModel.tabs) { tab in
                    HStack(spacing: 6) {
                        Button {
                            viewModel.selectedTabID = tab.id
                        } label: {
                            Text(tab.name + (tab.isDirty ? " •" : ""))
                                .lineLimit(1)
                                .font(.system(size: 12, weight: viewModel.selectedTabID == tab.id ? .semibold : .regular))
                        }
                        .buttonStyle(.plain)

                        Button {
                            requestCloseTab(tab)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .buttonStyle(.plain)
                        .help("Close \(tab.name)")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(viewModel.selectedTabID == tab.id ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.10))
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
#if os(macOS)
        .background(enableTranslucentWindow ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(nsColor: .windowBackgroundColor)))
#else
        .background(enableTranslucentWindow ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color(.systemBackground)))
#endif
    }

    private var vimStatusSuffix: String {
#if os(macOS)
        guard vimModeEnabled else { return " • Vim: OFF" }
        return vimInsertMode ? " • Vim: INSERT" : " • Vim: NORMAL"
#else
        return ""
#endif
    }

    private var importProgressPercentText: String {
        let clamped = min(max(droppedFileLoadProgress, 0), 1)
        if clamped > 0, clamped < 0.01 { return "1%" }
        return "\(Int(clamped * 100))%"
    }

    private var quickSwitcherItems: [QuickFileSwitcherPanel.Item] {
        var items: [QuickFileSwitcherPanel.Item] = []
        let fileURLSet = Set(viewModel.tabs.compactMap { $0.fileURL?.standardizedFileURL.path })

        for tab in viewModel.tabs {
            let subtitle = tab.fileURL?.path ?? "Open tab"
            items.append(
                QuickFileSwitcherPanel.Item(
                    id: "tab:\(tab.id.uuidString)",
                    title: tab.name,
                    subtitle: subtitle
                )
            )
        }

        for url in projectFileURLs(from: projectTreeNodes) {
            let standardized = url.standardizedFileURL.path
            if fileURLSet.contains(standardized) { continue }
            items.append(
                QuickFileSwitcherPanel.Item(
                    id: "file:\(standardized)",
                    title: url.lastPathComponent,
                    subtitle: standardized
                )
            )
        }

        let query = quickSwitcherQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return Array(items.prefix(300)) }
        return Array(
            items.filter {
                $0.title.lowercased().contains(query) || $0.subtitle.lowercased().contains(query)
            }
            .prefix(300)
        )
    }

    private func selectQuickSwitcherItem(_ item: QuickFileSwitcherPanel.Item) {
        if item.id.hasPrefix("tab:") {
            let raw = String(item.id.dropFirst(4))
            if let id = UUID(uuidString: raw) {
                viewModel.selectedTabID = id
            }
            return
        }
        if item.id.hasPrefix("file:") {
            let path = String(item.id.dropFirst(5))
            openProjectFile(url: URL(fileURLWithPath: path))
        }
    }

}
