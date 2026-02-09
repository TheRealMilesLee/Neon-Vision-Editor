import Foundation

public struct LanguageDetector {
    public static let shared = LanguageDetector()
    private init() {}

    // Detection toggles (enabled by default)
    public static var csharpDetectionEnabled: Bool = true
    public static var cDetectionEnabled: Bool = true

    // Known extension to language map
    private let extensionMap: [String: String] = [
        "swift": "swift",
        "py": "python",
        "pyi": "python",
        "js": "javascript",
        "mjs": "javascript",
        "cjs": "javascript",
        "ts": "typescript",
        "tsx": "typescript",
        "php": "php",
        "phtml": "php",
        "csv": "csv",
        "tsv": "csv",
        "toml": "toml",
        "ini": "ini",
        "yaml": "yaml",
        "yml": "yaml",
        "xml": "xml",
        "sql": "sql",
        "log": "log",
        "vim": "vim",
        "ipynb": "ipynb",
        "java": "java",
        "kt": "kotlin",
        "kts": "kotlin",
        "go": "go",
        "rb": "ruby",
        "rs": "rust",
        "ps1": "powershell",
        "psm1": "powershell",
        "html": "html",
        "htm": "html",
        "css": "css",
        "c": "c",
        "cpp": "cpp",
        "cc": "cpp",
        "hpp": "cpp",
        "hh": "cpp",
        "h": "cpp",
        "m": "objective-c",
        "mm": "objective-c",
        "cs": "csharp",
        "json": "json",
        "jsonc": "json",
        "json5": "json",
        "md": "markdown",
        "markdown": "markdown",
        "env": "dotenv",
        "proto": "proto",
        "graphql": "graphql",
        "gql": "graphql",
        "rst": "rst",
        "conf": "nginx",
        "nginx": "nginx",
        "cob": "cobol",
        "cbl": "cobol",
        "cobol": "cobol",
        "sh": "bash",
        "bash": "bash",
        "zsh": "zsh"
    ]

    private let dotfileMap: [String: String] = [
        ".zshrc": "zsh",
        ".zprofile": "zsh",
        ".zlogin": "zsh",
        ".zlogout": "zsh",
        ".bashrc": "bash",
        ".bash_profile": "bash",
        ".bash_login": "bash",
        ".bash_logout": "bash",
        ".profile": "bash",
        ".vimrc": "vim",
        ".env": "dotenv",
        ".envrc": "dotenv",
        ".gitconfig": "ini"
    ]

    public struct Result {
        public let lang: String
        public let scores: [String: Int]
        public let confidence: Int // difference between top-1 and top-2
    }

    public func preferredLanguage(for fileURL: URL?) -> String? {
        guard let fileURL else { return nil }
        let fileName = fileURL.lastPathComponent.lowercased()
        if fileName.hasPrefix(".env") {
            return "dotenv"
        }
        if let mapped = dotfileMap[fileName] {
            return mapped
        }
        let ext = fileURL.pathExtension.lowercased()
        return extensionMap[ext]
    }

