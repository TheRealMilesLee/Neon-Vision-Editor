import SwiftUI

struct NeonSettingsView: View {
    let supportsOpenInTabs: Bool
    let supportsTranslucency: Bool
    let supportsInvisibles: Bool
    let supportsPageGuide: Bool
    @AppStorage("SettingsOpenInTabs") private var openInTabs: String = "system"
    @AppStorage("SettingsEditorFontName") private var editorFontName: String = "Menlo"
    @AppStorage("SettingsEditorFontSize") private var editorFontSize: Double = 13
    @AppStorage("SettingsLineHeight") private var lineHeight: Double = 1.3
    @AppStorage("SettingsAppearance") private var appearance: String = "system"
    @AppStorage("EnableTranslucentWindow") private var translucentWindow: Bool = false

    @AppStorage("SettingsShowLineNumbers") private var showLineNumbers: Bool = true
    @AppStorage("SettingsShowInvisibles") private var showInvisibles: Bool = false
    @AppStorage("SettingsHighlightCurrentLine") private var highlightCurrentLine: Bool = true
    @AppStorage("SettingsShowPageGuide") private var showPageGuide: Bool = false
    @AppStorage("SettingsPageGuideColumn") private var pageGuideColumn: Int = 80
    @AppStorage("SettingsLineWrapEnabled") private var lineWrapEnabled: Bool = true

    @AppStorage("SettingsIndentStyle") private var indentStyle: String = "spaces"
    @AppStorage("SettingsIndentWidth") private var indentWidth: Int = 4
    @AppStorage("SettingsAutoIndent") private var autoIndent: Bool = true
    @AppStorage("SettingsAutoCloseBrackets") private var autoCloseBrackets: Bool = true
    @AppStorage("SettingsTrimTrailingWhitespace") private var trimTrailingWhitespace: Bool = false

    @AppStorage("SettingsCompletionEnabled") private var completionEnabled: Bool = false
    @AppStorage("SettingsCompletionFromDocument") private var completionFromDocument: Bool = true
    @AppStorage("SettingsCompletionFromSyntax") private var completionFromSyntax: Bool = false

    @AppStorage("SettingsThemeName") private var selectedTheme: String = "Neon Glow"
    @AppStorage("SettingsThemeTextColor") private var themeTextHex: String = "#EDEDED"
    @AppStorage("SettingsThemeBackgroundColor") private var themeBackgroundHex: String = "#0E1116"
    @AppStorage("SettingsThemeCursorColor") private var themeCursorHex: String = "#4EA4FF"
    @AppStorage("SettingsThemeSelectionColor") private var themeSelectionHex: String = "#2A3340"
    @AppStorage("SettingsThemeKeywordColor") private var themeKeywordHex: String = "#F5D90A"
    @AppStorage("SettingsThemeStringColor") private var themeStringHex: String = "#FF7AD9"
    @AppStorage("SettingsThemeNumberColor") private var themeNumberHex: String = "#FFB86C"
    @AppStorage("SettingsThemeCommentColor") private var themeCommentHex: String = "#7F8C98"

    private let themes: [String] = [
        "Neon Glow",
        "Arc",
        "Dusk",
        "Midnight",
        "Mono",
        "Paper",
        "Pulse",
        "Custom"
    ]

