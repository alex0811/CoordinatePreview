import AppKit
import CoreGraphics
import UniformTypeIdentifiers

final class ImageCanvasView: NSView, NSMenuItemValidation {
    var onOpenImage: ((URL) -> Void)?
    var onImageZoomChange: ((CGFloat) -> Void)? {
        didSet {
            onImageZoomChange?(imageZoom)
        }
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    private static let availableMagnifierZooms = [6, 8, 12, 16]
    private static let defaultMagnifierZoom = 12
    private static let magnifierZoomDefaultsKey = "MagnifierZoom"
    private static let magnifierPreviewSide: CGFloat = 132
    private static let imagePadding: CGFloat = 24
    private static let minimapSize = CGSize(width: 180, height: 120)
    private static let minimapMargin: CGFloat = 16

    /// Base discrete zoom steps. `1.0` is the "fit in window" default. Extra
    /// steps are appended dynamically when a long image needs more zoom to
    /// reach the rendered points-per-source-pixel limit.
    private static let imageZoomSteps: [CGFloat] = [
        0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0, 6.0, 10.0, 20.0
    ]
    private static let defaultImageZoom: CGFloat = 1.0
    private static let minimumImageZoom = imageZoomSteps[0]
    private static let minimumMaximumImageZoom = imageZoomSteps[imageZoomSteps.count - 1]
    private static let maximumRenderedPointsPerPixel: CGFloat = 20

    private let image: NSImage
    private let pixelSize: CGSize
    private let minimapView: ImageMinimapView
    private var magnifierZoom: Int
    private var imageZoom: CGFloat = 1.0
    private var panOffset: CGPoint = .zero
    private var mouseLocation: CGPoint?
    private var coordinate: PixelCoordinate?
    private var jumpedCoordinate: PixelCoordinate?
    private var trackingAreaReference: NSTrackingArea?

    var pixelYRange: ClosedRange<Int>? {
        let pixelHeight = Int(pixelSize.height.rounded())
        return pixelHeight > 0 ? 0...(pixelHeight - 1) : nil
    }

    private var baseImageRect: CGRect {
        ImageGeometry.aspectFitRect(
            imageSize: pixelSize,
            in: bounds,
            padding: Self.imagePadding
        )
    }

    private var renderedImageRect: CGRect {
        ImageGeometry.scaledImageRect(
            baseFit: baseImageRect,
            in: bounds,
            zoom: imageZoom,
            panOffset: panOffset
        )
    }

    /// Keep the existing 20× fit-relative capability, but let very tall images
    /// continue to 20 rendered points per source pixel. A 2%-fit long image,
    /// for example, can therefore reach a relative zoom of 1000×.
    private var maximumImageZoom: CGFloat {
        let renderedScaleZoom = ImageGeometry.zoomForRenderedScale(
            pointsPerPixel: Self.maximumRenderedPointsPerPixel,
            baseFit: baseImageRect,
            pixelSize: pixelSize
        ) ?? Self.minimumMaximumImageZoom
        return max(Self.minimumMaximumImageZoom, renderedScaleZoom)
    }

    private var availableImageZoomSteps: [CGFloat] {
        let maximumZoom = maximumImageZoom
        var steps = Self.imageZoomSteps
        var lastZoom = steps[steps.count - 1]

        while lastZoom < maximumZoom {
            let nextZoom = min(lastZoom * 2, maximumZoom)
            guard nextZoom > lastZoom else { break }
            steps.append(nextZoom)
            lastZoom = nextZoom
        }
        return steps
    }

    init(loadedImage: LoadedImage) {
        image = loadedImage.image
        pixelSize = loadedImage.pixelSize
        minimapView = ImageMinimapView(
            image: loadedImage.image,
            pixelSize: loadedImage.pixelSize
        )
        let savedZoom = UserDefaults.standard.integer(forKey: Self.magnifierZoomDefaultsKey)
        magnifierZoom = Self.availableMagnifierZooms.contains(savedZoom)
            ? savedZoom
            : Self.defaultMagnifierZoom
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL])

