import SwiftUI
#if os(macOS)
import AppKit
#endif

struct NeonSettingsView: View {
    let supportsOpenInTabs: Bool
    let supportsTranslucency: Bool
    @EnvironmentObject private var supportPurchaseManager: SupportPurchaseManager
    @AppStorage("SettingsOpenInTabs") private var openInTabs: String = "system"
    @AppStorage("SettingsEditorFontName") private var editorFontName: String = ""
    @AppStorage("SettingsEditorFontSize") private var editorFontSize: Double = 14
    @AppStorage("SettingsLineHeight") private var lineHeight: Double = 1.0
    @AppStorage("SettingsAppearance") private var appearance: String = "system"
    @AppStorage("EnableTranslucentWindow") private var translucentWindow: Bool = false

    @AppStorage("SettingsShowLineNumbers") private var showLineNumbers: Bool = true
    @AppStorage("SettingsHighlightCurrentLine") private var highlightCurrentLine: Bool = false
    @AppStorage("SettingsLineWrapEnabled") private var lineWrapEnabled: Bool = false
    @AppStorage("SettingsIndentStyle") private var indentStyle: String = "spaces"
    @AppStorage("SettingsIndentWidth") private var indentWidth: Int = 4
    @AppStorage("SettingsAutoIndent") private var autoIndent: Bool = true
    @AppStorage("SettingsAutoCloseBrackets") private var autoCloseBrackets: Bool = false
    @AppStorage("SettingsTrimTrailingWhitespace") private var trimTrailingWhitespace: Bool = false
    @AppStorage("SettingsTrimWhitespaceForSyntaxDetection") private var trimWhitespaceForSyntaxDetection: Bool = false

    @AppStorage("SettingsCompletionEnabled") private var completionEnabled: Bool = false
    @AppStorage("SettingsCompletionFromDocument") private var completionFromDocument: Bool = false
    @AppStorage("SettingsCompletionFromSyntax") private var completionFromSyntax: Bool = false
    @AppStorage("SettingsActiveTab") private var settingsActiveTab: String = "general"
    @AppStorage("SettingsTemplateLanguage") private var settingsTemplateLanguage: String = "swift"
#if os(macOS)
    @State private var fontPicker = FontPickerController()
#endif

    @State private var grokAPIToken: String = SecureTokenStore.token(for: .grok)
    @State private var openAIAPIToken: String = SecureTokenStore.token(for: .openAI)
    @State private var geminiAPIToken: String = SecureTokenStore.token(for: .gemini)
    @State private var anthropicAPIToken: String = SecureTokenStore.token(for: .anthropic)
    @State private var showSupportPurchaseDialog: Bool = false

    @AppStorage("SettingsThemeName") private var selectedTheme: String = "Neon Glow"
    @AppStorage("SettingsThemeTextColor") private var themeTextHex: String = "#EDEDED"
    @AppStorage("SettingsThemeBackgroundColor") private var themeBackgroundHex: String = "#0E1116"
    @AppStorage("SettingsThemeCursorColor") private var themeCursorHex: String = "#4EA4FF"
    @AppStorage("SettingsThemeSelectionColor") private var themeSelectionHex: String = "#2A3340"
    @AppStorage("SettingsThemeKeywordColor") private var themeKeywordHex: String = "#F5D90A"
    @AppStorage("SettingsThemeStringColor") private var themeStringHex: String = "#FF7AD9"
    @AppStorage("SettingsThemeNumberColor") private var themeNumberHex: String = "#FFB86C"
    @AppStorage("SettingsThemeCommentColor") private var themeCommentHex: String = "#7F8C98"
    
    private var inputFieldBackground: Color {
#if os(macOS)
        Color(nsColor: .windowBackgroundColor)
#else
        Color(.secondarySystemBackground)
#endif
    }

    private let themes: [String] = [
        "Neon Glow",
        "Arc",
        "Dusk",
        "Aurora",
        "Horizon",
        "Midnight",
        "Mono",
        "Paper",
        "Solar",
        "Pulse",
        "Mocha",
        "Custom"
    ]

    private let templateLanguages: [String] = [
        "swift", "python", "javascript", "typescript", "php", "java", "kotlin", "go", "ruby", "rust",
        "cobol", "dotenv", "proto", "graphql", "rst", "nginx", "sql", "html", "css", "c", "cpp",
        "csharp", "objective-c", "json", "xml", "yaml", "toml", "csv", "ini", "vim", "log", "ipynb",
        "markdown", "bash", "zsh", "powershell", "standard", "plain"
    ]