    init(
        supportsOpenInTabs: Bool = true,
        supportsTranslucency: Bool = true,
        supportsInvisibles: Bool = true,
        supportsPageGuide: Bool = true
    ) {
        self.supportsOpenInTabs = supportsOpenInTabs
        self.supportsTranslucency = supportsTranslucency
        self.supportsInvisibles = supportsInvisibles
        self.supportsPageGuide = supportsPageGuide
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            editorTab
                .tabItem { Label("Editor", systemImage: "slider.horizontal.3") }
            codeTab
                .tabItem { Label("Code", systemImage: "chevron.left.forwardslash.chevron.right") }
            themeTab
                .tabItem { Label("Themes", systemImage: "paintpalette") }
        }
#if os(macOS)
        .tabViewStyle(.sidebar)
#endif
        .frame(minWidth: 860, minHeight: 620)
    }

    private var generalTab: some View {
        Form {
            Section("Window") {
                if supportsOpenInTabs {
                    Picker("Open in Tabs", selection: $openInTabs) {
                        Text("Follow System").tag("system")
                        Text("Always").tag("always")
                        Text("Never").tag("never")
                    }
                    .pickerStyle(.segmented)
                }

                Picker("Appearance", selection: $appearance) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)

                if supportsTranslucency {
                    Toggle("Translucent Window", isOn: $translucentWindow)
                }
            }

            Section("Editor Font") {
                HStack {
                    TextField("Font Name", text: $editorFontName)
                    Stepper(value: $editorFontSize, in: 10...28, step: 1) {
                        Text("\(Int(editorFontSize)) pt")
                    }
                    .frame(maxWidth: 120)
                }

                HStack {
                    Text("Line Height")
                    Slider(value: $lineHeight, in: 1.0...1.8, step: 0.05)
                    Text(String(format: "%.2fx", lineHeight))
                        .frame(width: 54, alignment: .trailing)
                }
            }
        }
        .padding(16)
    }

    private var editorTab: some View {
        Form {
            Section("Display") {
                Toggle("Show Line Numbers", isOn: $showLineNumbers)
                if supportsInvisibles {
                    Toggle("Show Invisibles", isOn: $showInvisibles)
                }
                Toggle("Highlight Current Line", isOn: $highlightCurrentLine)
                Toggle("Line Wrap", isOn: $lineWrapEnabled)
            }

            if supportsPageGuide {
                Section("Page Guide") {
                    Toggle("Show Page Guide", isOn: $showPageGuide)
                    Stepper(value: $pageGuideColumn, in: 40...200, step: 1) {
                        Text("Column \(pageGuideColumn)")
                    }
                    .disabled(!showPageGuide)
                }
            }
        }
        .padding(16)
    }

    private var codeTab: some View {
        Form {
            Section("Indentation") {
                Picker("Indent Style", selection: $indentStyle) {
                    Text("Spaces").tag("spaces")
                    Text("Tabs").tag("tabs")
                }
                .pickerStyle(.segmented)

                Stepper(value: $indentWidth, in: 2...8, step: 1) {
                    Text("Indent Width: \(indentWidth)")
                }
            }

            Section("Editing") {
                Toggle("Auto Indent", isOn: $autoIndent)
                Toggle("Auto Close Brackets", isOn: $autoCloseBrackets)
                Toggle("Trim Trailing Whitespace", isOn: $trimTrailingWhitespace)
            }

            Section("Completion") {
                Toggle("Enable Completion", isOn: $completionEnabled)
                Toggle("Include Words in Document", isOn: $completionFromDocument)
                Toggle("Include Syntax Keywords", isOn: $completionFromSyntax)
            }
        }
        .padding(16)
    }

    private var themeTab: some View {
        let isCustom = selectedTheme == "Custom"
        HStack(spacing: 16) {
            List(themes, id: \.self, selection: $selectedTheme) { theme in
                Text(theme)
            }
            .frame(minWidth: 200)

            VStack(alignment: .leading, spacing: 16) {
                Text("Theme Colors")
                    .font(.headline)

                colorRow(title: "Text", color: hexBinding($themeTextHex, fallback: .white))
                    .disabled(!isCustom)
                colorRow(title: "Background", color: hexBinding($themeBackgroundHex, fallback: .black))
                    .disabled(!isCustom)
                colorRow(title: "Cursor", color: hexBinding($themeCursorHex, fallback: .blue))
                    .disabled(!isCustom)
                colorRow(title: "Selection", color: hexBinding($themeSelectionHex, fallback: .gray))
                    .disabled(!isCustom)

                Divider()

                Text("Syntax")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                colorRow(title: "Keywords", color: hexBinding($themeKeywordHex, fallback: .yellow))
                    .disabled(!isCustom)
                colorRow(title: "Strings", color: hexBinding($themeStringHex, fallback: .pink))
                    .disabled(!isCustom)
                colorRow(title: "Numbers", color: hexBinding($themeNumberHex, fallback: .orange))
                    .disabled(!isCustom)
                colorRow(title: "Comments", color: hexBinding($themeCommentHex, fallback: .gray))
                    .disabled(!isCustom)

                Spacer()
                Text(isCustom ? "Custom theme applies immediately." : "Select Custom to edit colors.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
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

    private func hexBinding(_ hex: Binding<String>, fallback: Color) -> Binding<Color> {
        Binding<Color>(
            get: { colorFromHex(hex.wrappedValue, fallback: fallback) },
            set: { newColor in hex.wrappedValue = colorToHex(newColor) }
        )
    }
}

#Preview {
    NeonSettingsView(
        supportsOpenInTabs: true,
        supportsTranslucency: true,
        supportsInvisibles: true,
        supportsPageGuide: true
    )
}
