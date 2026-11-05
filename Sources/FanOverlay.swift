import AppKit

/// Shows the fan symbol over the slot `StatusImage` leaves in the status item button.
/// An image view draws it, so it gets the same template tint as the button's text,
/// and a Core Animation rotation spins it without waking the app each frame.
@MainActor
final class FanOverlay: NSView {
    // The blades repeat every 90°, so at 30 fps the fastest spin (1.5 turns a second, 18° a frame) still reads clockwise.
    private static let frameRate = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
    private static let spinKey = "spin"

    private let fanView = NSImageView()
    private var imageSize = NSSize.zero
    private var fanFrame: NSRect?
    private var turnsPerSecond: Double?

    init() {
        super.init(frame: .zero)
        autoresizingMask = [.width, .height]
        fanView.image = StatusImage.fanSymbol
        fanView.imageScaling = .scaleNone
        // Gives the image view its layer now, so a spin can start before the first layout.
        fanView.wantsLayer = true
        addSubview(fanView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // Clicks fall through to the status item button underneath.
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func place(_ fanFrame: NSRect?, inImageOf imageSize: NSSize) {
        self.fanFrame = fanFrame
        self.imageSize = imageSize
        needsLayout = true
    }

    /// Spins clockwise at `turnsPerSecond`; nil holds the blades still.
    func spin(turnsPerSecond: Double?) {
        guard turnsPerSecond != self.turnsPerSecond, let layer = fanView.layer else { return }

        self.turnsPerSecond = turnsPerSecond
        // Continue from the current angle so a speed change doesn't make the blades jump.
        let angle = (layer.presentation()?.value(forKeyPath: "transform.rotation.z") as? NSNumber)?.doubleValue ?? 0
        layer.removeAnimation(forKey: Self.spinKey)
        guard let turnsPerSecond else { return }

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = angle
        rotation.toValue = angle - 2 * .pi
        rotation.duration = 1 / turnsPerSecond
        rotation.repeatCount = .infinity
        rotation.preferredFrameRateRange = Self.frameRate
        layer.add(rotation, forKey: Self.spinKey)
    }

    override func layout() {
        super.layout()
        fanView.isHidden = fanFrame == nil
        guard let fanFrame else { return }

        // NSStatusBarButton centres its image.
        fanView.frame = fanFrame.offsetBy(dx: ((bounds.width - imageSize.width) / 2).rounded(),
                                          dy: ((bounds.height - imageSize.height) / 2).rounded())
        // AppKit anchors a view's layer at its origin; the blades must turn about their centre.
        fanView.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        fanView.layer?.position = CGPoint(x: fanView.frame.midX, y: fanView.frame.midY)
    }
}
