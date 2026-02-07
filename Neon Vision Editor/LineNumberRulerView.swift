//
//  LineNumberRulerView.swift
//  Neon Vision Editor
//
//  Created by h3pdesign on 06.02.26.
//


#if os(macOS)
import AppKit

final class LineNumberRulerView: NSRulerView {
    weak var textView: NSTextView?

    private let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
    private let textColor = NSColor.secondaryLabelColor
    private let inset: CGFloat = 6

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.clientView = textView
        self.ruleThickness = 48

        // Ensure we get bounds-changed notifications while scrolling
        textView.enclosingScrollView?.contentView.postsBoundsChangedNotifications = true

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(needsRedraw),
            name: NSView.boundsDidChangeNotification,
            object: textView.enclosingScrollView?.contentView
        )
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func needsRedraw() {
        needsDisplay = true
    }
    
    // Keep the ruler transparent so the window's translucency/vibrancy shows through.
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        // Do not paint an opaque background.
        NSColor.clear.setFill()
        dirtyRect.fill()

        // Draw only the ruler contents (line numbers).
        drawHashMarksAndLabels(in: dirtyRect)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard
            let tv = textView,
            let lm = tv.layoutManager
        else { return }

        let fullString = tv.string as NSString
        let visibleRect = tv.visibleRect
        let tcOrigin = tv.textContainerOrigin  // Accounts for textContainerInset

        // Find the first visible character using a probe point inside the text container
        // (not inside the left inset / ruler area)
        let probePoint = NSPoint(x: tcOrigin.x + 2, y: visibleRect.minY + 2)
        let firstVisibleCharIndex = tv.characterIndexForInsertion(at: probePoint)
        let clampedCharIndex = min(max(firstVisibleCharIndex, 0), fullString.length)

        // Compute the line number of the first visible logical line
        // by counting newline characters up to the visible character index
        let prefix = fullString.substring(to: clampedCharIndex)
        var currentLineNumber = prefix.reduce(1) { $1 == "\n" ? $0 + 1 : $0 }

        // Start at the logical line containing the first visible character
        var charIndex = fullString.lineRange(
            for: NSRange(location: clampedCharIndex, length: 0)
        ).location

        while charIndex < fullString.length {
            let lineRange = fullString.lineRange(
                for: NSRange(location: charIndex, length: 0)
            )

            // Ensure layout information is available for this logical line
            lm.ensureLayout(forCharacterRange: lineRange)

            let glyphRange = lm.glyphRange(
                forCharacterRange: lineRange,
                actualCharacterRange: nil
            )

            if glyphRange.location >= lm.numberOfGlyphs { break }

            var effectiveGlyphRange = NSRange(location: 0, length: 0)

            // Get the visual rect for the first glyph of the logical line
            let lineRectInContainer = lm.lineFragmentRect(
                forGlyphAt: glyphRange.location,
                effectiveRange: &effectiveGlyphRange,
                withoutAdditionalLayout: false
            )

            // Convert from text container coordinates to view coordinates
            let lineRectInView = NSRect(
                x: lineRectInContainer.origin.x + tcOrigin.x,
                y: lineRectInContainer.origin.y + tcOrigin.y,
                width: lineRectInContainer.size.width,
                height: lineRectInContainer.size.height
            )

            // Stop once we are below the visible viewport
            if lineRectInView.minY > visibleRect.maxY { break }

            // Draw only lines that intersect the visible area
            if lineRectInView.maxY >= visibleRect.minY {
                let numberString = NSString(string: "\(currentLineNumber)")
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: textColor
                ]
                let size = numberString.size(withAttributes: attributes)

                // Position the line number vertically centered relative to the line fragment
                let drawY =
                    (lineRectInView.minY - visibleRect.minY)
                    + bounds.minY
                    + (lineRectInView.height - size.height) / 2.0

                let drawPoint = NSPoint(
                    x: bounds.maxX - size.width - inset,
                    y: drawY
                )

                numberString.draw(at: drawPoint, withAttributes: attributes)
            }

            // Advance to the next logical line
            charIndex = lineRange.upperBound
            currentLineNumber += 1
        }
    }
}
#endif
