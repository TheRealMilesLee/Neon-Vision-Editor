import Foundation

public struct LanguageDetector {
    public static let shared = LanguageDetector()
    private init() {}

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
            ("import swiftui", 20),
            ("import foundation", 15),
            ("struct ", 4),
            (": view", 10),
            ("enum ", 4),
            (" case ", 3),
            ("let ", 4),
            ("var ", 3),
            ("func ", 3),
            ("->", 3),
            ("@main", 8),
            ("#if ", 3),
            ("#endif", 3),
            ("urlsession", 10),
            ("urlrequest(", 8),
            ("jsondecoder", 8),
            ("jsonserialization", 6),
            ("decodable", 8),
            ("encodable", 6),
            ("asyncstream<", 8),
            ("public final class ", 8),
            ("url(", 3),
            ("url(string:", 3),
            ("try await", 8),
            ("task {", 5),
            ("@published", 6),
            ("@stateobject", 6),
            ("@mainactor", 6)
        ]
        for (sig, w) in swiftSignals { if t.contains(sig) { bump("swift", w) } }

        // 4) C# signals
        let hasUsingSystem = t.contains("\nusing system;") || t.contains("\nusing system.")
        let hasNamespace = t.contains("\nnamespace ")
        let hasMainMethod = t.contains("static void main(") || t.contains("static int main(")
        let hasCSharpAttributes = t.contains("\n[") && t.contains("]\n")
        let csharpContext = hasUsingSystem || hasNamespace || hasMainMethod
        let semicolonCount = raw.components(separatedBy: ";").count - 1

        if hasUsingSystem { bump("csharp", 25) }
        if hasNamespace { bump("csharp", 25) }
        if hasMainMethod { bump("csharp", 20) }
        if hasCSharpAttributes { bump("csharp", 8) }
        if csharpContext {
            if semicolonCount > 8 { bump("csharp", 6) }
            if t.contains("\nclass ") && (t.contains("\npublic ") || t.contains(" public ")) && t.contains(" static ") { bump("csharp", 6) }
        } else {
            // Without strong context, cap weak C# signals
            if semicolonCount > 12 { bump("csharp", 2) }
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
        if swiftScore >= 15 && !csharpContext {
            // Penalize accidental C# when Swift is strong and no C# context
            scores["csharp"] = max(0, csharpScore - 10)
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