    // Main API
    public func detect(text: String, name: String?, fileURL: URL?) -> Result {
        let raw = text
        let t = raw.lowercased()
        let trimmed = t.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strong priority: if the text contains "import SwiftUI" anywhere, classify as Swift immediately.
        if t.contains("import swiftui") {
            return Result(lang: "swift", scores: ["swift": 10_000], confidence: 10_000)
        }

        // Additional strong Swift early-returns for common app files
        if t.contains("@main") {
            return Result(lang: "swift", scores: ["swift": 10_000], confidence: 10_000)
        }
        if (t.contains("struct ") && t.contains(": view")) || t.contains("import appkit") || t.contains("import uikit") || t.contains("import foundationmodels") {
            return Result(lang: "swift", scores: ["swift": 9_000], confidence: 9_000)
        }

        // If content includes several Swift-only tokens, force Swift regardless of other signals
        if t.contains("@published") || t.contains("@stateobject") || t.contains("guard ") || t.contains(" if let ") {
            return Result(lang: "swift", scores: ["swift": 8_000], confidence: 8_000)
        }

        // Swift-specific class modifier that's uncommon in C# (uses 'sealed' instead)
        if t.contains(" final class ") || t.contains("public final class ") {
            return Result(lang: "swift", scores: ["swift": 8_500], confidence: 8_500)
        }

        var scores: [String: Int] = [
            "swift": 0,
            "csharp": 0,
            "php": 0,
            "csv": 0,
            "python": 0,
            "javascript": 0,
            "typescript": 0,
            "java": 0,
            "kotlin": 0,
            "go": 0,
            "ruby": 0,
            "rust": 0,
            "dotenv": 0,
            "proto": 0,
            "graphql": 0,
            "rst": 0,
            "nginx": 0,
            "cpp": 0,
            "c": 0,
            "css": 0,
            "markdown": 0,
            "json": 0,
            "html": 0,
            "sql": 0,
            "xml": 0,
            "yaml": 0,
            "toml": 0,
            "ini": 0,
            "vim": 0,
            "log": 0,
            "ipynb": 0,
            "powershell": 0,
            "cobol": 0,
            "objective-c": 0,
            "bash": 0,
            "zsh": 0
        ]

        func bump(_ key: String, _ amount: Int) { scores[key, default: 0] += amount }
        func count(of needle: String) -> Int { t.components(separatedBy: needle).count - 1 }

        // 0) Extension prior
        if let byURL = preferredLanguage(for: fileURL) {
            bump(byURL, 80)
        } else if let name {
            let lowerName = name.lowercased()
            if let mapped = dotfileMap[lowerName] {
                bump(mapped, 80)
            } else {
                let ext = URL(fileURLWithPath: lowerName).pathExtension.lowercased()
                if let mapped = extensionMap[ext] {
                    bump(mapped, 80)
                }
            }
        }

        // 1) Explicit fenced hints
        if t.contains("```swift") { bump("swift", 100) }
        if t.contains("```python") { bump("python", 100) }
        if t.contains("```js") || t.contains("```javascript") { bump("javascript", 100) }
        if t.contains("```php") { bump("php", 100) }
        if t.contains("```ts") || t.contains("```typescript") { bump("typescript", 100) }
        if t.contains("```java") { bump("java", 100) }
        if t.contains("```kotlin") || t.contains("```kt") { bump("kotlin", 100) }
        if t.contains("```go") { bump("go", 100) }
        if t.contains("```ruby") || t.contains("```rb") { bump("ruby", 100) }
        if t.contains("```rust") || t.contains("```rs") { bump("rust", 100) }
        if t.contains("```csharp") || t.contains("```cs") { bump("csharp", 100) }
        if t.contains("```cpp") || t.contains("```c++") { bump("cpp", 100) }
        if t.contains("```c") { bump("c", 100) }
        if t.contains("```proto") { bump("proto", 100) }
        if t.contains("```graphql") || t.contains("```gql") { bump("graphql", 100) }
        if t.contains("```dotenv") || t.contains("```env") { bump("dotenv", 100) }
        if t.contains("```rst") { bump("rst", 100) }
        if t.contains("```sql") { bump("sql", 100) }
        if t.contains("```xml") { bump("xml", 100) }
        if t.contains("```yaml") || t.contains("```yml") { bump("yaml", 100) }
        if t.contains("```toml") { bump("toml", 100) }
        if t.contains("```ini") { bump("ini", 100) }
        if t.contains("```vim") { bump("vim", 100) }
        if t.contains("```powershell") || t.contains("```ps1") { bump("powershell", 100) }
        if t.contains("```cobol") { bump("cobol", 100) }
        if t.contains("```objective-c") || t.contains("```objc") { bump("objective-c", 100) }

        // 2) Single-language quick checks
        if let first = trimmed.first, (first == "{" || first == "[") && t.contains(":") { bump("json", 90) }
        if t.contains("<?xml") { bump("xml", 90) }
        if t.contains("<html") || t.contains("<body") || t.contains("</") { bump("html", 90) }
        if t.contains("<?php") || t.contains("<?=") { bump("php", 90) }
        if t.contains("syntax = \"proto") { bump("proto", 90) }
        if t.contains("schema {") || t.contains("type query") { bump("graphql", 70) }
        if t.contains("server {") || t.contains("http {") || t.contains("location /") { bump("nginx", 70) }
        if t.contains(".. toctree::") || t.contains(".. code-block::") { bump("rst", 70) }
        if t.contains("[") && t.contains("]") && t.range(of: #"(?m)^\s*\[[^]]+\]\s*$"#, options: .regularExpression) != nil { bump("ini", 70) }
        if t.range(of: #"(?m)^[A-Za-z0-9_.-]+\s*:\s+\S+"#, options: .regularExpression) != nil { bump("yaml", 60) }
        if t.range(of: #"(?m)^\s*\w+\s*=\s*.+$"#, options: .regularExpression) != nil { bump("toml", 60) }
        if t.contains("\"cells\"") && t.contains("\"cell_type\"") && t.contains("\"metadata\"") { bump("ipynb", 90) }
        if t.range(of: #"(?m)^[A-Z_][A-Z0-9_]*\s*="#, options: .regularExpression) != nil { bump("dotenv", 70) }
        if raw.contains(",") && raw.contains("\n") {
            let lines = raw.split(separator: "\n", omittingEmptySubsequences: true)
            if lines.count >= 2 {
                let commaCounts = lines.prefix(6).map { line in line.filter { $0 == "," }.count }
                if let firstCount = commaCounts.first, firstCount > 0 && commaCounts.dropFirst().allSatisfy({ $0 == firstCount || abs($0 - firstCount) <= 1 }) {
                    bump("csv", 80)
                }
            }
        }
        if t.contains("#!/bin/bash") || t.contains("#!/usr/bin/env bash") { bump("bash", 90) }
        if t.contains("#!/bin/zsh") || t.contains("#!/usr/bin/env zsh") { bump("zsh", 90) }
        if t.contains("#!/bin/sh") || t.contains("#!/usr/bin/env sh") { bump("bash", 40) }

        // 3) Swift signals
        let swiftSignals = [
            ("import swiftui", 30),
            ("import foundation", 20),
            ("import appkit", 18),
            ("import uikit", 18),
            ("import combine", 16),
            ("import swiftdata", 16),
            ("struct ", 6),
            (": view", 14),
            ("enum ", 5),
            (" class ", 4),
            (" case ", 4),
            ("let ", 6),
            ("var ", 5),
            ("func ", 5),
            ("->", 4),
            (" init(", 6),
            ("guard ", 10),
            ("if let ", 10),
            ("as?", 6),
            ("as!", 6),
            ("try?", 6),
            ("try!", 6),
            ("@main", 10),
            ("#if ", 4),
            ("#endif", 4),
            ("urlsession", 10),
            ("urlrequest(", 8),
            ("jsondecoder", 8),
            ("jsonserialization", 6),
            ("decodable", 8),
            ("encodable", 6),
            ("asyncstream<", 8),
            ("observableobject", 10),
            ("@published", 8),
            ("@stateobject", 8),
            ("@state", 6),
            ("@binding", 6),
            ("@mainactor", 8)
        ,
        ("public final class ", 14),
        (" final class ", 12),
        ("protocol ", 10),
        ("extension ", 10)
        ]
        for (sig, w) in swiftSignals { if t.contains(sig) { bump("swift", w) } }

        // 4) C# signals
        let hasUsingSystem = t.contains("\nusing system;") || t.contains("\nusing system.")
        let hasNamespace = t.contains("\nnamespace ")
        let hasMainMethod = t.contains("static void main(") || t.contains("static int main(")
        let hasCSharpAttributes = t.contains("\n[") && t.contains("]\n") && !t.contains("@")
        let csharpContext = hasUsingSystem || hasNamespace || hasMainMethod
        let semicolonCount = raw.components(separatedBy: ";").count - 1

        if hasUsingSystem { bump("csharp", 18) }
        if hasNamespace { bump("csharp", 18) }
        if hasMainMethod { bump("csharp", 16) }
        if hasCSharpAttributes { bump("csharp", 6) }
        if csharpContext {
            if semicolonCount > 8 { bump("csharp", 4) }
            if t.contains("\nclass ") && (t.contains("\npublic ") || t.contains(" public ")) && t.contains(" static ") {
                bump("csharp", 4)
            }
        } else {
            // Without strong context, do not let semicolons alone push C# over Swift
            if semicolonCount > 20 { bump("csharp", 1) }
        }

        // 5) Python
        if t.contains("\ndef ") || t.hasPrefix("def ") { bump("python", 15) }
        if t.contains("\nimport ") && t.contains(":\n") { bump("python", 8) }

        // 6) PHP
        if t.contains("$this->") || t.contains("$_get") || t.contains("$_post") || t.contains("$_server") || t.contains("$_session") {
            bump("php", 20)
        }
        if (t.contains("function ") && t.contains("$")) || t.contains("echo ") {
            bump("php", 10)
        }

        // 7) JavaScript / TypeScript
        if t.contains("function ") || t.contains("=>") || t.contains("console.log") { bump("javascript", 15) }
        if t.contains("interface ") || t.contains("type ") || t.contains("implements ") || t.contains("readonly ") || t.contains(" as const") {
            bump("typescript", 16)
        }
        if t.contains(": string") || t.contains(": number") || t.contains(": boolean") {
            bump("typescript", 10)
        }

        // 8) C/C++
        if t.contains("#include") { bump("c", 10); bump("cpp", 10) }
        if t.contains("std::") { bump("cpp", 20) }
        if t.contains("int main(") { bump("c", 6); bump("cpp", 6) }
        if t.contains("printf(") || t.contains("scanf(") { bump("c", 8) }

        // 9) CSS
        if t.contains("{") && t.contains("}") && t.contains(":") && t.contains(";") && !t.contains("func ") {
            bump("css", 8)
        }

        // 10) Proto
        if t.contains("message ") || t.contains("enum ") || t.contains("rpc ") { bump("proto", 10) }

        // 11) GraphQL
        if t.contains("type ") && t.contains("{") && t.contains("}") { bump("graphql", 8) }
        if t.contains("fragment ") || t.contains("mutation") || t.contains("subscription") { bump("graphql", 8) }

        // 12) Nginx
        if t.contains("proxy_pass") || t.contains("server_name") || t.contains("error_log") { bump("nginx", 8) }

        // 13) reStructuredText
        if t.contains("::") && t.contains("\n====") { bump("rst", 6) }

        // 14) Markdown
        if t.contains("\n# ") || t.hasPrefix("# ") || t.contains("\n- ") || t.contains("\n* ") { bump("markdown", 8) }

        // 15) Java
        if t.contains("public class ") || t.contains("public static void main") || t.contains("package ") { bump("java", 18) }
        if t.contains("import java.") { bump("java", 12) }

        // 16) Kotlin
        if t.contains("fun ") || t.contains("val ") || t.contains("var ") || t.contains("data class ") || t.contains("object ") { bump("kotlin", 12) }
        if t.contains("suspend fun") || t.contains("companion object") { bump("kotlin", 12) }

        // 17) Go
        if t.contains("package main") || t.contains("func ") { bump("go", 14) }
        if t.contains("import (") || t.contains("fmt.") { bump("go", 8) }

        // 18) Ruby
        if t.contains("\ndef ") || t.contains("\nclass ") || t.contains("\nmodule ") { bump("ruby", 12) }
        if t.contains("\nend") || t.contains("puts ") { bump("ruby", 6) }

        // 19) Rust
        if t.contains("fn ") || t.contains("let mut ") || t.contains("use ") { bump("rust", 12) }
        if t.contains("crate::") || t.contains("impl ") || t.contains("trait ") { bump("rust", 8) }

        // 20) Objective-C
        if t.contains("@interface") || t.contains("@implementation") || t.contains("#import <foundation") { bump("objective-c", 18) }

        // 21) SQL
        if t.contains("select ") || t.contains("insert ") || t.contains("update ") || t.contains("create table") { bump("sql", 14) }

        // 22) XML
        if t.contains("<?xml") || (t.contains("<") && t.contains("</") && !t.contains("<html")) { bump("xml", 10) }

        // 23) YAML
        if t.contains("---") || t.range(of: #"(?m)^\w+:\s+.+$"#, options: .regularExpression) != nil { bump("yaml", 8) }

        // 24) TOML
        if t.range(of: #"(?m)^\[[^\]]+\]$"#, options: .regularExpression) != nil { bump("toml", 8) }

        // 25) INI
        if t.range(of: #"(?m)^\[[^\]]+\]$"#, options: .regularExpression) != nil && t.range(of: #"(?m)^\w+\s*=\s*.+$"#, options: .regularExpression) != nil { bump("ini", 8) }

        // 26) Vimscript
        if t.contains("autocmd") || t.contains("nnoremap") || t.contains("inoremap") || t.contains("set ") { bump("vim", 10) }

        // 27) Log
        if t.range(of: #"(?m)^\[(info|warn|error|debug)\]"#, options: .regularExpression) != nil { bump("log", 8) }

        // 28) PowerShell
        if t.contains("param(") || t.contains("write-host") || t.contains("$psversiontable") { bump("powershell", 12) }

        // 29) COBOL
        if t.contains("identification division") || t.contains("procedure division") { bump("cobol", 14) }

        // Conflict resolution tweaks
        let swiftScore = scores["swift"] ?? 0
        let csharpScore = scores["csharp"] ?? 0
        if swiftScore >= 20 && !csharpContext {
            // Strong Swift indicators without C# context: heavily penalize accidental C# bumps
            scores["csharp"] = max(0, csharpScore - 20)
        } else if swiftScore >= 15 && !csharpContext {
            // Moderate Swift indicators: apply smaller penalty
            scores["csharp"] = max(0, csharpScore - 10)
        }

        if (t.contains("import swiftui") || t.contains(": view") || t.contains("@main") || t.contains(" final class ")) && !csharpContext {
            scores["csharp"] = max(0, (scores["csharp"] ?? 0) - 40)
        }

        // If Swift-only tokens are present, strongly discourage C#
        if (t.contains(" final class ") || t.contains("@published") || t.contains(": view")) && !csharpContext {
            scores["csharp"] = max(0, (scores["csharp"] ?? 0) - 30)
        }

        // If C# detection is disabled, ensure it cannot win
        if !Self.csharpDetectionEnabled {
            scores["csharp"] = Int.min / 2
        }

        // If C detection is disabled, ensure it cannot win
        if !Self.cDetectionEnabled {
            scores["c"] = Int.min / 2
        }

        // Decide winner and confidence
        let sorted = scores.sorted { $0.value > $1.value }
        let top = sorted.first
        let second = sorted.dropFirst().first
        let confidence = max(0, (top?.value ?? 0) - (second?.value ?? 0))
        let lang = (top?.value ?? 0) > 0 ? (top?.key ?? "plain") : "plain"
        return Result(lang: lang, scores: scores, confidence: confidence)
    }
}

