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
