import SwiftUI
import Foundation

struct SyntaxColors {
    let keyword: Color
    let string: Color
    let number: Color
    let comment: Color
    let attribute: Color
    let variable: Color
    let def: Color
    let property: Color
    let meta: Color
    let tag: Color
    let atom: Color
    let builtin: Color
    let type: Color

    static func fromVibrantLightTheme(colorScheme: ColorScheme) -> SyntaxColors {
        let baseColors: [String: (light: Color, dark: Color)] = [
            "keyword": (light: Color(red: 251/255, green: 0/255, blue: 186/255), dark: Color(red: 251/255, green: 0/255, blue: 186/255)),
            "string": (light: Color(red: 190/255, green: 0/255, blue: 255/255), dark: Color(red: 190/255, green: 0/255, blue: 255/255)),
            "number": (light: Color(red: 28/255, green: 0/255, blue: 207/255), dark: Color(red: 28/255, green: 0/255, blue: 207/255)),
            "comment": (light: Color(red: 93/255, green: 108/255, blue: 121/255), dark: Color(red: 150/255, green: 160/255, blue: 170/255)),
            "attribute": (light: Color(red: 57/255, green: 0/255, blue: 255/255), dark: Color(red: 57/255, green: 0/255, blue: 255/255)),
            "variable": (light: Color(red: 19/255, green: 0/255, blue: 255/255), dark: Color(red: 19/255, green: 0/255, blue: 255/255)),
            "def": (light: Color(red: 29/255, green: 196/255, blue: 83/255), dark: Color(red: 29/255, green: 196/255, blue: 83/255)),
            "property": (light: Color(red: 29/255, green: 196/255, blue: 83/255), dark: Color(red: 29/255, green: 0/255, blue: 160/255)),
            "meta": (light: Color(red: 255/255, green: 16/255, blue: 0/255), dark: Color(red: 255/255, green: 16/255, blue: 0/255)),
            "tag": (light: Color(red: 170/255, green: 0/255, blue: 160/255), dark: Color(red: 170/255, green: 0/255, blue: 160/255)),
            "atom": (light: Color(red: 28/255, green: 0/255, blue: 207/255), dark: Color(red: 28/255, green: 0/255, blue: 207/255)),
            "builtin": (light: Color(red: 255/255, green: 130/255, blue: 0/255), dark: Color(red: 255/255, green: 130/255, blue: 0/255)),
            "type": (light: Color(red: 170/255, green: 0/255, blue: 160/255), dark: Color(red: 170/255, green: 0/255, blue: 160/255))
        ]

        return SyntaxColors(
            keyword: colorScheme == .dark ? baseColors["keyword"]!.dark : baseColors["keyword"]!.light,
            string: colorScheme == .dark ? baseColors["string"]!.dark : baseColors["string"]!.light,
            number: colorScheme == .dark ? baseColors["number"]!.dark : baseColors["number"]!.light,
            comment: colorScheme == .dark ? baseColors["comment"]!.dark : baseColors["comment"]!.light,
            attribute: colorScheme == .dark ? baseColors["attribute"]!.dark : baseColors["attribute"]!.light,
            variable: colorScheme == .dark ? baseColors["variable"]!.dark : baseColors["variable"]!.light,
            def: colorScheme == .dark ? baseColors["def"]!.dark : baseColors["def"]!.light,
            property: colorScheme == .dark ? baseColors["property"]!.dark : baseColors["property"]!.light,
            meta: colorScheme == .dark ? baseColors["meta"]!.dark : baseColors["meta"]!.light,
            tag: colorScheme == .dark ? baseColors["tag"]!.dark : baseColors["tag"]!.light,
            atom: colorScheme == .dark ? baseColors["atom"]!.dark : baseColors["atom"]!.light,
            builtin: colorScheme == .dark ? baseColors["builtin"]!.dark : baseColors["builtin"]!.light,
            type: colorScheme == .dark ? baseColors["type"]!.dark : baseColors["type"]!.light
        )
    }
}

