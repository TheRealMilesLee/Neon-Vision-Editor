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
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let bg: NSColor = textView?.backgroundColor ?? .clear
        bg.setFill()
        bounds.fill()

        NSColor.separatorColor.withAlphaComponent(0.35).setFill()
        NSRect(x: bounds.maxX - 1, y: bounds.minY, width: 1, height: bounds.height).fill()

        drawHashMarksAndLabels(in: dirtyRect)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard
            let tv = textView,
            let lm = tv.layoutManager,
            let textContainer = tv.textContainer
        else { return }

        let fullString = tv.string as NSString
        let textLength = fullString.length
        let visibleRect = tv.visibleRect
        let tcOrigin = tv.textContainerOrigin
        guard textLength >= 0 else { return }
        if textLength == 0 {
            let numberString = NSString(string: "1")
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor
            ]
            let size = numberString.size(withAttributes: attributes)
            let drawPoint = NSPoint(x: bounds.maxX - size.width - inset, y: tcOrigin.y + 2)
            numberString.draw(at: drawPoint, withAttributes: attributes)
            return
        }

        let visibleRectInContainer = visibleRect.offsetBy(dx: -tcOrigin.x, dy: -tcOrigin.y)
        let visibleGlyphRange = lm.glyphRange(forBoundingRect: visibleRectInContainer, in: textContainer)
        guard visibleGlyphRange.location != NSNotFound, visibleGlyphRange.length > 0 else { return }

        var drawnLineStarts = Set<Int>()
        lm.enumerateLineFragments(forGlyphRange: visibleGlyphRange) { [self] _, usedRect, _, glyphRange, _ in
            guard glyphRange.location != NSNotFound else { return }
            let charRange = lm.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            guard charRange.location != NSNotFound, charRange.location < textLength else { return }

            let lineRange = fullString.lineRange(for: NSRange(location: charRange.location, length: 0))
            let lineStart = lineRange.location
            if drawnLineStarts.contains(lineStart) { return }
            drawnLineStarts.insert(lineStart)

            let prefix = fullString.substring(to: lineStart)
            let lineNumber = prefix.reduce(1) { $1 == "\n" ? $0 + 1 : $0 }

            let numberString = NSString(string: "\(lineNumber)")
            let attributes: [NSAttributedString.Key: Any] = [
                .font: self.font,
                .foregroundColor: self.textColor
            ]
            let size = numberString.size(withAttributes: attributes)

            let lineRectInView = NSRect(
                x: usedRect.origin.x + tcOrigin.x,
                y: usedRect.origin.y + tcOrigin.y,
                width: usedRect.size.width,
                height: usedRect.size.height
            )
            let originInRuler = self.convert(NSPoint(x: 0, y: lineRectInView.minY), from: tv)
            let drawY = originInRuler.y + (lineRectInView.height - size.height) / 2.0
            let drawPoint = NSPoint(x: self.bounds.maxX - size.width - self.inset, y: drawY)
            numberString.draw(at: drawPoint, withAttributes: attributes)
        }
    }
}
#endif
