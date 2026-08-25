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

    // MARK: - Image zoom / pan

    @Test func zoomOfOneMatchesBaseFit() {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let baseFit = ImageGeometry.aspectFitRect(
            imageSize: CGSize(width: 2000, height: 1000),
            in: bounds
        )
        let scaled = ImageGeometry.scaledImageRect(
            baseFit: baseFit,
            in: bounds,
            zoom: 1,
            panOffset: .zero
        )

        #expect(abs(scaled.minX - baseFit.minX) < 0.001)
        #expect(abs(scaled.minY - baseFit.minY) < 0.001)
        #expect(abs(scaled.width - baseFit.width) < 0.001)
        #expect(abs(scaled.height - baseFit.height) < 0.001)
    }

    @Test func zoomScalesSizeAroundCenter() {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let baseFit = ImageGeometry.aspectFitRect(
            imageSize: CGSize(width: 2000, height: 1000),
            in: bounds
        )
        let scaled = ImageGeometry.scaledImageRect(
            baseFit: baseFit,
            in: bounds,
            zoom: 2,
            panOffset: .zero
        )

        #expect(abs(scaled.width - baseFit.width * 2) < 0.001)
        #expect(abs(scaled.height - baseFit.height * 2) < 0.001)
        // Centered on the bounds' midpoint, which is also the baseFit midpoint.
        #expect(abs(scaled.midX - bounds.midX) < 0.001)
        #expect(abs(scaled.midY - bounds.midY) < 0.001)
    }

    @Test func panOffsetTranslatesWithoutResizing() {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let baseFit = ImageGeometry.aspectFitRect(
            imageSize: CGSize(width: 2000, height: 1000),
            in: bounds
        )
        let scaled = ImageGeometry.scaledImageRect(
            baseFit: baseFit,
            in: bounds,
            zoom: 2,
            panOffset: CGPoint(x: 50, y: -30)
        )
        let untranslated = ImageGeometry.scaledImageRect(
            baseFit: baseFit,
            in: bounds,
            zoom: 2,
            panOffset: .zero
        )

        #expect(abs(scaled.minX - (untranslated.minX + 50)) < 0.001)
        #expect(abs(scaled.minY - (untranslated.minY - 30)) < 0.001)
        #expect(abs(scaled.width - untranslated.width) < 0.001)
    }

    @Test func clampAllowsPanningUpToTheOverhang() {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        // Image displayed larger than the viewport: 2000x800, 500px overhang per side.
        let displayed = CGSize(width: 2000, height: 800)

        let clamped = ImageGeometry.clampPanOffset(
            CGPoint(x: 500, y: 200),
            bounds: bounds,
            displayedSize: displayed
        )
        #expect(abs(clamped.x - 500) < 0.001)
        #expect(abs(clamped.y) < 0.001)
    }

    @Test func clampRejectsPanningBeyondOverhang() {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let displayed = CGSize(width: 2000, height: 800)

        let clamped = ImageGeometry.clampPanOffset(
            CGPoint(x: 1000, y: 100),
            bounds: bounds,
            displayedSize: displayed
        )
        // 500 is the max overhang on X, and there is no Y overhang.
        #expect(abs(clamped.x - 500) < 0.001)
        #expect(abs(clamped.y) < 0.001)
    }

    @Test func clampCentersWhenImageFitsInViewport() {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        // Image smaller than viewport: no panning allowed.
        let displayed = CGSize(width: 400, height: 200)

        let clamped = ImageGeometry.clampPanOffset(
            CGPoint(x: 100, y: -100),
            bounds: bounds,
            displayedSize: displayed
        )
        #expect(abs(clamped.x) < 0.001)
        #expect(abs(clamped.y) < 0.001)
    }

    @Test func minimapViewportMapsVisibleImageArea() {
        let viewport = ImageGeometry.normalizedViewportRect(
            imageRect: CGRect(x: -500, y: -100, width: 2000, height: 1000),
            viewport: CGRect(x: 0, y: 0, width: 1000, height: 800)
        )

        #expect(abs((viewport?.minX ?? 0) - 0.25) < 0.001)
        #expect(abs((viewport?.minY ?? 0) - 0.1) < 0.001)
        #expect(abs((viewport?.width ?? 0) - 0.5) < 0.001)
        #expect(abs((viewport?.height ?? 0) - 0.8) < 0.001)
    }

    @Test func minimapViewportUsesFullAxisWhenImageFits() {
        let viewport = ImageGeometry.normalizedViewportRect(
            imageRect: CGRect(x: 250, y: -400, width: 500, height: 1600),
            viewport: CGRect(x: 0, y: 0, width: 1000, height: 800)
        )

        #expect(abs((viewport?.minX ?? -1) - 0) < 0.001)
        #expect(abs((viewport?.width ?? 0) - 1) < 0.001)
        #expect(abs((viewport?.minY ?? 0) - 0.25) < 0.001)
        #expect(abs((viewport?.height ?? 0) - 0.5) < 0.001)
    }

    @Test func minimapNavigationCentersSelectedImagePoint() {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let baseFit = CGRect(x: 250, y: 25, width: 500, height: 750)
        let offset = ImageGeometry.panOffsetCentering(
            normalizedPoint: CGPoint(x: 0.75, y: 0.25),
            baseFit: baseFit,
            bounds: bounds,
            zoom: 4
        )
        let displayed = ImageGeometry.scaledImageRect(
            baseFit: baseFit,
            in: bounds,
            zoom: 4,
            panOffset: offset ?? .zero
        )
        let selectedPoint = CGPoint(
            x: displayed.minX + displayed.width * 0.75,
            y: displayed.minY + displayed.height * 0.25
        )

        #expect(abs(selectedPoint.x - bounds.midX) < 0.001)
        #expect(abs(selectedPoint.y - bounds.midY) < 0.001)
    }

    @Test func minimapNavigationClampsAtImageEdges() {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let baseFit = CGRect(x: 250, y: 25, width: 500, height: 750)
        let topLeft = ImageGeometry.panOffsetCentering(
            normalizedPoint: CGPoint(x: -1, y: -1),
            baseFit: baseFit,
            bounds: bounds,
            zoom: 4
        )
        let bottomRight = ImageGeometry.panOffsetCentering(
            normalizedPoint: CGPoint(x: 2, y: 2),
            baseFit: baseFit,
            bounds: bounds,
            zoom: 4
        )

        #expect(topLeft == CGPoint(x: 500, y: 1100))
        #expect(bottomRight == CGPoint(x: -500, y: -1100))
    }

    @Test func jumpCentersSourcePixelRowAndPreservesHorizontalPan() {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let baseFit = CGRect(x: 250, y: 25, width: 500, height: 750)
        let offset = ImageGeometry.panOffsetCentering(
            pixelY: 600,
            pixelHeight: 1000,
            baseFit: baseFit,
            bounds: bounds,
            zoom: 4,
            currentPanOffset: CGPoint(x: 250, y: 400)
        )

        let displayed = ImageGeometry.scaledImageRect(
            baseFit: baseFit,
            in: bounds,
            zoom: 4,
            panOffset: offset ?? .zero
        )
        let rowCenterY = displayed.minY + 600.5 / 1000 * displayed.height

        #expect(abs((offset?.x ?? 0) - 250) < 0.001)
        #expect(abs(rowCenterY - bounds.midY) < 0.001)
    }

    @Test func jumpClampsRowsNearImageEdges() {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let baseFit = CGRect(x: 250, y: 25, width: 500, height: 750)

        let topOffset = ImageGeometry.panOffsetCentering(
            pixelY: 0,
            pixelHeight: 1000,
            baseFit: baseFit,
            bounds: bounds,
            zoom: 4,
            currentPanOffset: .zero
        )
        let bottomOffset = ImageGeometry.panOffsetCentering(
            pixelY: 999,
            pixelHeight: 1000,
            baseFit: baseFit,
            bounds: bounds,
            zoom: 4,
            currentPanOffset: .zero
        )

        #expect(abs((topOffset?.y ?? 0) - 1100) < 0.001)
        #expect(abs((bottomOffset?.y ?? 0) + 1100) < 0.001)
    }

    @Test func jumpDoesNotPanWhenImageFitsInViewport() {
        let offset = ImageGeometry.panOffsetCentering(
            pixelY: 250,
            pixelHeight: 1000,
            baseFit: CGRect(x: 450, y: 25, width: 100, height: 750),
            bounds: CGRect(x: 0, y: 0, width: 1000, height: 800),
            zoom: 1,
            currentPanOffset: CGPoint(x: 100, y: 100)
        )

        #expect(offset == .zero)
    }

    @Test func jumpRejectsPixelRowsOutsideTheImage() {
        let arguments = (
            pixelHeight: 1000,
            baseFit: CGRect(x: 450, y: 25, width: 100, height: 750),
            bounds: CGRect(x: 0, y: 0, width: 1000, height: 800)
        )

        #expect(
            ImageGeometry.panOffsetCentering(
                pixelY: -1,
                pixelHeight: arguments.pixelHeight,
                baseFit: arguments.baseFit,
                bounds: arguments.bounds,
                zoom: 1,
                currentPanOffset: .zero
            ) == nil
        )
        #expect(
            ImageGeometry.panOffsetCentering(
                pixelY: 1000,
                pixelHeight: arguments.pixelHeight,
                baseFit: arguments.baseFit,
                bounds: arguments.bounds,
                zoom: 1,
                currentPanOffset: .zero
            ) == nil
        )
    }

    @Test func fitWidthZoomExpandsTallImageToAvailableWidth() {
        let zoom = ImageGeometry.zoomToFitWidth(
            baseFit: CGRect(x: 450, y: 24, width: 100, height: 752),
            bounds: CGRect(x: 0, y: 0, width: 1000, height: 800)
        )

        #expect(abs((zoom ?? 0) - 9.52) < 0.001)
    }

    @Test func fitWidthZoomKeepsWidthFittedImageAtOne() {
        let zoom = ImageGeometry.zoomToFitWidth(
            baseFit: CGRect(x: 24, y: 200, width: 952, height: 400),
            bounds: CGRect(x: 0, y: 0, width: 1000, height: 800)
        )

        #expect(abs((zoom ?? 0) - 1) < 0.001)
    }

    @Test func convertsAppKitPointToDisplayLocalCursorPoint() {
        let primaryPoint = ImageGeometry.displayLocalCursorPoint(
            appKitScreenPoint: CGPoint(x: 100, y: 980),
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )
        let secondaryPoint = ImageGeometry.displayLocalCursorPoint(
            appKitScreenPoint: CGPoint(x: -1000, y: 700),
            screenFrame: CGRect(x: -1440, y: 0, width: 1440, height: 900)
        )

        #expect(primaryPoint == CGPoint(x: 100, y: 100))
        #expect(secondaryPoint == CGPoint(x: 440, y: 200))
    }

    @Test func zoomKeepsCenteredFocusPointStable() {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let baseFit = ImageGeometry.aspectFitRect(
            imageSize: CGSize(width: 2000, height: 1000),
            in: bounds
        )
        let focus = bounds.center

        let newOffset = ImageGeometry.panOffsetForZoom(
            fromZoom: 1,
            toZoom: 2,
            focusPoint: focus,
            baseFit: baseFit,
            bounds: bounds,
            oldPanOffset: .zero
        )

        let scaledFrom = ImageGeometry.scaledImageRect(
            baseFit: baseFit,
            in: bounds,
            zoom: 1,
            panOffset: .zero
        )
        let scaledTo = ImageGeometry.scaledImageRect(
            baseFit: baseFit,
            in: bounds,
            zoom: 2,
            panOffset: newOffset
        )

        let fromFocus = CGPoint(
            x: (focus.x - scaledFrom.minX) / scaledFrom.width,
            y: (focus.y - scaledFrom.minY) / scaledFrom.height
        )
        let toFocus = CGPoint(
            x: (focus.x - scaledTo.minX) / scaledTo.width,
            y: (focus.y - scaledTo.minY) / scaledTo.height
        )
        #expect(abs(fromFocus.x - toFocus.x) < 0.001)
        #expect(abs(fromFocus.y - toFocus.y) < 0.001)
    }

    @Test func zoomFromUserOffsetKeepsFocusPointStable() {
        let bounds = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let baseFit = ImageGeometry.aspectFitRect(
            imageSize: CGSize(width: 2000, height: 1000),
            in: bounds
        )
        let oldOffset = CGPoint(x: 200, y: -100)
        let focus = CGPoint(x: 300, y: 200)

        let newOffset = ImageGeometry.panOffsetForZoom(
            fromZoom: 2,
            toZoom: 3,
            focusPoint: focus,
            baseFit: baseFit,
            bounds: bounds,
            oldPanOffset: oldOffset
        )

        let scaledFrom = ImageGeometry.scaledImageRect(
            baseFit: baseFit,
            in: bounds,
            zoom: 2,
            panOffset: oldOffset
        )
        let scaledTo = ImageGeometry.scaledImageRect(
            baseFit: baseFit,
            in: bounds,
            zoom: 3,
            panOffset: newOffset
        )

        let fromFocus = CGPoint(
            x: (focus.x - scaledFrom.minX) / scaledFrom.width,
            y: (focus.y - scaledFrom.minY) / scaledFrom.height
        )
        let toFocus = CGPoint(
            x: (focus.x - scaledTo.minX) / scaledTo.width,
            y: (focus.y - scaledTo.minY) / scaledTo.height
        )
        #expect(abs(fromFocus.x - toFocus.x) < 0.001)
        #expect(abs(fromFocus.y - toFocus.y) < 0.001)
    }

    @Test func renderedScaleExpandsZoomRangeForLongImage() {
        let zoom = ImageGeometry.zoomForRenderedScale(
            pointsPerPixel: 20,
            baseFit: CGRect(x: 0, y: 0, width: 10, height: 500),
            pixelSize: CGSize(width: 1000, height: 50_000)
        )

        // The long image is fitted at 1%, so rendering each source pixel at
        // 20 points requires a 2000× fit-relative zoom.
        #expect(abs((zoom ?? 0) - 2_000) < 0.001)
    }

    @Test func renderedScaleRejectsInvalidGeometry() {
        let zoom = ImageGeometry.zoomForRenderedScale(
            pointsPerPixel: 20,
            baseFit: .zero,
            pixelSize: CGSize(width: 1000, height: 50_000)
        )

        #expect(zoom == nil)
    }

    @Test func magnificationScalesProportionallyAtHighZoom() {
        let zoom = ImageGeometry.zoomAfterMagnification(
            currentZoom: 100,
            magnification: 0.1,
            minimumZoom: 0.25,
            maximumZoom: 2_000
        )

        #expect(abs(zoom - 110) < 0.001)
    }

    @Test func magnificationClampsToDynamicMaximum() {
        let zoom = ImageGeometry.zoomAfterMagnification(
            currentZoom: 1_900,
            magnification: 0.2,
            minimumZoom: 0.25,
            maximumZoom: 2_000
        )

        #expect(abs(zoom - 2_000) < 0.001)
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