    init(
        supportsOpenInTabs: Bool = true,
        supportsTranslucency: Bool = true
    ) {
        self.supportsOpenInTabs = supportsOpenInTabs
        self.supportsTranslucency = supportsTranslucency
    }

    var body: some View {
        TabView(selection: $settingsActiveTab) {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag("general")
            editorTab
                .tabItem { Label("Editor", systemImage: "slider.horizontal.3") }
                .tag("editor")
            templateTab
                .tabItem { Label("Templates", systemImage: "doc.badge.plus") }
                .tag("templates")
            themeTab
                .tabItem { Label("Themes", systemImage: "paintpalette") }
                .tag("themes")
            aiTab
                .tabItem { Label("AI", systemImage: "brain.head.profile") }
                .tag("ai")
            supportTab
                .tabItem { Label("Support", systemImage: "heart") }
                .tag("support")
        }
        .frame(minWidth: 860, minHeight: 620)
        .onAppear {
            if settingsActiveTab == "code" {
                settingsActiveTab = "editor"
            }
            if supportPurchaseManager.supportProduct == nil {
                Task { await supportPurchaseManager.refreshStoreState() }
            }
#if os(macOS)
            fontPicker.onChange = { selected in
                editorFontName = selected.fontName
                editorFontSize = Double(selected.pointSize)
            }
#endif
        }
        .confirmationDialog("Support Neon Vision Editor", isPresented: $showSupportPurchaseDialog, titleVisibility: .visible) {
            Button("Support \(supportPurchaseManager.supportPriceLabel)") {
                Task { await supportPurchaseManager.purchaseSupport() }
            }
            Button("Restore Purchases") {
                Task { await supportPurchaseManager.restorePurchases() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Optional one-time purchase to support development. No features are locked behind this purchase.")
        }
        .alert(
            "App Store",
            isPresented: Binding(
                get: { supportPurchaseManager.statusMessage != nil },
                set: { if !$0 { supportPurchaseManager.statusMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(supportPurchaseManager.statusMessage ?? "")
        }
    }

    private var generalTab: some View {
        settingsContainer {
            GroupBox("Window") {
                VStack(alignment: .leading, spacing: 12) {
                    if supportsOpenInTabs {
                        HStack(alignment: .center, spacing: 12) {
                            Text("Open in Tabs")
                                .frame(width: 140, alignment: .leading)
                            Picker("", selection: $openInTabs) {
                                Text("Follow System").tag("system")
                                Text("Always").tag("always")
                                Text("Never").tag("never")
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    HStack(alignment: .center, spacing: 12) {
                        Text("Appearance")
                            .frame(width: 140, alignment: .leading)
                        Picker("", selection: $appearance) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(.segmented)
                    }

                    if supportsTranslucency {
                        Toggle("Translucent Window", isOn: $translucentWindow)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(12)
            }

            GroupBox("Editor Font") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        Text("Font Name")
                            .frame(width: 140, alignment: .leading)
                        TextField("Font Name", text: $editorFontName)
                            .textFieldStyle(.plain)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(inputFieldBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                            )
                            .cornerRadius(6)
                            .frame(width: 240)
#if os(macOS)
                        Button("Choose…") {
                            fontPicker.open(currentName: editorFontName, size: editorFontSize)
                        }
#endif
                        Stepper(value: $editorFontSize, in: 10...28, step: 1) {
                            Text("\(Int(editorFontSize)) pt")
                        }
                        .frame(maxWidth: 120)
                    }

                    HStack(alignment: .center, spacing: 12) {
                        Text("Line Height")
                            .frame(width: 140, alignment: .leading)
                        Slider(value: $lineHeight, in: 1.0...1.8, step: 0.05)
                            .frame(width: 240)
                        Text(String(format: "%.2fx", lineHeight))
                            .frame(width: 54, alignment: .trailing)
                    }
                }
                .padding(12)
            }
        }
    }

    private var editorTab: some View {
        settingsContainer(maxWidth: 760) {
            GroupBox("Editor") {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Display")
                            .font(.headline)
                        Toggle("Show Line Numbers", isOn: $showLineNumbers)
                        Toggle("Highlight Current Line", isOn: $highlightCurrentLine)
                        Toggle("Line Wrap", isOn: $lineWrapEnabled)
                        Text("Invisible character markers are disabled to avoid whitespace glyph artifacts.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Indentation")
                            .font(.headline)
                        Picker("Indent Style", selection: $indentStyle) {
                            Text("Spaces").tag("spaces")
                            Text("Tabs").tag("tabs")
                        }
                        .pickerStyle(.segmented)

                        Stepper(value: $indentWidth, in: 2...8, step: 1) {
                            Text("Indent Width: \(indentWidth)")
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Editing")
                            .font(.headline)
                        Toggle("Auto Indent", isOn: $autoIndent)
                        Toggle("Auto Close Brackets", isOn: $autoCloseBrackets)
                        Toggle("Trim Trailing Whitespace", isOn: $trimTrailingWhitespace)
                        Toggle("Trim Edges for Syntax Detection", isOn: $trimWhitespaceForSyntaxDetection)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Completion")
                            .font(.headline)
                        Toggle("Enable Completion", isOn: $completionEnabled)
                        Toggle("Include Words in Document", isOn: $completionFromDocument)
                        Toggle("Include Syntax Keywords", isOn: $completionFromSyntax)
                    }
                }
                .padding(12)
            }
        }
    }

    private var templateTab: some View {
        settingsContainer(maxWidth: 640) {
            GroupBox("Completion Template") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        Text("Language")
                            .frame(width: 140, alignment: .leading)
                        Picker("", selection: $settingsTemplateLanguage) {
                            ForEach(templateLanguages, id: \.self) { lang in
                                Text(languageLabel(for: lang)).tag(lang)
                            }
                        }
                        .frame(width: 220, alignment: .leading)
                        .pickerStyle(.menu)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                        )
                        .cornerRadius(8)
                    }

                    TextEditor(text: templateBinding(for: settingsTemplateLanguage))
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200, maxHeight: 320)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )

                    HStack(spacing: 12) {
                        Button("Reset to Default") {
                            UserDefaults.standard.removeObject(forKey: templateOverrideKey(for: settingsTemplateLanguage))
                        }
                        Button("Use Default Template") {
                            if let fallback = defaultTemplate(for: settingsTemplateLanguage) {
                                UserDefaults.standard.set(fallback, forKey: templateOverrideKey(for: settingsTemplateLanguage))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)
            }
        }
    }

    private var themeTab: some View {
        let isCustom = selectedTheme == "Custom"
        let palette = themePaletteColors(for: selectedTheme)
        return settingsContainer(maxWidth: 760) {
            HStack(spacing: 16) {
#if os(macOS)
                let listView = List(themes, id: \.self, selection: $selectedTheme) { theme in
                    Text(theme)
                        .listRowBackground(Color.clear)
                }
                .frame(minWidth: 200)
                .listStyle(.plain)
                .background(Color.clear)
                if #available(macOS 13.0, *) {
                    listView.scrollContentBackground(.hidden)
                } else {
                    listView
                }
#else
                let listView = List {
                    ForEach(themes, id: \.self) { theme in
                        HStack {
                            Text(theme)
                            Spacer()
                            if theme == selectedTheme {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTheme = theme
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .frame(minWidth: 200)
                .listStyle(.plain)
                .background(Color.clear)
                if #available(iOS 16.0, *) {
                    listView.scrollContentBackground(.hidden)
                } else {
                    listView
                }
#endif

                VStack(alignment: .leading, spacing: 16) {
                    Text("Theme Colors")
                        .font(.headline)

                    colorRow(title: "Text", color: isCustom ? hexBinding($themeTextHex, fallback: .white) : .constant(palette.text))
                        .disabled(!isCustom)
                    colorRow(title: "Background", color: isCustom ? hexBinding($themeBackgroundHex, fallback: .black) : .constant(palette.background))
                        .disabled(!isCustom)
                    colorRow(title: "Cursor", color: isCustom ? hexBinding($themeCursorHex, fallback: .blue) : .constant(palette.cursor))
                        .disabled(!isCustom)
                    colorRow(title: "Selection", color: isCustom ? hexBinding($themeSelectionHex, fallback: .gray) : .constant(palette.selection))
                        .disabled(!isCustom)

                    Divider()

                    Text("Syntax")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    colorRow(title: "Keywords", color: isCustom ? hexBinding($themeKeywordHex, fallback: .yellow) : .constant(palette.keyword))
                        .disabled(!isCustom)
                    colorRow(title: "Strings", color: isCustom ? hexBinding($themeStringHex, fallback: .pink) : .constant(palette.string))
                        .disabled(!isCustom)
                    colorRow(title: "Numbers", color: isCustom ? hexBinding($themeNumberHex, fallback: .orange) : .constant(palette.number))
                        .disabled(!isCustom)
                    colorRow(title: "Comments", color: isCustom ? hexBinding($themeCommentHex, fallback: .gray) : .constant(palette.comment))
                        .disabled(!isCustom)
                    colorRow(title: "Types", color: .constant(palette.type))
                        .disabled(true)
                    colorRow(title: "Builtins", color: .constant(palette.builtin))
                        .disabled(true)

                    Spacer()
                    Text(isCustom ? "Custom theme applies immediately." : "Select Custom to edit colors.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var aiTab: some View {
        settingsContainer(maxWidth: 520) {
            GroupBox("AI Provider API Keys") {
                VStack(alignment: .center, spacing: 12) {
                    aiKeyRow(title: "Grok", placeholder: "sk-…", value: $grokAPIToken, provider: .grok)
                    aiKeyRow(title: "OpenAI", placeholder: "sk-…", value: $openAIAPIToken, provider: .openAI)
                    aiKeyRow(title: "Gemini", placeholder: "AIza…", value: $geminiAPIToken, provider: .gemini)
                    aiKeyRow(title: "Anthropic", placeholder: "sk-ant-…", value: $anthropicAPIToken, provider: .anthropic)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(12)
            }
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var supportTab: some View {
        settingsContainer(maxWidth: 520) {
            GroupBox("Support Development") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("In-App Purchase is optional and only used to support the app.")
                        .foregroundStyle(.secondary)
                    if supportPurchaseManager.canUseInAppPurchases {
                        Text("Price: \(supportPurchaseManager.supportPriceLabel)")
                            .font(.headline)
                        if supportPurchaseManager.hasSupported {
                            Label("Thank you for your support.", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                        }
                        HStack(spacing: 12) {
                            Button(supportPurchaseManager.isPurchasing ? "Purchasing…" : "Support the App") {
                                showSupportPurchaseDialog = true
                            }
                            .disabled(supportPurchaseManager.isPurchasing || supportPurchaseManager.isLoadingProducts)

                            Button("Refresh Price") {
                                Task { await supportPurchaseManager.refreshProducts() }
                            }
                            .disabled(supportPurchaseManager.isLoadingProducts)
                        }
                    } else {
                        Text("Direct notarized builds are unaffected: all editor features stay fully available without any purchase.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text("Support purchase is available only in App Store/TestFlight builds.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if supportPurchaseManager.canBypassInCurrentBuild {
                        Divider()
                        Text("TestFlight/Sandbox: You can bypass purchase for testing.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Button("Bypass Purchase (Testing)") {
                                supportPurchaseManager.bypassForTesting()
                            }
                            Button("Clear Bypass") {
                                supportPurchaseManager.clearBypassForTesting()
                            }
                        }
                    }
                }
                .padding(12)
            }
        }
    }

    private func settingsContainer<Content: View>(maxWidth: CGFloat = 560, @ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .center, spacing: 20) {
                content()
            }
            .frame(maxWidth: maxWidth, alignment: .center)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 16)
            .padding(.horizontal, 24)
        }
        .background(.ultraThinMaterial)
    }

    private func colorRow(title: String, color: Binding<Color>) -> some View {
        HStack {
            Text(title)
                .frame(width: 120, alignment: .leading)
            ColorPicker("", selection: color)
                .labelsHidden()
            Spacer()
        }
    }

    private func aiKeyRow(title: String, placeholder: String, value: Binding<String>, provider: APITokenKey) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 120, alignment: .leading)
            SecureField(placeholder, text: value)
                .textFieldStyle(.plain)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(inputFieldBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                )
                .cornerRadius(6)
                .frame(width: 200)
                .onChange(of: value.wrappedValue) { _, new in
                    SecureTokenStore.setToken(new, for: provider)
                }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func languageLabel(for lang: String) -> String {
        switch lang {
        case "php": return "PHP"
        case "cobol": return "COBOL"
        case "dotenv": return "Dotenv"
        case "proto": return "Proto"
        case "graphql": return "GraphQL"
        case "rst": return "reStructuredText"
        case "nginx": return "Nginx"
        case "objective-c": return "Objective-C"
        case "csharp": return "C#"
        case "c": return "C"
        case "cpp": return "C++"
        case "json": return "JSON"
        case "xml": return "XML"
        case "yaml": return "YAML"
        case "toml": return "TOML"
        case "csv": return "CSV"
        case "ini": return "INI"
        case "sql": return "SQL"
        case "vim": return "Vim"
        case "log": return "Log"
        case "ipynb": return "Jupyter Notebook"
        case "html": return "HTML"
        case "css": return "CSS"
        case "standard": return "Standard"
        default: return lang.capitalized
        }
    }

    private func templateOverrideKey(for language: String) -> String {
        "TemplateOverride_\(language)"
    }

    private func templateBinding(for language: String) -> Binding<String> {
        Binding<String>(
            get: { UserDefaults.standard.string(forKey: templateOverrideKey(for: language)) ?? defaultTemplate(for: language) ?? "" },
            set: { newValue in UserDefaults.standard.set(newValue, forKey: templateOverrideKey(for: language)) }
        )
    }

    private func defaultTemplate(for language: String) -> String? {
        switch language {
        case "swift":
            return "import Foundation\n\n// TODO: Add code here\n"
        case "python":
            return "def main():\n    pass\n\n\nif __name__ == \"__main__\":\n    main()\n"
        case "javascript":
            return "\"use strict\";\n\nfunction main() {\n  // TODO: Add code here\n}\n\nmain();\n"
        case "typescript":
            return "function main(): void {\n  // TODO: Add code here\n}\n\nmain();\n"
        case "java":
            return "public class Main {\n    public static void main(String[] args) {\n        // TODO: Add code here\n    }\n}\n"
        case "kotlin":
            return "fun main() {\n    // TODO: Add code here\n}\n"
        case "go":
            return "package main\n\nimport \"fmt\"\n\nfunc main() {\n    fmt.Println(\"Hello\")\n}\n"
        case "ruby":
            return "def main\n  # TODO: Add code here\nend\n\nmain\n"
        case "rust":
            return "fn main() {\n    println!(\"Hello\");\n}\n"
        case "c":
            return "#include <stdio.h>\n\nint main(void) {\n    printf(\"Hello\\n\");\n    return 0;\n}\n"
        case "cpp":
            return "#include <iostream>\n\nint main() {\n    std::cout << \"Hello\" << std::endl;\n    return 0;\n}\n"
        case "csharp":
            return "using System;\n\nclass Program {\n    static void Main() {\n        Console.WriteLine(\"Hello\");\n    }\n}\n"
        case "objective-c":
            return "#import <Foundation/Foundation.h>\n\nint main(int argc, const char * argv[]) {\n    @autoreleasepool {\n        NSLog(@\"Hello\");\n    }\n    return 0;\n}\n"
        case "php":
            return "<?php\n\nfunction main() {\n    // TODO: Add code here\n}\n\nmain();\n"
        case "html":
            return "<!doctype html>\n<html>\n<head>\n  <meta charset=\"utf-8\" />\n  <title>Document</title>\n</head>\n<body>\n\n</body>\n</html>\n"
        case "css":
            return "body {\n  margin: 0;\n  font-family: system-ui, sans-serif;\n}\n"
        case "json":
            return "{\n  \"key\": \"value\"\n}\n"
        case "yaml":
            return "key: value\n"
        case "toml":
            return "key = \"value\"\n"
        case "sql":
            return "SELECT *\nFROM table_name;\n"
        case "bash", "zsh":
            return "#!/usr/bin/env \(language)\n\n"
        case "markdown":
            return "# Title\n\n"
        case "plain":
            return ""
        default:
            return "TODO\n"
        }
    }

    private func hexBinding(_ hex: Binding<String>, fallback: Color) -> Binding<Color> {
        Binding<Color>(
            get: { colorFromHex(hex.wrappedValue, fallback: fallback) },
            set: { newColor in hex.wrappedValue = colorToHex(newColor) }
        )
    }
}

#if os(macOS)
final class FontPickerController: NSObject, NSFontChanging {
    private var currentFont: NSFont = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    var onChange: ((NSFont) -> Void)?

    func open(currentName: String, size: Double) {
        let base = NSFont(name: currentName, size: CGFloat(size)) ?? NSFont.monospacedSystemFont(ofSize: CGFloat(size), weight: .regular)
        currentFont = base
        let manager = NSFontManager.shared
        manager.target = self
        manager.action = #selector(changeFont(_:))
        manager.setSelectedFont(base, isMultiple: false)
        NSFontPanel.shared.orderFront(nil)
    }

    @objc func changeFont(_ sender: NSFontManager?) {
        let manager = sender ?? NSFontManager.shared
        let converted = manager.convert(currentFont)
        currentFont = converted
        onChange?(converted)
    }
}
#endif

#if DEBUG && canImport(SwiftUI) && canImport(PreviewsMacros)
#Preview {
    NeonSettingsView(
        supportsOpenInTabs: true,
        supportsTranslucency: true
    )
}
#endif