// Regex patterns per language mapped to colors. Keep light-weight for performance.
func getSyntaxPatterns(for language: String, colors: SyntaxColors) -> [String: Color] {
    switch language {
    case "swift":
        return [
            // Keywords (extended to include `import`)
            "\\b(func|struct|class|enum|protocol|extension|if|else|for|while|switch|case|default|guard|defer|throw|try|catch|return|init|deinit|import)\\b": colors.keyword,

            // Strings and Characters
            "\"[^\"]*\"": colors.string,
            "'[^'\\](?:\\.[^'\\])*'": colors.string,

            // Numbers
            "\\b([0-9]+(\\.[0-9]+)?)\\b": colors.number,

            // Comments (single and multi-line)
            "//.*": colors.comment,
            "/\\*([^*]|(\\*+[^*/]))*\\*+/": colors.comment,

            // Documentation markup (triple slash and doc blocks)
            "(?m)^(///).*$": colors.comment,
            "/\\*\\*([\\s\\S]*?)\\*+/": colors.comment,
            // Documentation keywords inside docs (e.g., - Parameter:, - Returns:)
            "(?m)\\-\\s*(Parameter|Parameters|Returns|Throws|Note|Warning|See\\salso)\\s*:": colors.meta,

            // Marks / TODO / FIXME
            "(?m)//\\s*(MARK|TODO|FIXME)\\s*:.*$": colors.meta,

            // URLs
            "https?://[A-Za-z0-9._~:/?#@!$&'()*+,;=%-]+": colors.atom,
            "file://[A-Za-z0-9._~:/?#@!$&'()*+,;=%-]+": colors.atom,

            // Preprocessor statements (conditionals and directives)
            "(?m)^#(if|elseif|else|endif|warning|error|available)\\b.*$": colors.keyword,

            // Attributes like @available, @MainActor, etc.
            "@\\w+": colors.attribute,

            // Variable declarations
            "\\b(var|let)\\b": colors.variable,

            // Common Swift types
            "\\b(String|Int|Double|Bool)\\b": colors.type,

            // Regex literals and components (Swift /…/)
            "/[^/\\n]*/": colors.builtin, // whole regex literal
            "\\(\\?<([A-Za-z_][A-Za-z0-9_]*)>": colors.def, // named capture start (?<name>
            "\\[[^\\]]*\\]": colors.property, // character classes
            "[|*+?]": colors.meta, // regex operators

            // Common SwiftUI property names like `body`
            "\\bbody\\b": colors.property,
            // Project-specific identifier you mentioned: `viewModel`
            "\\bviewModel\\b": colors.property
        ]
    case "python":
        return [
            "\\b(def|class|if|else|for|while|try|except|with|as|import|from)\\b": colors.keyword,
            "\\b(int|str|float|bool|list|dict)\\b": colors.type,
            "\"[^\"]*\"|'[^']*'": colors.string,
            "\\b([0-9]+(\\.[0-9]+)?)\\b": colors.number,
            "#.*": colors.comment
        ]
    case "javascript":
        return [
            "\\b(function|var|let|const|if|else|for|while|do|try|catch)\\b": colors.keyword,
            "\\b(Number|String|Boolean|Object|Array)\\b": colors.type,
            "\"[^\"]*\"|'[^']*'|\\`[^\\`]*\\`": colors.string,
            "\\b([0-9]+(\\.[0-9]+)?)\\b": colors.number,
            "//.*|/\\*([^*]|(\\*+[^*/]))*\\*+/": colors.comment
        ]
    case "html":
        return ["<[^>]+>": colors.tag]
    case "css":
        return ["\\b([a-zA-Z-]+\\s*:\\s*[^;]+;)": colors.property]
    case "c", "cpp":
        return [
            "\\b(int|float|double|char|void|if|else|for|while|do|switch|case|return)\\b": colors.keyword,
            "\\b(int|float|double|char)\\b": colors.type,
            "\"[^\"]*\"": colors.string,
            "\\b([0-9]+(\\.[0-9]+)?)\\b": colors.number,
            "//.*|/\\*([^*]|(\\*+[^*/]))*\\*+/": colors.comment
        ]
    case "json":
        return [
            "\"[^\"]+\"\\s*:": colors.property,
            "\"[^\"]*\"": colors.string,
            "\\b([0-9]+(\\.[0-9]+)?)\\b": colors.number,
            "\\b(true|false|null)\\b": colors.keyword
        ]
    case "markdown":
        return [
            "^#{1,6}\\s+.+$": colors.keyword,
            "\\*\\*[^*\\n]+\\*\\*": colors.def,
            "(?<!_)_[^_\\n]+_(?!_)": colors.def
        ]
    case "bash":
        return [
            // Keywords and flow control
            #"\b(if|then|else|elif|fi|for|while|do|done|case|esac|function|in|select|until|time)\b"#: colors.keyword,
            // Variables and parameter expansions
            #"\$[A-Za-z_][A-Za-z0-9_]*|\${[^}]+}"#: colors.variable,
            // Command substitution and arithmetic
            #"\$\([^)]*\)|`[^`]*`|\$\(\([^)]*\)\)"#: colors.builtin,
            // Strings
            #"\"[^\"]*\"|'[^']*'"#: colors.string,
            // Numbers
            #"\b[0-9]+\b"#: colors.number,
            // Comments
            #"#.*"#: colors.comment,
            // Here-doc markers and redirections/pipes
            #"<<-?\s*[A-Za-z_][A-Za-z0-9_]*"#: colors.meta,
            #"\|\||\|\s|>>?|<<?|2>\&1|2>>?"#: colors.meta
        ]
    case "zsh":
        return [
            "\\b(if|then|else|elif|fi|for|while|do|done|case|esac|function|in|autoload|typeset|setopt|unsetopt)\\b": colors.keyword,
            "\\$[A-Za-z_][A-Za-z0-9_]*|\\${[^}]+}": colors.variable,
            "\\b[0-9]+\\b": colors.number,
            "\\\"[^\\\"]*\\\"|'[^']*'": colors.string,
            "#.*": colors.comment
        ]
    case "powershell":
        return [
            // Keywords and statements
            #"\b(function|param|if|else|elseif|foreach|for|while|switch|break|continue|return|try|catch|finally)\b"#: colors.keyword,
            // Cmdlets (Get-*, Set-*, Write-*, etc.)
            #"\b(Get|Set|New|Remove|Add|Clear|Write|Read|Start|Stop|Enable|Disable|Invoke|Test|Out|Select|Where|ForEach)-[A-Za-z][A-Za-z0-9]*\b"#: colors.builtin,
            // Variables
            #"\$[A-Za-z_][A-Za-z0-9_:]*"#: colors.variable,
            // Strings (single, double)
            #"\"[^\"]*\"|'[^']*'"#: colors.string,
            // Numbers
            #"\b([0-9]+(\.[0-9]+)?)\b"#: colors.number,
            // Comments
            #"#.*"#: colors.comment
        ]
    case "java":
        return [
            #"\b(class|interface|enum|public|private|protected|static|final|void|int|double|float|boolean|new|return|if|else|for|while|switch|case)\b"#: colors.keyword,
            #"\"[^\"]*\""#: colors.string,
            #"//.*|/\*([^*]|(\*+[^*/]))*\*+/"#: colors.comment,
            #"\b([0-9]+(\.[0-9]+)?)\b"#: colors.number
        ]
    case "kotlin":
        return [
            #"\b(class|object|fun|val|var|when|if|else|for|while|return|import|package|interface)\b"#: colors.keyword,
            #"\"[^\"]*\"|`[^`]*`"#: colors.string,
            #"//.*|/\*([^*]|(\*+[^*/]))*\*+/"#: colors.comment,
            #"\b([0-9]+(\.[0-9]+)?)\b"#: colors.number
        ]
    case "go":
        return [
            #"\b(package|import|func|var|const|type|struct|interface|if|else|for|switch|case|return|go|defer)\b"#: colors.keyword,
            #"\"[^\"]*\"|`[^`]*`"#: colors.string,
            #"//.*|/\*([^*]|(\*+[^*/]))*\*+/"#: colors.comment,
            #"\b([0-9]+(\.[0-9]+)?)\b"#: colors.number
        ]
    case "ruby":
        return [
            #"\b(def|class|module|if|else|elsif|end|do|while|until|case|when|begin|rescue|ensure|return)\b"#: colors.keyword,
            #"\"[^\"]*\"|'[^']*'"#: colors.string,
            #"#.*"#: colors.comment,
            #"\b([0-9]+(\.[0-9]+)?)\b"#: colors.number
        ]
    case "rust":
        return [
            #"\b(fn|let|mut|struct|enum|impl|trait|pub|use|mod|if|else|match|loop|while|for|return)\b"#: colors.keyword,
            #"\"[^\"]*\""#: colors.string,
            #"//.*|/\*([^*]|(\*+[^*/]))*\*+/"#: colors.comment,
            #"\b([0-9]+(\.[0-9]+)?)\b"#: colors.number
        ]
    case "typescript":
        return [
            #"\b(function|class|interface|type|enum|const|let|var|if|else|for|while|do|try|catch|return|extends|implements)\b"#: colors.keyword,
            #"\"[^\"]*\"|'[^']*'|`[^`]*`"#: colors.string,
            #"//.*|/\*([^*]|(\*+[^*/]))*\*+/"#: colors.comment,
            #"\b([0-9]+(\.[0-9]+)?)\b"#: colors.number
        ]
    case "objective-c":
        return [
            #"@\w+"#: colors.attribute,
            #"\b(if|else|for|while|switch|case|return)\b"#: colors.keyword,
            #"\"[^\"]*\""#: colors.string,
            #"//.*|/\*([^*]|(\*+[^*/]))*\*+/"#: colors.comment,
            #"\b([0-9]+(\.[0-9]+)?)\b"#: colors.number
        ]
    case "sql":
        return [
            #"\b(SELECT|INSERT|UPDATE|DELETE|CREATE|TABLE|FROM|WHERE|JOIN|LEFT|RIGHT|INNER|OUTER|GROUP|BY|ORDER|LIMIT|VALUES|INTO)\b"#: colors.keyword,
            #"'[^']*'|\"[^\"]*\""#: colors.string,
            #"--.*"#: colors.comment,
            #"\b([0-9]+(\.[0-9]+)?)\b"#: colors.number
        ]
    case "xml":
        return [
            #"<[^>]+>"#: colors.tag,
            #"\"[^\"]*\""#: colors.string
        ]
    case "yaml":
        return [
            #"^\s*-[\s\S]*$"#: colors.keyword,
            #"\b(true|false|null)\b"#: colors.keyword,
            #"\b[0-9]+\b"#: colors.number
        ]
    case "toml":
        return [
            #"^\[[^\]]+\]"#: colors.meta,
            #"\b[0-9]+\b"#: colors.number,
            #"\"[^\"]*\""#: colors.string
        ]
    case "ini":
        return [
            #"^\[[^\]]+\]"#: colors.meta,
            #"^;.*$"#: colors.comment,
            #"^\w+\s*=\s*.*$"#: colors.property
        ]
    case "csharp":
        return [
            #"\b(class|interface|enum|struct|namespace|using|public|private|protected|internal|static|readonly|sealed|abstract|virtual|override|async|await|new|return|if|else|for|foreach|while|do|switch|case|break|continue|try|catch|finally|throw)\b"#: colors.keyword,
            #"\b(string|int|double|float|bool|decimal|char|void|object|var|List<[^>]+>|Dictionary<[^>]+>)\b"#: colors.type,
            #"\"[^\"]*\""#: colors.string,
            #"\b([0-9]+(\.[0-9]+)?)\b"#: colors.number,
            #"//.*|/\*([^*]|(\*+[^*/]))*\*+/"#: colors.comment
        ]
    case "standard":
        return [
            // Strings (double/single/backtick)
            #"\"[^\"]*\"|'[^']*'|`[^`]*`"#: colors.string,
            // Numbers
            #"\b([0-9]+(\.[0-9]+)?)\b"#: colors.number,
            // Line and block comments for C-like and hash comments
            #"//.*|/\*([^*]|(\*+[^*/]))*\*+/|#.*"#: colors.comment,
            // Common keywords from several languages
            #"\b(if|else|for|while|do|switch|case|return|class|struct|enum|func|function|var|let|const|import|from|using|namespace|public|private|protected|static|void|new|try|catch|finally|throw)\b"#: colors.keyword
        ]
    case "plain":
        return [:]
    default:
        return [:]
    }
}

// Simple sheet to edit and persist API tokens for external AI providers.
