import SwiftUI
import Foundation

#if os(macOS)
import AppKit

final class AcceptingTextView: NSTextView {
    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override var isOpaque: Bool { false }

    // We want the caret at the *start* of the paste.
    private var pendingPasteCaretLocation: Int?

    // MARK: - Drag & Drop: insert file contents instead of file path
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let canRead = sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ])
        return canRead ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        if let nsurls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [NSURL],
           let first = nsurls.first {
            let url: URL = first as URL
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                // Read file contents with security-scoped access
                let content: String
                if let data = try? Data(contentsOf: url) {
                    if let s = String(data: data, encoding: .utf8) {
                        content = s
                    } else if let s = String(data: data, encoding: .utf16) {
                        content = s
                    } else {
                        content = try String(contentsOf: url, encoding: .utf8)
                    }
                } else {
                    content = try String(contentsOf: url, encoding: .utf8)
                }
                // Replace current selection with the dropped file contents
                let nsContent = content as NSString
                let sel = selectedRange()
                undoManager?.disableUndoRegistration()
                textStorage?.beginEditing()
                textStorage?.mutableString.replaceCharacters(in: sel, with: nsContent as String)
                textStorage?.endEditing()
                undoManager?.enableUndoRegistration()
                // Notify the text system so delegates/SwiftUI binding update
                self.didChangeText()
                // Move caret to the end of inserted content and reveal range
                let newLoc = sel.location + nsContent.length
                setSelectedRange(NSRange(location: newLoc, length: 0))
                // Ensure the full inserted range is visible
                let insertedRange = NSRange(location: sel.location, length: nsContent.length)
                scrollRangeToVisible(insertedRange)
                
                NotificationCenter.default.post(name: .pastedText, object: content)
                
                return true
            } catch {
                return false
            }
        }
        return false
    }

    // MARK: - Typing helpers (your existing behavior)
    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        guard let s = insertString as? String else {
            super.insertText(insertString, replacementRange: replacementRange)
            return
        }

        // Auto-indent by copying leading whitespace
        if s == "\n" {
            // Auto-indent: copy leading whitespace from current line
            let ns = (string as NSString)
            let sel = selectedRange()
            let lineRange = ns.lineRange(for: NSRange(location: sel.location, length: 0))
            let currentLine = ns.substring(with: NSRange(
                location: lineRange.location,
                length: max(0, sel.location - lineRange.location)
            ))
            let indent = currentLine.prefix { $0 == " " || $0 == "\t" }
            super.insertText("\n" + indent, replacementRange: replacementRange)
            return
        }

        // Auto-close common bracket/quote pairs
        let pairs: [String: String] = ["(": ")", "[": "]", "{": "}", "\"": "\"", "'": "'"]
        if let closing = pairs[s] {
            let sel = selectedRange()
            super.insertText(s + closing, replacementRange: replacementRange)
            setSelectedRange(NSRange(location: sel.location + 1, length: 0))
            return
        }

        super.insertText(insertString, replacementRange: replacementRange)
    }

    // Paste: capture insertion point and enforce caret position after paste across async updates.
    override func paste(_ sender: Any?) {
        // Capture where paste begins (start of insertion/replacement)
        pendingPasteCaretLocation = selectedRange().location

        // Keep your existing notification behavior
        let pastedString = NSPasteboard.general.string(forType: .string)

        super.paste(sender)

        if let pastedString, !pastedString.isEmpty {
            NotificationCenter.default.post(name: .pastedText, object: pastedString)
        }

        // Enforce caret after paste (multiple ticks beats late selection changes)
        schedulePasteCaretEnforcement()
    }

    override func didChangeText() {
        super.didChangeText()
        // Pasting triggers didChangeText; schedule enforcement again.
        schedulePasteCaretEnforcement()
    }

    // Re-apply the desired caret position over multiple runloop ticks to beat late layout/async work.
    private func schedulePasteCaretEnforcement() {
        guard pendingPasteCaretLocation != nil else { return }

        // Cancel previously queued enforcement to avoid spamming
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(applyPendingPasteCaret), object: nil)

        // Run next turn
        perform(#selector(applyPendingPasteCaret), with: nil, afterDelay: 0)

        // Run again next runloop tick (beats "snap back" from late async work)
        DispatchQueue.main.async { [weak self] in
            self?.applyPendingPasteCaret()
        }

        // Run once more with a tiny delay (beats slower async highlight passes)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            self?.applyPendingPasteCaret()
        }
    }

    @objc private func applyPendingPasteCaret() {
        guard let desired = pendingPasteCaretLocation else { return }

        let length = (string as NSString).length
        let loc = min(max(0, desired), length)
        let range = NSRange(location: loc, length: 0)

        // Set caret and keep it visible
        setSelectedRange(range)

        if let container = textContainer {
            layoutManager?.ensureLayout(for: container)
        }
        scrollRangeToVisible(range)

        // Important: clear only after we've enforced at least once.
        // The delayed calls will no-op once this is nil.
        pendingPasteCaretLocation = nil
    }
}

