import AppKit
import UniformTypeIdentifiers

final class ImageCanvasView: NSView, NSMenuItemValidation {
    var onOpenImage: ((URL) -> Void)?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    private static let availableMagnifierZooms = [6, 8, 12, 16]
    private static let defaultMagnifierZoom = 12
    private static let magnifierZoomDefaultsKey = "MagnifierZoom"
    private static let magnifierPreviewSide: CGFloat = 132

    /// Discrete image zoom steps. `1.0` is the "fit in window" default.
    private static let imageZoomSteps: [CGFloat] = [
        0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0, 6.0
    ]
    private static let defaultImageZoom: CGFloat = 1.0
    private static let minimumImageZoom = imageZoomSteps[0]
    private static let maximumImageZoom = imageZoomSteps[imageZoomSteps.count - 1]

    private let image: NSImage
    private let pixelSize: CGSize
    private var magnifierZoom: Int
    private var imageZoom: CGFloat = 1.0
    private var panOffset: CGPoint = .zero
    private var mouseLocation: CGPoint?
    private var coordinate: PixelCoordinate?
    private var trackingAreaReference: NSTrackingArea?

    private var baseImageRect: CGRect {
        ImageGeometry.aspectFitRect(imageSize: pixelSize, in: bounds)
    }

    private var renderedImageRect: CGRect {
        ImageGeometry.scaledImageRect(
            baseFit: baseImageRect,
            in: bounds,
            zoom: imageZoom,
            panOffset: panOffset
        )
    }

    init(loadedImage: LoadedImage) {
        image = loadedImage.image
        pixelSize = loadedImage.pixelSize
        let savedZoom = UserDefaults.standard.integer(forKey: Self.magnifierZoomDefaultsKey)
        magnifierZoom = Self.availableMagnifierZooms.contains(savedZoom)
            ? savedZoom
            : Self.defaultMagnifierZoom
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateTrackingAreas() {
        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }

        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaReference = area
        super.updateTrackingAreas()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor(calibratedWhite: 0.10, alpha: 1).setFill()
        dirtyRect.fill()

        let imageRect = renderedImageRect
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: imageRect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )

