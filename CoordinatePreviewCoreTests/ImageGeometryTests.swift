import CoreGraphics
import Testing
@testable import CoordinatePreviewCore

struct ImageGeometryTests {
    @Test func aspectFitUsesWidthForWideImages() {
        let rect = ImageGeometry.aspectFitRect(
            imageSize: CGSize(width: 2000, height: 1000),
            in: CGRect(x: 0, y: 0, width: 1000, height: 800),
            padding: 20
        )

        #expect(abs(rect.minX - 20) < 0.001)
        #expect(abs(rect.minY - 160) < 0.001)
        #expect(abs(rect.width - 960) < 0.001)
        #expect(abs(rect.height - 480) < 0.001)
    }

    @Test func aspectFitUsesHeightForTallImages() {
        let rect = ImageGeometry.aspectFitRect(
            imageSize: CGSize(width: 1000, height: 2000),
            in: CGRect(x: 0, y: 0, width: 1000, height: 800),
            padding: 20
        )

        #expect(abs(rect.minX - 310) < 0.001)
        #expect(abs(rect.minY - 20) < 0.001)
        #expect(abs(rect.width - 380) < 0.001)
        #expect(abs(rect.height - 760) < 0.001)
    }

    @Test func mapsTopLeftAndBottomRightPixels() {
        let imageRect = CGRect(x: 10, y: 20, width: 200, height: 100)
        let pixelSize = CGSize(width: 2000, height: 1000)

        #expect(
            ImageGeometry.pixelCoordinate(
                at: CGPoint(x: 10, y: 20),
                in: imageRect,
                pixelSize: pixelSize
            ) == PixelCoordinate(x: 0, y: 0)
        )
        #expect(
            ImageGeometry.pixelCoordinate(
                at: CGPoint(x: 209.999, y: 119.999),
                in: imageRect,
                pixelSize: pixelSize
            ) == PixelCoordinate(x: 1999, y: 999)
        )
    }

    @Test func mapsCenterWithoutDependingOnDisplayScale() {
        let coordinate = ImageGeometry.pixelCoordinate(
            at: CGPoint(x: 60, y: 45),
            in: CGRect(x: 10, y: 20, width: 100, height: 50),
            pixelSize: CGSize(width: 4000, height: 2000)
        )

        #expect(coordinate == PixelCoordinate(x: 2000, y: 1000))
    }

    @Test func rejectsPointsOutsideTheRenderedImage() {
        let imageRect = CGRect(x: 10, y: 20, width: 200, height: 100)
        let pixelSize = CGSize(width: 2000, height: 1000)

        #expect(
            ImageGeometry.pixelCoordinate(
                at: CGPoint(x: 9.999, y: 50),
                in: imageRect,
                pixelSize: pixelSize
            ) == nil
        )
        #expect(
            ImageGeometry.pixelCoordinate(
                at: CGPoint(x: 210, y: 50),
                in: imageRect,
                pixelSize: pixelSize
            ) == nil
        )
    }

    @Test func centersMagnifierSampleAwayFromEdges() {
        let sample = ImageGeometry.pixelSampleWindow(
            centeredAt: PixelCoordinate(x: 100, y: 80),
            pixelSize: CGSize(width: 400, height: 300)
        )

        #expect(
            sample == PixelSampleWindow(
                x: 95,
                y: 75,
                width: 11,
                height: 11,
                focusColumn: 5,
                focusRow: 5
            )
        )
    }

    @Test func clampsMagnifierSampleAtImageEdges() {
        let topLeft = ImageGeometry.pixelSampleWindow(
            centeredAt: PixelCoordinate(x: 0, y: 0),
            pixelSize: CGSize(width: 400, height: 300)
        )
        let bottomRight = ImageGeometry.pixelSampleWindow(
            centeredAt: PixelCoordinate(x: 399, y: 299),
            pixelSize: CGSize(width: 400, height: 300)
        )

        #expect(topLeft?.x == 0)
        #expect(topLeft?.y == 0)
        #expect(topLeft?.focusColumn == 0)
        #expect(topLeft?.focusRow == 0)
        #expect(bottomRight?.x == 389)
        #expect(bottomRight?.y == 289)
        #expect(bottomRight?.focusColumn == 10)
        #expect(bottomRight?.focusRow == 10)
    }

    @Test func supportsImagesSmallerThanMagnifierSample() {
        let sample = ImageGeometry.pixelSampleWindow(
            centeredAt: PixelCoordinate(x: 2, y: 1),
            pixelSize: CGSize(width: 4, height: 3)
        )

        #expect(
            sample == PixelSampleWindow(
                x: 0,
                y: 0,
                width: 4,
                height: 3,
                focusColumn: 2,
                focusRow: 1
            )
        )
    }

    @Test func offsetsPixelCoordinateByOnePixel() {
        let coordinate = PixelCoordinate(x: 100, y: 80)
        let pixelSize = CGSize(width: 400, height: 300)

        #expect(
            ImageGeometry.offsetPixelCoordinate(
                coordinate,
                deltaX: -1,
                deltaY: 0,
                pixelSize: pixelSize
            ) == PixelCoordinate(x: 99, y: 80)
        )
        #expect(
            ImageGeometry.offsetPixelCoordinate(
                coordinate,
                deltaX: 0,
                deltaY: 1,
                pixelSize: pixelSize
            ) == PixelCoordinate(x: 100, y: 81)
        )
    }

    @Test func clampsKeyboardAdjustmentToImageBounds() {
        let pixelSize = CGSize(width: 400, height: 300)

        #expect(
            ImageGeometry.offsetPixelCoordinate(
                PixelCoordinate(x: 0, y: 0),
                deltaX: -1,
                deltaY: -1,
                pixelSize: pixelSize
            ) == PixelCoordinate(x: 0, y: 0)
        )
        #expect(
            ImageGeometry.offsetPixelCoordinate(
                PixelCoordinate(x: 399, y: 299),
                deltaX: 1,
                deltaY: 1,
                pixelSize: pixelSize
            ) == PixelCoordinate(x: 399, y: 299)
        )
    }

    @Test func mapsAdjustedPixelToItsRenderedCenter() {
        let point = ImageGeometry.centerPoint(
            of: PixelCoordinate(x: 0, y: 0),
            in: CGRect(x: 10, y: 20, width: 200, height: 100),
            pixelSize: CGSize(width: 2000, height: 1000)
        )

        #expect(abs((point?.x ?? 0) - 10.05) < 0.001)
        #expect(abs((point?.y ?? 0) - 20.05) < 0.001)
    }
}