// NSViewRepresentable wrapper around NSTextView to integrate with SwiftUI.
struct CustomTextEditor: NSViewRepresentable {
    @Binding var text: String
    let language: String
    let colorScheme: ColorScheme
    let fontSize: CGFloat
    @Binding var isLineWrapEnabled: Bool
    let translucentBackgroundEnabled: Bool

    // Toggle soft-wrapping by adjusting text container sizing and scroller visibility.
    private func applyWrapMode(isWrapped: Bool, textView: NSTextView, scrollView: NSScrollView) {
        if isWrapped {
            // Wrap: track the text view width, no horizontal scrolling
            textView.isHorizontallyResizable = false
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.heightTracksTextView = false
            scrollView.hasHorizontalScroller = false
            // Ensure the container width matches the visible content width right now
            let contentWidth = scrollView.contentSize.width
            let width = contentWidth > 0 ? contentWidth : scrollView.frame.size.width
            textView.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        } else {
            // No wrap: allow horizontal expansion and horizontal scrolling
            textView.isHorizontallyResizable = true
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.heightTracksTextView = false
            scrollView.hasHorizontalScroller = true
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }

        // Force layout update so the change takes effect immediately
        if let container = textView.textContainer, let lm = textView.layoutManager {
            lm.invalidateLayout(forCharacterRange: NSRange(location: 0, length: (textView.string as NSString).length), actualCharacterRange: nil)
            lm.ensureLayout(for: container)
        }
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    func makeNSView(context: Context) -> NSScrollView {
        // Build scroll view and text view
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        scrollView.hasVerticalScroller = true
        scrollView.contentView.postsBoundsChangedNotifications = true

        let textView = AcceptingTextView(frame: .zero)
        // Configure editing behavior and visuals
        textView.isEditable = true
        textView.isRichText = false
        textView.usesFindBar = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        if translucentBackgroundEnabled {
            textView.backgroundColor = .clear
            textView.drawsBackground = false
        } else {
            textView.backgroundColor = .textBackgroundColor
            textView.drawsBackground = true
        }

        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor

        // Disable smart substitutions/detections that can interfere with selection when recoloring
        textView.isAutomaticTextCompletionEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false

        textView.registerForDraggedTypes([.fileURL, .URL])

        // Embed the text view in the scroll view
        scrollView.documentView = textView

        // Configure the text view delegate
        textView.delegate = context.coordinator

        // Install line number ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        scrollView.verticalRulerView = LineNumberRulerView(textView: textView)

        // Apply wrapping and seed initial content
        applyWrapMode(isWrapped: isLineWrapEnabled, textView: textView, scrollView: scrollView)

        // Seed initial text
        textView.string = text
        DispatchQueue.main.async { [weak scrollView, weak textView] in
            guard let sv = scrollView, let tv = textView else { return }
            sv.window?.makeFirstResponder(tv)
        }
        context.coordinator.scheduleHighlightIfNeeded(currentText: text)

        // Keep container width in sync when the scroll view resizes
        NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: scrollView.contentView, queue: .main) { [weak textView, weak scrollView] _ in
            guard let tv = textView, let sv = scrollView else { return }
            if tv.textContainer?.widthTracksTextView == true {
                tv.textContainer?.containerSize.width = sv.contentSize.width
                if let container = tv.textContainer {
                    tv.layoutManager?.ensureLayout(for: container)
                }
            }
        }

        context.coordinator.textView = textView
        return scrollView
    }

