import SwiftUI
import AppKit
import Foundation

struct APISupportSettingsView: View {
    @Binding var grokAPIToken: String
    @Binding var openAIAPIToken: String
    @Binding var geminiAPIToken: String
    @Binding var anthropicAPIToken: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Provider API Keys").font(.headline)
            Group {
                LabeledContent("Grok") {
                    SecureField("sk-…", text: $grokAPIToken)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .onChange(of: grokAPIToken) { _, new in
                            UserDefaults.standard.set(new, forKey: "GrokAPIToken")
                        }
                }
                LabeledContent("OpenAI") {
                    SecureField("sk-…", text: $openAIAPIToken)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .onChange(of: openAIAPIToken) { _, new in
                            UserDefaults.standard.set(new, forKey: "OpenAIAPIToken")
                        }
                }
                LabeledContent("Gemini") {
                    SecureField("AIza…", text: $geminiAPIToken)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .onChange(of: geminiAPIToken) { _, new in
                            UserDefaults.standard.set(new, forKey: "GeminiAPIToken")
                        }
                }
                LabeledContent("Anthropic") {
                    SecureField("sk-ant-…", text: $anthropicAPIToken)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .onChange(of: anthropicAPIToken) { _, new in
                            UserDefaults.standard.set(new, forKey: "AnthropicAPIToken")
                        }
                }
            }
            .labelStyle(.titleAndIcon)

            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
            }
        }
        .padding(20)
        .frame(minWidth: 460)
    }
}

struct FindReplacePanel: View {
    @Binding var findQuery: String
    @Binding var replaceQuery: String
    @Binding var useRegex: Bool
    @Binding var caseSensitive: Bool
    @Binding var statusMessage: String
    var onFindNext: () -> Void
    var onReplace: () -> Void
    var onReplaceAll: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Find & Replace").font(.headline)
            LabeledContent("Find") {
                TextField("Search text", text: $findQuery)
                    .textFieldStyle(.roundedBorder)
            }
            LabeledContent("Replace") {
                TextField("Replacement", text: $replaceQuery)
                    .textFieldStyle(.roundedBorder)
            }
            Toggle("Use Regex", isOn: $useRegex)
            Toggle("Case Sensitive", isOn: $caseSensitive)
            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack {
                Button("Find Next") { onFindNext() }
                Button("Replace") { onReplace() }.disabled(findQuery.isEmpty)
                Button("Replace All") { onReplaceAll() }.disabled(findQuery.isEmpty)
                Spacer()
                Button("Close") { dismiss() }
            }
        }
        .padding(16)
        .frame(minWidth: 380)
    }
}

extension Notification.Name {
    static let moveCursorToLine = Notification.Name("moveCursorToLine")
    static let caretPositionDidChange = Notification.Name("caretPositionDidChange")
    static let pastedText = Notification.Name("pastedText")
    static let toggleTranslucencyRequested = Notification.Name("toggleTranslucencyRequested")
}

extension NSRange {
    func toOptional() -> NSRange? { self.location == NSNotFound ? nil : self }
}

