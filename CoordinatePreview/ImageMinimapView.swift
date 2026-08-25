import AppKit

/// An interactive overview of the full image. The highlighted rectangle shows
/// the portion currently visible on the canvas and can be clicked or dragged
/// to navigate.
final class ImageMinimapView: NSView {
    var onNavigate: ((CGPoint) -> Void)?

    var normalizedViewportRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1) {
        didSet {
            guard normalizedViewportRect != oldValue else { return }
            needsDisplay = true
        }
    }

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }

    private static let contentInset: CGFloat = 8
    private static let minimumImageSide: CGFloat = 18
    private static let minimumIndicatorSide: CGFloat = 6
    private static let cornerRadius: CGFloat = 7

    private let image: NSImage
    private let pixelSize: CGSize
    private var dragAnchorFromViewportCenter: CGPoint?

    private var imageRect: CGRect {
        var fittedRect = ImageGeometry.aspectFitRect(
            imageSize: pixelSize,
            in: bounds,
            padding: Self.contentInset
        )

        // Extremely long images would otherwise become a one- or two-point
        // strip. Keep the short side large enough to remain interactive.
        if fittedRect.width > 0, fittedRect.width < Self.minimumImageSide {
            fittedRect.size.width = min(
                Self.minimumImageSide,
                max(bounds.width - Self.contentInset * 2, 0)
            )
            fittedRect.origin.x = bounds.midX - fittedRect.width / 2
        }
        if fittedRect.height > 0, fittedRect.height < Self.minimumImageSide {
            fittedRect.size.height = min(
                Self.minimumImageSide,
                max(bounds.height - Self.contentInset * 2, 0)
            )
            fittedRect.origin.y = bounds.midY - fittedRect.height / 2
        }
        return fittedRect
    }

    init(image: NSImage, pixelSize: CGSize) {
        self.image = image
        self.pixelSize = pixelSize
        super.init(frame: .zero)

        toolTip = "点击或拖动视口框以浏览图片"
        setAccessibilityElement(true)
        setAccessibilityLabel("图片导航缩略图")
        setAccessibilityHelp("点击或拖动以移动当前图片视口")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let backgroundRect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let background = NSBezierPath(
            roundedRect: backgroundRect,
            xRadius: Self.cornerRadius,
            yRadius: Self.cornerRadius
        )
        NSColor.black.withAlphaComponent(0.78).setFill()
        background.fill()

        let imageRect = imageRect
        guard imageRect.width > 0, imageRect.height > 0 else { return }

        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: imageRect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: imageRect).addClip()

        NSColor.black.withAlphaComponent(0.24).setFill()
        imageRect.fill()

        let indicatorRect = viewportIndicatorRect(in: imageRect)
        NSColor.white.withAlphaComponent(0.14).setFill()
        indicatorRect.fill()

        let indicator = NSBezierPath(rect: indicatorRect)
        indicator.lineWidth = 2
        NSColor.systemYellow.setStroke()
        indicator.stroke()

        NSGraphicsContext.restoreGraphicsState()

        let imageBorder = NSBezierPath(rect: imageRect)
        imageBorder.lineWidth = 1
        NSColor.white.withAlphaComponent(0.28).setStroke()
        imageBorder.stroke()

        background.lineWidth = 1
        NSColor.white.withAlphaComponent(0.22).setStroke()
        background.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        guard let normalizedLocation = normalizedImagePoint(at: location, clamped: false) else {
            return
        }

        if viewportIndicatorRect(in: imageRect).contains(location) {
            dragAnchorFromViewportCenter = CGPoint(
                x: normalizedLocation.x - normalizedViewportRect.midX,
                y: normalizedLocation.y - normalizedViewportRect.midY
            )
        } else {
            dragAnchorFromViewportCenter = .zero
        }

        navigate(pointerLocation: normalizedLocation)
        window?.invalidateCursorRects(for: self)
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragAnchorFromViewportCenter != nil else { return }
        let location = convert(event.locationInWindow, from: nil)
        guard let normalizedLocation = normalizedImagePoint(at: location, clamped: true) else {
            return
        }
        navigate(pointerLocation: normalizedLocation)
    }

    override func mouseUp(with event: NSEvent) {
        dragAnchorFromViewportCenter = nil
        window?.invalidateCursorRects(for: self)
    }

    override func resetCursorRects() {
        let cursor: NSCursor = dragAnchorFromViewportCenter == nil ? .openHand : .closedHand
        addCursorRect(imageRect, cursor: cursor)
    }

    private func navigate(pointerLocation: CGPoint) {
        let anchor = dragAnchorFromViewportCenter ?? .zero
        onNavigate?(
            CGPoint(
                x: min(max(pointerLocation.x - anchor.x, 0), 1),
                y: min(max(pointerLocation.y - anchor.y, 0), 1)
            )
        )
    }

    private func normalizedImagePoint(at point: CGPoint, clamped: Bool) -> CGPoint? {
        let imageRect = imageRect
        guard imageRect.width > 0,
              imageRect.height > 0,
              clamped || imageRect.contains(point) else {
            return nil
        }

        return CGPoint(
            x: min(max((point.x - imageRect.minX) / imageRect.width, 0), 1),
            y: min(max((point.y - imageRect.minY) / imageRect.height, 0), 1)
        )
    }

    private func viewportIndicatorRect(in imageRect: CGRect) -> CGRect {
        let normalized = normalizedViewportRect
        let rawRect = CGRect(
            x: imageRect.minX + normalized.minX * imageRect.width,
            y: imageRect.minY + normalized.minY * imageRect.height,
            width: normalized.width * imageRect.width,
            height: normalized.height * imageRect.height
        )

        let width = max(rawRect.width, min(Self.minimumIndicatorSide, imageRect.width))
        let height = max(rawRect.height, min(Self.minimumIndicatorSide, imageRect.height))
        let originX = min(
            max(rawRect.midX - width / 2, imageRect.minX),
            imageRect.maxX - width
        )
        let originY = min(
            max(rawRect.midY - height / 2, imageRect.minY),
            imageRect.maxY - height
        )
        return CGRect(x: originX, y: originY, width: width, height: height)
    }
}