    // Keep NSTextView in sync with SwiftUI state and schedule highlighting when needed.
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        if let textView = nsView.documentView as? NSTextView {
            if textView.string != text {
                textView.string = text
            }
            if textView.font?.pointSize != fontSize {
                textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            }
            // Background color adjustments for translucency
            if translucentBackgroundEnabled {
                nsView.drawsBackground = false
                textView.backgroundColor = .clear
                textView.drawsBackground = false
            } else {
                nsView.drawsBackground = false
                textView.backgroundColor = .textBackgroundColor
                textView.drawsBackground = true
            }
            // Keep the text container width in sync & relayout
            applyWrapMode(isWrapped: isLineWrapEnabled, textView: textView, scrollView: nsView)

            // Force immediate reflow after toggling wrap
            if let container = textView.textContainer, let lm = textView.layoutManager {
                lm.invalidateLayout(forCharacterRange: NSRange(location: 0, length: (textView.string as NSString).length), actualCharacterRange: nil)
                lm.ensureLayout(for: container)
            }

            textView.invalidateIntrinsicContentSize()
            nsView.reflectScrolledClipView(nsView.contentView)

            // Only schedule highlight if needed (e.g., language/color scheme changes or external text updates)
            context.coordinator.parent = self
            context.coordinator.scheduleHighlightIfNeeded()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // Coordinator: NSTextViewDelegate that bridges NSText changes to SwiftUI and manages highlighting.
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CustomTextEditor
        weak var textView: NSTextView?

        // Background queue + debouncer for regex-based highlighting
        private let highlightQueue = DispatchQueue(label: "NeonVision.SyntaxHighlight", qos: .userInitiated)
        // Snapshots of last highlighted state to avoid redundant work
        private var pendingHighlight: DispatchWorkItem?
        private var lastHighlightedText: String = ""
        private var lastLanguage: String?
        private var lastColorScheme: ColorScheme?

        init(_ parent: CustomTextEditor) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(moveToLine(_:)), name: .moveCursorToLine, object: nil)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        /// Schedules highlighting if text/language/theme changed. Skips very large documents
        /// and defers when a modal sheet is presented.
        func scheduleHighlightIfNeeded(currentText: String? = nil) {
            guard textView != nil else { return }

            // Query NSApp.modalWindow on the main thread to avoid thread-check warnings
            let isModalPresented: Bool = {
                if Thread.isMainThread {
                    return NSApp.modalWindow != nil
                } else {
                    var result = false
                    DispatchQueue.main.sync { result = (NSApp.modalWindow != nil) }
                    return result
                }
            }()

            if isModalPresented {
                pendingHighlight?.cancel()
                let work = DispatchWorkItem { [weak self] in
                    self?.scheduleHighlightIfNeeded(currentText: currentText)
                }
                pendingHighlight = work
                highlightQueue.asyncAfter(deadline: .now() + 0.3, execute: work)
                return
            }

            let lang = parent.language
            let scheme = parent.colorScheme
            let text: String = {
                if let currentText = currentText {
                    return currentText
                }

                if Thread.isMainThread {
                    return textView?.string ?? ""
                }

                var result = ""
                DispatchQueue.main.sync {
                    result = textView?.string ?? ""
                }
                return result
            }()

            // Skip expensive highlighting for very large documents
            let nsLen = (text as NSString).length
            if nsLen > 200_000 { // ~200k UTF-16 code units
                self.lastHighlightedText = text
                self.lastLanguage = lang
                self.lastColorScheme = scheme
                return
            }

            if text == lastHighlightedText && lastLanguage == lang && lastColorScheme == scheme {
                return
            }
            rehighlight()
        }