        if let mouseLocation, let coordinate {
            drawGuideLines(at: mouseLocation, in: imageRect)
            drawCrosshair(at: mouseLocation)
            drawMagnifier(for: coordinate, beside: mouseLocation)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        window?.makeFirstResponder(self)
        updateCoordinate(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        window?.makeFirstResponder(self)
        updateCoordinate(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        mouseLocation = nil
        coordinate = nil
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        let delta: (x: Int, y: Int)
        switch event.keyCode {
        case 123:
            delta = (-1, 0)
        case 124:
            delta = (1, 0)
        case 125:
            delta = (0, 1)
        case 126:
            delta = (0, -1)
        default:
            super.keyDown(with: event)
            return
        }

        guard let coordinate,
              let adjustedCoordinate = ImageGeometry.offsetPixelCoordinate(
                coordinate,
                deltaX: delta.x,
                deltaY: delta.y,
                pixelSize: pixelSize
              ),
              let adjustedLocation = ImageGeometry.centerPoint(
                of: adjustedCoordinate,
                in: renderedImageRect,
                pixelSize: pixelSize
              ) else {
            super.keyDown(with: event)
            return
        }

        self.coordinate = adjustedCoordinate
        mouseLocation = adjustedLocation
        needsDisplay = true
    }

    @objc func setMagnifierZoom(_ sender: NSMenuItem) {
        guard Self.availableMagnifierZooms.contains(sender.tag) else { return }
        magnifierZoom = sender.tag
        UserDefaults.standard.set(sender.tag, forKey: Self.magnifierZoomDefaultsKey)
        needsDisplay = true
    }

    @objc func zoomIn() {
        applyZoomStep(by: 1, focusPoint: CGPoint(x: bounds.midX, y: bounds.midY))
    }

    @objc func zoomOut() {
        applyZoomStep(by: -1, focusPoint: CGPoint(x: bounds.midX, y: bounds.midY))
    }

    @objc func resetZoom() {
        applyZoom(Self.defaultImageZoom, focusPoint: CGPoint(x: bounds.midX, y: bounds.midY))
    }

    private func applyZoomStep(by delta: Int, focusPoint: CGPoint) {
        let zoom: CGFloat?
        if delta > 0 {
            zoom = Self.imageZoomSteps.first { $0 > imageZoom }
        } else if delta < 0 {
            zoom = Self.imageZoomSteps.last { $0 < imageZoom }
        } else {
            zoom = nil
        }

        if let zoom {
            applyZoom(zoom, focusPoint: focusPoint)
        }
    }

    private func applyZoom(_ zoom: CGFloat, focusPoint: CGPoint) {
        guard zoom != imageZoom else { return }
        let newOffset = ImageGeometry.panOffsetForZoom(
            fromZoom: imageZoom,
            toZoom: zoom,
            focusPoint: focusPoint,
            baseFit: baseImageRect,
            bounds: bounds,
            oldPanOffset: panOffset
        )
        imageZoom = zoom
        panOffset = newOffset
        window?.invalidateCursorRects(for: self)
        refreshCoordinateAfterTransform()
    }

    override func magnify(with event: NSEvent) {
        let focusPoint = convert(event.locationInWindow, from: nil)
        let zoom = min(
            max(imageZoom + event.magnification, Self.minimumImageZoom),
            Self.maximumImageZoom
        )
        applyZoom(zoom, focusPoint: focusPoint)
    }

    override func scrollWheel(with event: NSEvent) {
        // Only pan when the image is actually zoomed in; otherwise let macOS
        // do whatever it wants with the event (e.g. nothing).
        guard imageZoom > Self.defaultImageZoom else {
            super.scrollWheel(with: event)
            return
        }

        let deltaX: CGFloat
        let deltaY: CGFloat
        if event.hasPreciseScrollingDeltas {
            deltaX = event.scrollingDeltaX
            deltaY = event.scrollingDeltaY
        } else {
            deltaX = event.deltaX * 10
            deltaY = event.deltaY * 10
        }
        guard deltaX != 0 || deltaY != 0 else {
            super.scrollWheel(with: event)
            return
        }

        // AppKit's scrolling deltas already respect the system's scroll-direction
        // preference. Apply them directly so the image follows the fingers.
        panOffset = ImageGeometry.clampPanOffset(
            CGPoint(x: panOffset.x + deltaX, y: panOffset.y + deltaY),
            bounds: bounds,
            displayedSize: CGSize(
                width: baseImageRect.width * imageZoom,
                height: baseImageRect.height * imageZoom
            )
        )
        refreshCoordinateAfterTransform()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.action == #selector(setMagnifierZoom(_:)) else {
            return true
        }

        menuItem.state = menuItem.tag == magnifierZoom ? .on : .off
        return Self.availableMagnifierZooms.contains(menuItem.tag)
    }

    override func resetCursorRects() {
        addCursorRect(renderedImageRect, cursor: .crosshair)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        window?.invalidateCursorRects(for: self)

        // Re-clamp the pan offset so a shrinking viewport can't leave the
        // zoomed image permanently parked outside the visible area.
        let displayedSize = CGSize(
            width: baseImageRect.width * imageZoom,
            height: baseImageRect.height * imageZoom
        )
        panOffset = ImageGeometry.clampPanOffset(
            panOffset,
            bounds: CGRect(origin: .zero, size: newSize),
            displayedSize: displayedSize
        )

        guard let window else { return }
        updateCoordinate(at: convert(window.mouseLocationOutsideOfEventStream, from: nil))
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        imageURL(from: sender) == nil ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = imageURL(from: sender) else { return false }
        onOpenImage?(url)
        return true
    }

    private func updateCoordinate(at location: CGPoint) {
        guard bounds.contains(location) else {
            mouseLocation = nil
            coordinate = nil
            needsDisplay = true
            return
        }

        let newCoordinate = ImageGeometry.pixelCoordinate(
            at: location,
            in: renderedImageRect,
            pixelSize: pixelSize
        )

        // Keep the pointer location while it remains inside the canvas. A pan
        // can move the image out from under it and back again without another
        // mouse-moved event being delivered.
        mouseLocation = location
        coordinate = newCoordinate
        needsDisplay = true
    }

    private func refreshCoordinateAfterTransform() {
        if let mouseLocation {
            updateCoordinate(at: mouseLocation)
        } else {
            needsDisplay = true
        }
    }

    private func drawGuideLines(at point: CGPoint, in imageRect: CGRect) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: imageRect).addClip()

        let path = NSBezierPath()
        path.lineWidth = 1
        path.setLineDash([5, 4], count: 2, phase: 0)
        path.move(to: CGPoint(x: imageRect.minX, y: point.y))
        path.line(to: CGPoint(x: imageRect.maxX, y: point.y))
        path.move(to: CGPoint(x: point.x, y: imageRect.minY))
        path.line(to: CGPoint(x: point.x, y: imageRect.maxY))

        NSColor.black.withAlphaComponent(0.65).setStroke()
        path.lineWidth = 3
        path.stroke()

        NSColor.white.withAlphaComponent(0.85).setStroke()
        path.lineWidth = 1
        path.stroke()

        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawCrosshair(at point: CGPoint) {
        NSColor.white.withAlphaComponent(0.9).setStroke()
        let path = NSBezierPath()
        path.lineWidth = 1
        path.move(to: CGPoint(x: point.x - 6, y: point.y))
        path.line(to: CGPoint(x: point.x + 6, y: point.y))
        path.move(to: CGPoint(x: point.x, y: point.y - 6))
        path.line(to: CGPoint(x: point.x, y: point.y + 6))
        path.stroke()
    }

