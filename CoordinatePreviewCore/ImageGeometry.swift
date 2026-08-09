import CoreGraphics

public struct PixelCoordinate: Equatable, Sendable {
    public let x: Int
    public let y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

public struct PixelSampleWindow: Equatable, Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int
    public let focusColumn: Int
    public let focusRow: Int

    public init(
        x: Int,
        y: Int,
        width: Int,
        height: Int,
        focusColumn: Int,
        focusRow: Int
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.focusColumn = focusColumn
        self.focusRow = focusRow
    }
}

public enum ImageGeometry {
    public static func aspectFitRect(
        imageSize: CGSize,
        in bounds: CGRect,
        padding: CGFloat = 24
    ) -> CGRect {
        guard imageSize.width > 0,
              imageSize.height > 0,
              bounds.width > padding * 2,
              bounds.height > padding * 2 else {
            return .zero
        }

        let availableBounds = bounds.insetBy(dx: padding, dy: padding)
        let scale = min(
            availableBounds.width / imageSize.width,
            availableBounds.height / imageSize.height
        )
        let fittedSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        return CGRect(
            x: bounds.midX - fittedSize.width / 2,
            y: bounds.midY - fittedSize.height / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    /// Applies an image-level zoom and pan offset to the aspect-fit rect.
    ///
    /// The result is centered within `bounds` (matching `aspectFitRect` when
    /// `zoom == 1` and `panOffset == .zero`) and then translated by `panOffset`.
    public static func scaledImageRect(
        baseFit: CGRect,
        in bounds: CGRect,
        zoom: CGFloat,
        panOffset: CGPoint
    ) -> CGRect {
        guard zoom > 0 else { return baseFit }

        let displayedSize = CGSize(
            width: baseFit.width * zoom,
            height: baseFit.height * zoom
        )
        let centered = CGRect(
            x: bounds.midX - displayedSize.width / 2,
            y: bounds.midY - displayedSize.height / 2,
            width: displayedSize.width,
            height: displayedSize.height
        )
        return centered.offsetBy(dx: panOffset.x, dy: panOffset.y)
    }

    /// Keeps the image inside `bounds`: when the displayed image is larger than
    /// the bounds it may pan up to its own overhang; when it is smaller it is
    /// forced back to the center (offset zero).
    public static func clampPanOffset(
        _ panOffset: CGPoint,
        bounds: CGRect,
        displayedSize: CGSize
    ) -> CGPoint {
        let maxOffsetX = max(0, (displayedSize.width - bounds.width) / 2)
        let maxOffsetY = max(0, (displayedSize.height - bounds.height) / 2)
        return CGPoint(
            x: min(max(panOffset.x, -maxOffsetX), maxOffsetX),
            y: min(max(panOffset.y, -maxOffsetY), maxOffsetY)
        )
    }

    /// Computes the new pan offset so the image point currently under
    /// `focusPoint` (in view coordinates) stays under it after the zoom changes.
    public static func panOffsetForZoom(
        fromZoom: CGFloat,
        toZoom: CGFloat,
        focusPoint: CGPoint,
        baseFit: CGRect,
        bounds: CGRect,
        oldPanOffset: CGPoint
    ) -> CGPoint {
        guard fromZoom > 0, toZoom > 0 else { return .zero }

        let displayedFrom = scaledImageRect(
            baseFit: baseFit,
            in: bounds,
            zoom: fromZoom,
            panOffset: oldPanOffset
        )
        let displayedToZero = scaledImageRect(
            baseFit: baseFit,
            in: bounds,
            zoom: toZoom,
            panOffset: .zero
        )

        guard displayedFrom.width > 0, displayedFrom.height > 0 else {
            return .zero
        }

        let normalizedFocus = CGPoint(
            x: (focusPoint.x - displayedFrom.minX) / displayedFrom.width,
            y: (focusPoint.y - displayedFrom.minY) / displayedFrom.height
        )

        let unclampedOffset = CGPoint(
            x: focusPoint.x - displayedToZero.minX - normalizedFocus.x * displayedToZero.width,
            y: focusPoint.y - displayedToZero.minY - normalizedFocus.y * displayedToZero.height
        )

        return clampPanOffset(
            unclampedOffset,
            bounds: bounds,
            displayedSize: displayedToZero.size
        )
    }

    /// Converts a rendered points-per-source-pixel target into the zoom value
    /// used by a view whose `1×` state is aspect-fit.
    public static func zoomForRenderedScale(
        pointsPerPixel: CGFloat,
        baseFit: CGRect,
        pixelSize: CGSize
    ) -> CGFloat? {
        guard pointsPerPixel > 0,
              baseFit.width > 0,
              baseFit.height > 0,
              pixelSize.width > 0,
              pixelSize.height > 0 else {
            return nil
        }

        let fitScale = min(
            baseFit.width / pixelSize.width,
            baseFit.height / pixelSize.height
        )
        guard fitScale.isFinite, fitScale > 0 else { return nil }

        let zoom = pointsPerPixel / fitScale
        return zoom.isFinite ? zoom : nil
    }

    /// Applies AppKit's magnification delta as a scale factor and clamps it to
    /// the supported zoom range.
    public static func zoomAfterMagnification(
        currentZoom: CGFloat,
        magnification: CGFloat,
        minimumZoom: CGFloat,
        maximumZoom: CGFloat
    ) -> CGFloat {
        guard currentZoom.isFinite,
              magnification.isFinite,
              minimumZoom > 0,
              maximumZoom >= minimumZoom else {
            return currentZoom
        }

        let scaleFactor = max(0, 1 + magnification)
        return min(max(currentZoom * scaleFactor, minimumZoom), maximumZoom)
    }

    public static func pixelCoordinate(
        at point: CGPoint,
        in imageRect: CGRect,
        pixelSize: CGSize
    ) -> PixelCoordinate? {
        let pixelWidth = Int(pixelSize.width.rounded())
        let pixelHeight = Int(pixelSize.height.rounded())

        guard imageRect.width > 0,
              imageRect.height > 0,
              pixelWidth > 0,
              pixelHeight > 0,
              point.x >= imageRect.minX,
              point.x < imageRect.maxX,
              point.y >= imageRect.minY,
              point.y < imageRect.maxY else {
            return nil
        }

        let normalizedX = (point.x - imageRect.minX) / imageRect.width
        let normalizedY = (point.y - imageRect.minY) / imageRect.height

        return PixelCoordinate(
            x: min(pixelWidth - 1, Int(normalizedX * CGFloat(pixelWidth))),
            y: min(pixelHeight - 1, Int(normalizedY * CGFloat(pixelHeight)))
        )
    }

    public static func pixelSampleWindow(
        centeredAt coordinate: PixelCoordinate,
        pixelSize: CGSize,
        sideLength: Int = 11
    ) -> PixelSampleWindow? {
        let pixelWidth = Int(pixelSize.width.rounded())
        let pixelHeight = Int(pixelSize.height.rounded())

        guard pixelWidth > 0,
              pixelHeight > 0,
              sideLength > 0,
              coordinate.x >= 0,
              coordinate.x < pixelWidth,
              coordinate.y >= 0,
              coordinate.y < pixelHeight else {
            return nil
        }

        let sampleWidth = min(sideLength, pixelWidth)
        let sampleHeight = min(sideLength, pixelHeight)
        let halfSide = sideLength / 2
        let originX = min(
            max(0, coordinate.x - halfSide),
            pixelWidth - sampleWidth
        )
        let originY = min(
            max(0, coordinate.y - halfSide),
            pixelHeight - sampleHeight
        )

        return PixelSampleWindow(
            x: originX,
            y: originY,
            width: sampleWidth,
            height: sampleHeight,
            focusColumn: coordinate.x - originX,
            focusRow: coordinate.y - originY
        )
    }

    public static func offsetPixelCoordinate(
        _ coordinate: PixelCoordinate,
        deltaX: Int,
        deltaY: Int,
        pixelSize: CGSize
    ) -> PixelCoordinate? {
        let pixelWidth = Int(pixelSize.width.rounded())
        let pixelHeight = Int(pixelSize.height.rounded())

        guard pixelWidth > 0,
              pixelHeight > 0,
              coordinate.x >= 0,
              coordinate.x < pixelWidth,
              coordinate.y >= 0,
              coordinate.y < pixelHeight else {
            return nil
        }

        return PixelCoordinate(
            x: min(max(0, coordinate.x + deltaX), pixelWidth - 1),
            y: min(max(0, coordinate.y + deltaY), pixelHeight - 1)
        )
    }

    public static func centerPoint(
        of coordinate: PixelCoordinate,
        in imageRect: CGRect,
        pixelSize: CGSize
    ) -> CGPoint? {
        let pixelWidth = Int(pixelSize.width.rounded())
        let pixelHeight = Int(pixelSize.height.rounded())

        guard imageRect.width > 0,
              imageRect.height > 0,
              pixelWidth > 0,
              pixelHeight > 0,
              coordinate.x >= 0,
              coordinate.x < pixelWidth,
              coordinate.y >= 0,
              coordinate.y < pixelHeight else {
            return nil
        }

        return CGPoint(
            x: imageRect.minX
                + (CGFloat(coordinate.x) + 0.5) / CGFloat(pixelWidth) * imageRect.width,
            y: imageRect.minY
                + (CGFloat(coordinate.y) + 0.5) / CGFloat(pixelHeight) * imageRect.height
        )
    }
}
