import SwiftUI
import Foundation
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct PlainTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .text, .sourceCode] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let decoded = String(data: data, encoding: .utf8) {
            text = decoded
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

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
                            SecureTokenStore.setToken(new, for: .grok)
                        }
                }
                LabeledContent("OpenAI") {
                    SecureField("sk-…", text: $openAIAPIToken)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .onChange(of: openAIAPIToken) { _, new in
                            SecureTokenStore.setToken(new, for: .openAI)
                        }
                }
                LabeledContent("Gemini") {
                    SecureField("AIza…", text: $geminiAPIToken)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .onChange(of: geminiAPIToken) { _, new in
                            SecureTokenStore.setToken(new, for: .gemini)
                        }
                }
                LabeledContent("Anthropic") {
                    SecureField("sk-ant-…", text: $anthropicAPIToken)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .onChange(of: anthropicAPIToken) { _, new in
                            SecureTokenStore.setToken(new, for: .anthropic)
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

struct QuickFileSwitcherPanel: View {
    struct Item: Identifiable {
        let id: String
        let title: String
        let subtitle: String
    }

    @Binding var query: String
    let items: [Item]
    let onSelect: (Item) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Open")
                .font(.headline)
            TextField("Search files and tabs", text: $query)
                .textFieldStyle(.roundedBorder)

            List(items) { item in
                Button {
                    onSelect(item)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .lineLimit(1)
                        Text(item.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)

            HStack {
                Text("\(items.count) results")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Close") { dismiss() }
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 380)
    }
}

struct WelcomeTourView: View {
    @Environment(\.colorScheme) private var colorScheme

    struct TourPage: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let bullets: [String]
        let iconName: String
        let colors: [Color]
    }

    let onFinish: () -> Void
    @State private var selectedIndex: Int = 0

    private let pages: [TourPage] = [
        TourPage(
            title: "A Fast, Focused Editor",
            subtitle: "Built for quick edits and flow.",
            bullets: [
                "Tabbed editing with per-file language support",
                "Automatic syntax highlighting for many formats",
                "Word count, caret status, and complete toolbar options"
            ],
            iconName: "doc.text.magnifyingglass",
            colors: [Color(red: 0.96, green: 0.48, blue: 0.28), Color(red: 0.99, green: 0.78, blue: 0.35)]
        ),
        TourPage(
            title: "Smart Assistance",
            subtitle: "Use local or cloud AI models when you want.",
            bullets: [
                "Apple Intelligence integration (when available)",
                "Optional Grok, OpenAI, Gemini, and Anthropic providers",
                "AI providers are used for simple code completion and suggestions",
                "API keys stored securely in Keychain"
            ],
            iconName: "sparkles",
            colors: [Color(red: 0.20, green: 0.55, blue: 0.95), Color(red: 0.21, green: 0.86, blue: 0.78)]
        ),
        TourPage(
            title: "Power User Features",
            subtitle: "Navigate large projects quickly.",
            bullets: [
                "Quick Open with Cmd+P",
                "All sidebars: document outline and project structure",
                "Find & Replace and full editor/view toolbar actions",
                "Lightweight Vim-style workflow support on macOS"
            ],
            iconName: "bolt.circle",
            colors: [Color(red: 0.22, green: 0.72, blue: 0.43), Color(red: 0.08, green: 0.42, blue: 0.73)]
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedIndex) {
                ForEach(Array(pages.enumerated()), id: \.offset) { idx, page in
                    tourCard(for: page)
                        .tag(idx)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                }
            }
#if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
#else
            .tabViewStyle(.automatic)
#endif

            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { idx in
                    Capsule()
                        .fill(idx == selectedIndex ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: idx == selectedIndex ? 14 : 6, height: 5)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 10)

            HStack {
                Button("Skip") { onFinish() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                Spacer()

                if selectedIndex < pages.count - 1 {
                    Button("Next") {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedIndex += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") { onFinish() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.09, green: 0.10, blue: 0.14), Color(red: 0.13, green: 0.16, blue: 0.22)]
                    : [Color(red: 0.98, green: 0.99, blue: 1.00), Color(red: 0.93, green: 0.96, blue: 0.99)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
#if os(macOS)
        .frame(minWidth: 840, minHeight: 580)
#else
        .presentationDetents([.large])
#endif
    }

    @ViewBuilder
    private func tourCard(for page: TourPage) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer(minLength: 0)

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: page.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 56, height: 56)
                    Image(systemName: page.iconName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(page.title)
                        .font(.system(size: 28, weight: .bold))
                    Text(page.subtitle)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(page.bullets, id: \.self) { bullet in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(Color.accentColor.opacity(0.85))
                        .frame(width: 7, height: 7)
                        .padding(.top, 7)
                    Text(bullet)
                        .font(.system(size: 15))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(colorScheme == .dark ? .regularMaterial : .ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            colorScheme == .dark ? Color.white.opacity(0.16) : Color.white.opacity(0.55),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08),
                    radius: 18,
                    x: 0,
                    y: 8
                )
        )
    }
}

extension Notification.Name {
    static let moveCursorToLine = Notification.Name("moveCursorToLine")
    static let caretPositionDidChange = Notification.Name("caretPositionDidChange")
    static let pastedText = Notification.Name("pastedText")
    static let toggleTranslucencyRequested = Notification.Name("toggleTranslucencyRequested")
    static let clearEditorRequested = Notification.Name("clearEditorRequested")
    static let toggleCodeCompletionRequested = Notification.Name("toggleCodeCompletionRequested")
    static let showFindReplaceRequested = Notification.Name("showFindReplaceRequested")
    static let toggleProjectStructureSidebarRequested = Notification.Name("toggleProjectStructureSidebarRequested")
    static let showAPISettingsRequested = Notification.Name("showAPISettingsRequested")
    static let selectAIModelRequested = Notification.Name("selectAIModelRequested")
    static let showQuickSwitcherRequested = Notification.Name("showQuickSwitcherRequested")
    static let showWelcomeTourRequested = Notification.Name("showWelcomeTourRequested")
    static let toggleVimModeRequested = Notification.Name("toggleVimModeRequested")
    static let vimModeStateDidChange = Notification.Name("vimModeStateDidChange")
    static let droppedFileURL = Notification.Name("droppedFileURL")
    static let droppedFileLoadStarted = Notification.Name("droppedFileLoadStarted")
    static let droppedFileLoadProgress = Notification.Name("droppedFileLoadProgress")
    static let droppedFileLoadFinished = Notification.Name("droppedFileLoadFinished")
    static let toggleSidebarRequested = Notification.Name("toggleSidebarRequested")
    static let toggleBrainDumpModeRequested = Notification.Name("toggleBrainDumpModeRequested")
    static let toggleLineWrapRequested = Notification.Name("toggleLineWrapRequested")
}

extension NSRange {
    func toOptional() -> NSRange? { self.location == NSNotFound ? nil : self }
}

enum EditorCommandUserInfo {
    static let windowNumber = "targetWindowNumber"
}

#if os(macOS)
private final class WeakEditorViewModelRef {
    weak var value: EditorViewModel?
    init(_ value: EditorViewModel) { self.value = value }
}

@MainActor
final class WindowViewModelRegistry {
    static let shared = WindowViewModelRegistry()
    private var storage: [Int: WeakEditorViewModelRef] = [:]

    private init() {}

    func register(_ viewModel: EditorViewModel, for windowNumber: Int) {
        storage[windowNumber] = WeakEditorViewModelRef(viewModel)
    }

    func unregister(windowNumber: Int) {
        storage.removeValue(forKey: windowNumber)
    }

    func viewModel(for windowNumber: Int?) -> EditorViewModel? {
        guard let windowNumber else { return nil }
        if let vm = storage[windowNumber]?.value {
            return vm
        }
        storage.removeValue(forKey: windowNumber)
        return nil
    }

    func activeViewModel() -> EditorViewModel? {
        viewModel(for: NSApp.keyWindow?.windowNumber ?? NSApp.mainWindow?.windowNumber)
    }
}

private final class WindowObserverView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}

struct WindowAccessor: NSViewRepresentable {
    let onWindowChange: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WindowObserverView(frame: .zero)
        view.onWindowChange = onWindowChange
        DispatchQueue.main.async {
            onWindowChange(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? WindowObserverView else { return }
        view.onWindowChange = onWindowChange
        DispatchQueue.main.async {
            onWindowChange(view.window)
        }
    }
}
#endif