        /// Perform regex-based token coloring off-main, then apply attributes on the main thread.
        func rehighlight() {
            guard let textView = textView else { return }
            // Snapshot current state
            let textSnapshot = textView.string
            let language = parent.language
            let scheme = parent.colorScheme
            let selected = textView.selectedRange()
            let colors = SyntaxColors.fromVibrantLightTheme(colorScheme: scheme)
            let patterns = getSyntaxPatterns(for: language, colors: colors)

            // Cancel any in-flight work
            pendingHighlight?.cancel()

            let work = DispatchWorkItem { [weak self] in
                // Compute matches off the main thread
                let nsText = textSnapshot as NSString
                let fullRange = NSRange(location: 0, length: nsText.length)
                var coloredRanges: [(NSRange, Color)] = []
                for (pattern, color) in patterns {
                    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { continue }
                    let matches = regex.matches(in: textSnapshot, range: fullRange)
                    for match in matches {
                        coloredRanges.append((match.range, color))
                    }
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self = self, let tv = self.textView else { return }
                    // Discard if text changed since we started
                    guard tv.string == textSnapshot else { return }

                    tv.textStorage?.beginEditing()
                    // Clear previous coloring and apply base color
                    tv.textStorage?.removeAttribute(.foregroundColor, range: fullRange)
                    tv.textStorage?.addAttribute(.foregroundColor, value: tv.textColor ?? NSColor.labelColor, range: fullRange)
                    // Apply colored ranges
                    for (range, color) in coloredRanges {
                        tv.textStorage?.addAttribute(.foregroundColor, value: NSColor(color), range: range)
                    }
                    tv.textStorage?.endEditing()

                    // Restore selection only if it hasn't changed since we started
                    if NSEqualRanges(tv.selectedRange(), selected) {
                        tv.setSelectedRange(selected)
                    }

                    // Update last highlighted state
                    self.lastHighlightedText = textSnapshot
                    self.lastLanguage = language
                    self.lastColorScheme = scheme
                }
            }

            pendingHighlight = work
            // Debounce slightly to avoid thrashing while typing
            highlightQueue.asyncAfter(deadline: .now() + 0.12, execute: work)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            // Update SwiftUI binding, caret status, and rehighlight.
            parent.text = textView.string
            updateCaretStatusAndHighlight()
            scheduleHighlightIfNeeded(currentText: parent.text)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            updateCaretStatusAndHighlight()
        }

        // Compute (line, column), broadcast, and highlight the current line.
        private func updateCaretStatusAndHighlight() {
            guard let tv = textView else { return }
            let ns = tv.string as NSString
            let sel = tv.selectedRange()
            let location = sel.location
            let prefix = ns.substring(to: min(location, ns.length))
            let line = prefix.reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
            let col: Int = {
                if let lastNL = prefix.lastIndex(of: "\n") {
                    return prefix.distance(from: lastNL, to: prefix.endIndex) - 1
                } else {
                    return prefix.count
                }
            }()
            NotificationCenter.default.post(name: .caretPositionDidChange, object: nil, userInfo: ["line": line, "column": col])

            // Highlight current line
            let lineRange = ns.lineRange(for: NSRange(location: location, length: 0))
            let fullRange = NSRange(location: 0, length: ns.length)
            tv.textStorage?.beginEditing()
            tv.textStorage?.removeAttribute(.backgroundColor, range: fullRange)
            tv.textStorage?.addAttribute(.backgroundColor, value: NSColor.selectedTextBackgroundColor.withAlphaComponent(0.12), range: lineRange)
            tv.textStorage?.endEditing()
        }