        minimapView.isHidden = true
        minimapView.onNavigate = { [weak self] normalizedPoint in
            self?.navigateUsingMinimap(to: normalizedPoint)
        }
        addSubview(minimapView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        let width = min(Self.minimapSize.width, max(bounds.width - Self.minimapMargin * 2, 0))
        let height = min(Self.minimapSize.height, max(bounds.height - Self.minimapMargin * 2, 0))
        minimapView.frame = CGRect(
            x: bounds.maxX - Self.minimapMargin - width,
            y: bounds.maxY - Self.minimapMargin - height,
            width: width,
            height: height
        ).integral
        updateMinimap()
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

        if let selection = displayedSelection(in: imageRect) {
            drawGuideLines(at: selection.location, in: imageRect)
            drawCrosshair(at: selection.location)
            drawMagnifier(for: selection.coordinate, beside: selection.location)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        window?.makeFirstResponder(self)
        jumpedCoordinate = nil
        updateCoordinate(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseEntered(with event: NSEvent) {
        window?.makeFirstResponder(self)
        jumpedCoordinate = nil
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

        guard let selectedCoordinate = coordinate ?? jumpedCoordinate,
              let adjustedCoordinate = ImageGeometry.offsetPixelCoordinate(
                selectedCoordinate,
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

        if jumpedCoordinate != nil {
            jumpedCoordinate = adjustedCoordinate
        } else {
            coordinate = adjustedCoordinate
            mouseLocation = adjustedLocation
        }
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

    func jump(toPixelY pixelY: Int) {
        let retainedPixelX = coordinate?.x ?? jumpedCoordinate?.x
        guard let pixelYRange,
              pixelYRange.contains(pixelY) else {
            return
        }

        if let fitWidthZoom = ImageGeometry.zoomToFitWidth(
            baseFit: baseImageRect,
            bounds: bounds,
            padding: Self.imagePadding
        ), fitWidthZoom > imageZoom {
            applyZoom(fitWidthZoom, focusPoint: CGPoint(x: bounds.midX, y: bounds.midY))
        }

        guard let newOffset = ImageGeometry.panOffsetCentering(
            pixelY: pixelY,
            pixelHeight: pixelYRange.upperBound + 1,
            baseFit: baseImageRect,
            bounds: bounds,
            zoom: imageZoom,
            currentPanOffset: panOffset
        ) else {
            return
        }

        panOffset = newOffset
        updateMinimap()
        let imageRect = renderedImageRect
        let visibleImageRect = imageRect.intersection(bounds)
        let fallbackCoordinate: PixelCoordinate?
        if !visibleImageRect.isNull,
           visibleImageRect.width > 0,
           let rowCenter = ImageGeometry.centerPoint(
               of: PixelCoordinate(x: 0, y: pixelY),
               in: imageRect,
               pixelSize: pixelSize
           ) {
            fallbackCoordinate = ImageGeometry.pixelCoordinate(
                at: CGPoint(x: visibleImageRect.midX, y: rowCenter.y),
                in: imageRect,
                pixelSize: pixelSize
            )
        } else {
            fallbackCoordinate = nil
        }

        guard let pixelX = retainedPixelX ?? fallbackCoordinate?.x else {
            needsDisplay = true
            return
        }

        let targetCoordinate = PixelCoordinate(x: pixelX, y: pixelY)
        jumpedCoordinate = targetCoordinate
        mouseLocation = nil
        coordinate = nil
        if let location = ImageGeometry.centerPoint(
            of: targetCoordinate,
            in: imageRect,
            pixelSize: pixelSize
        ) {
            moveMouseCursor(to: location)
        }
        needsDisplay = true
    }

    private func applyZoomStep(by delta: Int, focusPoint: CGPoint) {
        let steps = availableImageZoomSteps
        let zoom: CGFloat?
        if delta > 0 {
            zoom = steps.first { $0 > imageZoom }
        } else if delta < 0 {
            zoom = steps.last { $0 < imageZoom }
        } else {
            zoom = nil
        }

        if let zoom {
            applyZoom(zoom, focusPoint: focusPoint)
        }
    }

    private func applyZoom(_ zoom: CGFloat, focusPoint: CGPoint) {
        let zoom = min(max(zoom, Self.minimumImageZoom), maximumImageZoom)
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
        onImageZoomChange?(imageZoom)
        window?.invalidateCursorRects(for: self)
        refreshCoordinateAfterTransform()
    }

    override func magnify(with event: NSEvent) {
        let focusPoint = convert(event.locationInWindow, from: nil)
        let zoom = ImageGeometry.zoomAfterMagnification(
            currentZoom: imageZoom,
            magnification: event.magnification,
            minimumZoom: Self.minimumImageZoom,
            maximumZoom: maximumImageZoom
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
        updateMinimap()

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
        let isOverMinimap = !minimapView.isHidden && minimapView.frame.contains(location)
        guard bounds.contains(location), !isOverMinimap else {
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
        updateMinimap()
        if let mouseLocation {
            updateCoordinate(at: mouseLocation)
        } else {
            needsDisplay = true
        }
    }

    private func navigateUsingMinimap(to normalizedPoint: CGPoint) {
        guard let newOffset = ImageGeometry.panOffsetCentering(
            normalizedPoint: normalizedPoint,
            baseFit: baseImageRect,
            bounds: bounds,
            zoom: imageZoom
        ) else {
            return
        }

        panOffset = newOffset
        window?.invalidateCursorRects(for: self)
        refreshCoordinateAfterTransform()
    }

    private func updateMinimap() {
        let imageRect = renderedImageRect
        let imageOverflowsCanvas = imageRect.width > bounds.width + 0.5
            || imageRect.height > bounds.height + 0.5
        guard imageOverflowsCanvas,
              let normalizedViewport = ImageGeometry.normalizedViewportRect(
                  imageRect: imageRect,
                  viewport: bounds
              ) else {
            minimapView.isHidden = true
            return
        }

        minimapView.normalizedViewportRect = normalizedViewport
        minimapView.isHidden = false
    }

    private func displayedSelection(
        in imageRect: CGRect
    ) -> (coordinate: PixelCoordinate, location: CGPoint)? {
        if let mouseLocation, let coordinate {
            return (coordinate, mouseLocation)
        }

        guard let jumpedCoordinate,
              let location = ImageGeometry.centerPoint(
                  of: jumpedCoordinate,
                  in: imageRect,
                  pixelSize: pixelSize
              ) else {
            return nil
        }
        return (jumpedCoordinate, location)
    }

    private func moveMouseCursor(to location: CGPoint) {
        guard let window else { return }
        let windowPoint = convert(location, to: nil)
        let screenPoint = window.convertPoint(toScreen: windowPoint)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(screenPoint) })
                ?? window.screen,
              let displayNumber = screen.deviceDescription[
                  NSDeviceDescriptionKey("NSScreenNumber")
              ] as? NSNumber,
              let displayPoint = ImageGeometry.displayLocalCursorPoint(
                  appKitScreenPoint: screenPoint,
                  screenFrame: screen.frame
              ) else {
            return
        }

        let result = CGDisplayMoveCursorToPoint(
            CGDirectDisplayID(displayNumber.uint32Value),
            displayPoint
        )
        if result == .success {
            NSCursor.crosshair.set()
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