    private func drawMagnifier(for coordinate: PixelCoordinate, beside point: CGPoint) {
        let estimatedSampleSide = max(
            3,
            Int(Self.magnifierPreviewSide) / magnifierZoom
        )
        let sampleSide = estimatedSampleSide.isMultiple(of: 2)
            ? estimatedSampleSide - 1
            : estimatedSampleSide
        guard let sample = ImageGeometry.pixelSampleWindow(
            centeredAt: coordinate,
            pixelSize: pixelSize,
            sideLength: sampleSide
        ) else {
            return
        }

        let cellSize = CGFloat(magnifierZoom)
        let maximumPreviewSide = Self.magnifierPreviewSide
        let previewSize = CGSize(
            width: CGFloat(sample.width) * cellSize,
            height: CGFloat(sample.height) * cellSize
        )
        let text = "x: \(coordinate.x)   y: \(coordinate.y)   \(magnifierZoom)×"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: attributes)
        let contentWidth = max(maximumPreviewSide, textSize.width)
        let boxSize = CGSize(
            width: contentWidth + 16,
            height: maximumPreviewSide + textSize.height + 22
        )

        var origin = CGPoint(x: point.x + 14, y: point.y + 16)
        if origin.x + boxSize.width > bounds.maxX - 8 {
            origin.x = point.x - boxSize.width - 14
        }
        if origin.y + boxSize.height > bounds.maxY - 8 {
            origin.y = point.y - boxSize.height - 14
        }
        origin.x = min(max(origin.x, bounds.minX + 8), bounds.maxX - boxSize.width - 8)
        origin.y = min(max(origin.y, bounds.minY + 8), bounds.maxY - boxSize.height - 8)

        let boxRect = CGRect(origin: origin, size: boxSize)
        NSColor.black.withAlphaComponent(0.82).setFill()
        NSBezierPath(roundedRect: boxRect, xRadius: 6, yRadius: 6).fill()

        let previewRect = CGRect(
            x: boxRect.midX - previewSize.width / 2,
            y: boxRect.minY + 8 + (maximumPreviewSide - previewSize.height) / 2,
            width: previewSize.width,
            height: previewSize.height
        )
        let sourceRect = CGRect(
            x: sample.x,
            y: Int(pixelSize.height) - sample.y - sample.height,
            width: sample.width,
            height: sample.height
        )

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: previewRect).addClip()
        NSGraphicsContext.current?.imageInterpolation = .none
        image.draw(
            in: previewRect,
            from: sourceRect,
            operation: .copy,
            fraction: 1,
            respectFlipped: true,
            hints: nil
        )
        NSGraphicsContext.restoreGraphicsState()

        drawPixelGrid(in: previewRect, sample: sample, cellSize: cellSize)

        text.draw(
            at: CGPoint(
                x: boxRect.midX - textSize.width / 2,
                y: boxRect.maxY - textSize.height - 7
            ),
            withAttributes: attributes
        )

        NSColor.white.withAlphaComponent(0.3).setStroke()
        let border = NSBezierPath(roundedRect: boxRect, xRadius: 6, yRadius: 6)
        border.lineWidth = 1
        border.stroke()
    }

    private func drawPixelGrid(
        in previewRect: CGRect,
        sample: PixelSampleWindow,
        cellSize: CGFloat
    ) {
        let grid = NSBezierPath()
        grid.lineWidth = 0.5

        for column in 0...sample.width {
            let x = previewRect.minX + CGFloat(column) * cellSize
            grid.move(to: CGPoint(x: x, y: previewRect.minY))
            grid.line(to: CGPoint(x: x, y: previewRect.maxY))
        }
        for row in 0...sample.height {
            let y = previewRect.minY + CGFloat(row) * cellSize
            grid.move(to: CGPoint(x: previewRect.minX, y: y))
            grid.line(to: CGPoint(x: previewRect.maxX, y: y))
        }

        NSColor.black.withAlphaComponent(0.45).setStroke()
        grid.stroke()

        let focusRect = CGRect(
            x: previewRect.minX + CGFloat(sample.focusColumn) * cellSize,
            y: previewRect.minY + CGFloat(sample.focusRow) * cellSize,
            width: cellSize,
            height: cellSize
        ).insetBy(dx: 1, dy: 1)
        NSColor.systemYellow.setStroke()
        let focusBorder = NSBezierPath(rect: focusRect)
        focusBorder.lineWidth = 2
        focusBorder.stroke()
    }

    private func imageURL(from draggingInfo: NSDraggingInfo) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        guard let urls = draggingInfo.draggingPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: options
        ) as? [URL] else {
            return nil
        }

        return urls.first { url in
            guard let type = UTType(filenameExtension: url.pathExtension) else {
                return false
            }
            return type.conforms(to: .image)
        }
    }
}