        /// Move caret to a 1-based line number, clamping to bounds, and emphasize the line.
        @objc func moveToLine(_ notification: Notification) {
            guard let lineOneBased = notification.object as? Int,
                  let textView = textView else { return }

            // If there's no text, nothing to do
            let currentText = textView.string
            guard !currentText.isEmpty else { return }

            // Cancel any in-flight highlight to prevent it from restoring an old selection
            pendingHighlight?.cancel()

            // Work with NSString/UTF-16 indices to match NSTextView expectations
            let ns = currentText as NSString
            let totalLength = ns.length

            // Clamp target line to available line count (1-based input)
            let linesArray = currentText.components(separatedBy: .newlines)
            let clampedLineIndex = max(1, min(lineOneBased, linesArray.count)) - 1 // 0-based index

            // Compute the UTF-16 location by summing UTF-16 lengths of preceding lines + newline characters
            var location = 0
            if clampedLineIndex > 0 {
                for i in 0..<(clampedLineIndex) {
                    let lineNSString = linesArray[i] as NSString
                    location += lineNSString.length
                    // Add one for the newline that separates lines, as components(separatedBy:) drops separators
                    location += 1
                }
            }
            // Safety clamp
            location = max(0, min(location, totalLength))

            // Move caret and scroll into view on the main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let tv = self.textView else { return }
                tv.window?.makeFirstResponder(tv)
                // Ensure layout is up-to-date before scrolling
                if let textContainer = tv.textContainer {
                    tv.layoutManager?.ensureLayout(for: textContainer)
                }
                tv.setSelectedRange(NSRange(location: location, length: 0))
                tv.scrollRangeToVisible(NSRange(location: location, length: 0))

                // Stronger highlight for the entire target line
                let lineRange = ns.lineRange(for: NSRange(location: location, length: 0))
                let fullRange = NSRange(location: 0, length: totalLength)
                tv.textStorage?.beginEditing()
                tv.textStorage?.removeAttribute(.backgroundColor, range: fullRange)
                tv.textStorage?.addAttribute(.backgroundColor, value: NSColor.selectedTextBackgroundColor.withAlphaComponent(0.18), range: lineRange)
                tv.textStorage?.endEditing()
            }
        }
    }
}
#else
import UIKit

final class LineNumberedTextViewContainer: UIView {
    let lineNumberView = UITextView()
    let textView = UITextView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        lineNumberView.translatesAutoresizingMaskIntoConstraints = false
        textView.translatesAutoresizingMaskIntoConstraints = false

        lineNumberView.isEditable = false
        lineNumberView.isSelectable = false
        lineNumberView.isScrollEnabled = true
        lineNumberView.isUserInteractionEnabled = false
        lineNumberView.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.65)
        lineNumberView.textColor = .secondaryLabel
        lineNumberView.textAlignment = .right
        lineNumberView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 6)
        lineNumberView.textContainer.lineFragmentPadding = 0

        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = UIColor.separator.withAlphaComponent(0.6)

        addSubview(lineNumberView)
        addSubview(divider)
        addSubview(textView)

        NSLayoutConstraint.activate([
            lineNumberView.leadingAnchor.constraint(equalTo: leadingAnchor),
            lineNumberView.topAnchor.constraint(equalTo: topAnchor),
            lineNumberView.bottomAnchor.constraint(equalTo: bottomAnchor),
            lineNumberView.widthAnchor.constraint(equalToConstant: 46),

            divider.leadingAnchor.constraint(equalTo: lineNumberView.trailingAnchor),
            divider.topAnchor.constraint(equalTo: topAnchor),
            divider.bottomAnchor.constraint(equalTo: bottomAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),

            textView.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor),
            textView.topAnchor.constraint(equalTo: topAnchor),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateLineNumbers(for text: String, fontSize: CGFloat) {
        let lineCount = max(1, text.components(separatedBy: .newlines).count)
        let numbers = (1...lineCount).map(String.init).joined(separator: "\n")
        lineNumberView.font = UIFont.monospacedDigitSystemFont(ofSize: max(11, fontSize - 1), weight: .regular)
        lineNumberView.text = numbers
    }
}

struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    let language: String
    let colorScheme: ColorScheme
    let fontSize: CGFloat
    @Binding var isLineWrapEnabled: Bool
    let translucentBackgroundEnabled: Bool

    func makeUIView(context: Context) -> LineNumberedTextViewContainer {
        let container = LineNumberedTextViewContainer()
        let textView = container.textView

        textView.delegate = context.coordinator
        textView.font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.text = text
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.backgroundColor = translucentBackgroundEnabled ? .clear : .systemBackground
        textView.textContainer.lineBreakMode = isLineWrapEnabled ? .byWordWrapping : .byClipping
        textView.textContainer.widthTracksTextView = isLineWrapEnabled

        container.updateLineNumbers(for: text, fontSize: fontSize)
        context.coordinator.container = container
        context.coordinator.textView = textView
        context.coordinator.scheduleHighlightIfNeeded(currentText: text)
        return container
    }

    func updateUIView(_ uiView: LineNumberedTextViewContainer, context: Context) {
        let textView = uiView.textView
        context.coordinator.parent = self
        if textView.text != text {
            textView.text = text
        }
        if textView.font?.pointSize != fontSize {
            textView.font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
        textView.backgroundColor = translucentBackgroundEnabled ? .clear : .systemBackground
        textView.textContainer.lineBreakMode = isLineWrapEnabled ? .byWordWrapping : .byClipping
        textView.textContainer.widthTracksTextView = isLineWrapEnabled
        uiView.updateLineNumbers(for: text, fontSize: fontSize)
        context.coordinator.syncLineNumberScroll()
        context.coordinator.scheduleHighlightIfNeeded(currentText: text)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: CustomTextEditor
        weak var container: LineNumberedTextViewContainer?
        weak var textView: UITextView?
        private let highlightQueue = DispatchQueue(label: "NeonVision.iOS.SyntaxHighlight", qos: .userInitiated)
        private var pendingHighlight: DispatchWorkItem?
        private var lastHighlightedText: String = ""
        private var lastLanguage: String?
        private var lastColorScheme: ColorScheme?
        private var isApplyingHighlight = false

        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }

        func scheduleHighlightIfNeeded(currentText: String? = nil) {
            guard let textView else { return }
            let text = currentText ?? textView.text ?? ""
            let lang = parent.language
            let scheme = parent.colorScheme

            if text == lastHighlightedText && lang == lastLanguage && scheme == lastColorScheme {
                return
            }

            pendingHighlight?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.rehighlight(text: text, language: lang, colorScheme: scheme)
            }
            pendingHighlight = work
            highlightQueue.asyncAfter(deadline: .now() + 0.1, execute: work)
        }

        private func rehighlight(text: String, language: String, colorScheme: ColorScheme) {
            let nsText = text as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)
            let baseColor: UIColor = colorScheme == .dark ? .white : .label
            let baseFont = UIFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .regular)

            let attributed = NSMutableAttributedString(
                string: text,
                attributes: [
                    .foregroundColor: baseColor,
                    .font: baseFont
                ]
            )

            let colors = SyntaxColors.fromVibrantLightTheme(colorScheme: colorScheme)
            let patterns = getSyntaxPatterns(for: language, colors: colors)

            for (pattern, color) in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { continue }
                let matches = regex.matches(in: text, range: fullRange)
                let uiColor = UIColor(color)
                for match in matches {
                    attributed.addAttribute(.foregroundColor, value: uiColor, range: match.range)
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self, let textView = self.textView else { return }
                guard textView.text == text else { return }
                let selectedRange = textView.selectedRange
                self.isApplyingHighlight = true
                textView.attributedText = attributed
                textView.selectedRange = selectedRange
                textView.typingAttributes = [
                    .foregroundColor: baseColor,
                    .font: baseFont
                ]
                self.isApplyingHighlight = false
                self.lastHighlightedText = text
                self.lastLanguage = language
                self.lastColorScheme = colorScheme
                self.container?.updateLineNumbers(for: text, fontSize: self.parent.fontSize)
                self.syncLineNumberScroll()
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isApplyingHighlight else { return }
            parent.text = textView.text
            container?.updateLineNumbers(for: textView.text, fontSize: parent.fontSize)
            scheduleHighlightIfNeeded(currentText: textView.text)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            syncLineNumberScroll()
        }

        func syncLineNumberScroll() {
            guard let textView, let lineView = container?.lineNumberView else { return }
            lineView.contentOffset = CGPoint(x: 0, y: textView.contentOffset.y)
        }
    }
}
#endif
