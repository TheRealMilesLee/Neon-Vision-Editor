import Foundation

public struct LanguageDetector {
    public static let shared = LanguageDetector()
    private init() {}

    // Temporary kill-switch for C# detection; set to true to re-enable
    public static var csharpDetectionEnabled: Bool = false

    // Temporary kill-switch for C detection; set to true to re-enable
    public static var cDetectionEnabled: Bool = false

    // Known extension to language map
    private let extensionMap: [String: String] = [
        "swift": "swift",
        "py": "python",
        "js": "javascript",
        "ts": "javascript",
        "html": "html",
        "css": "css",
        "c": "c",
        "cpp": "cpp",
        "cc": "cpp",
        "hpp": "cpp",
        "h": "c",
        "cs": "csharp",
        "json": "json",
        "md": "markdown",
        "sh": "bash",
        "bash": "bash",
        "zsh": "zsh"
    ]

    public struct Result {
        public let lang: String
        public let scores: [String: Int]
        public let confidence: Int // difference between top-1 and top-2
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
            "python": 0,
            "javascript": 0,
            "cpp": 0,
            "c": 0,
            "css": 0,
            "markdown": 0,
            "json": 0,
            "html": 0,
            "bash": 0,
            "zsh": 0
        ]

        func bump(_ key: String, _ amount: Int) { scores[key, default: 0] += amount }
        func count(of needle: String) -> Int { t.components(separatedBy: needle).count - 1 }

        // 0) Extension prior
        let ext: String? = {
            if let url = fileURL { return url.pathExtension.lowercased() }
            if let name = name { return URL(fileURLWithPath: name).pathExtension.lowercased() }
            return nil
        }()
        if let ext, let lang = extensionMap[ext] {
            bump(lang, 80) // strong prior from extension
        }

        // 1) Explicit fenced hints
        if t.contains("```swift") { bump("swift", 100) }
        if t.contains("```python") { bump("python", 100) }
        if t.contains("```js") || t.contains("```javascript") { bump("javascript", 100) }
        if t.contains("```csharp") || t.contains("```cs") { bump("csharp", 100) }
        if t.contains("```cpp") || t.contains("```c++") { bump("cpp", 100) }

        // 2) Single-language quick checks
        if let first = trimmed.first, (first == "{" || first == "[") && t.contains(":") { bump("json", 90) }
        if t.contains("<html") || t.contains("<body") || t.contains("</") { bump("html", 90) }
        if t.contains("#!/bin/bash") || t.contains("#!/usr/bin/env bash") { bump("bash", 90) }
        if t.contains("#!/bin/zsh") || t.contains("#!/usr/bin/env zsh") { bump("zsh", 90) }

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

        // 6) JavaScript / TypeScript
        if t.contains("function ") || t.contains("=>") || t.contains("console.log") { bump("javascript", 15) }

        // 7) C/C++
        if t.contains("#include") || t.contains("std::") { bump("cpp", 20) }
        if t.contains("int main(") { bump("cpp", 8) }

        // 8) CSS
        if t.contains("{") && t.contains("}") && t.contains(":") && t.contains(";") && !t.contains("func ") {
            bump("css", 8)
        }

        // 9) Markdown
        if t.contains("\n# ") || t.hasPrefix("# ") || t.contains("\n- ") || t.contains("\n* ") { bump("markdown", 8) }

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

