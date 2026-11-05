import AppKit

@MainActor
enum StatusImage {
    static let fanSymbol = NSImage(systemSymbolName: "fanblades.fill", accessibilityDescription: "Fan")?
        .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 8, weight: .semibold))

    private static let topFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
    private static let bottomFont = NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .medium)
    private static let lineGap: CGFloat = 2.5
    private static let fanGap: CGFloat = 1.5

    /// With `reservesFan`, leaves a square slot for `fanSymbol` before the bottom line and returns its frame.
    static func make(top: String, bottom: String, reservesFan: Bool = false) -> (image: NSImage, fanFrame: NSRect?) {
        let topText = NSAttributedString(string: top, attributes: [.font: topFont])
        let bottomText = NSAttributedString(string: bottom, attributes: [.font: bottomFont])
        // A square slot lets the blades rotate without clipping.
        let fanSide = reservesFan ? fanSymbol.map { max($0.size.width, $0.size.height) } ?? 0 : 0
        let textOffset = fanSide > 0 ? fanSide + fanGap : 0
        let bottomWidth = textOffset + bottomText.size().width
        // A fixed minimum width keeps neighbouring menu bar items from shifting as digits change.
        let minimumWidth = NSAttributedString(string: "0000 rpm", attributes: [.font: bottomFont]).size().width
        let width = ceil(max(minimumWidth, topText.size().width, bottomWidth))
        let height = NSStatusBar.system.thickness

        // Centre the block from the bottom line's descender to the top line's cap height.
        let blockHeight = topFont.capHeight + lineGap + bottomFont.capHeight - bottomFont.descender
        let bottomBaseline = (height - blockHeight) / 2 - bottomFont.descender
        let topBaseline = bottomBaseline + bottomFont.capHeight + lineGap
        let bottomX = (width - bottomWidth) / 2

        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { _ in
            topText.draw(at: NSPoint(x: (width - topText.size().width) / 2, y: topBaseline + topFont.descender))
            bottomText.draw(at: NSPoint(x: bottomX + textOffset, y: bottomBaseline + bottomFont.descender))
            return true
        }
        image.isTemplate = true

        let fanFrame = fanSide > 0
            ? NSRect(x: bottomX, y: bottomBaseline + bottomFont.capHeight / 2 - fanSide / 2, width: fanSide, height: fanSide)
            : nil
        return (image, fanFrame)
    }
}
