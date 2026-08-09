import AppKit

final class ImageWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?
    var onOpenImage: ((URL) -> Void)? {
        didSet {
            imageView.onOpenImage = onOpenImage
        }
    }

    private let imageView: ImageCanvasView
    private static let toolbarHeight: CGFloat = 40

    init(imageURL: URL) throws {
        let loadedImage = try LoadedImage(contentsOf: imageURL)
        imageView = ImageCanvasView(loadedImage: loadedImage)

        let screenSize = NSScreen.main?.visibleFrame.size ?? CGSize(width: 1280, height: 800)
        let preferredWidth = min(max(loadedImage.pixelSize.width + 48, 640), screenSize.width * 0.8)
        let preferredHeight = min(max(loadedImage.pixelSize.height + 48, 480), screenSize.height * 0.8)
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: preferredWidth, height: preferredHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)

        let content = ContentView(toolbarHeight: Self.toolbarHeight)
        content.frame = CGRect(origin: .zero, size: CGSize(width: preferredWidth, height: preferredHeight))
        content.autoresizingMask = [.width, .height]
        content.imageView = imageView
        content.toolbar = makeToolbar()

        window.title = imageURL.lastPathComponent
        window.contentView = content
        window.makeFirstResponder(imageView)
        window.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 1)
        window.minSize = CGSize(width: 360, height: 280)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()

        // Lay out once now that everything is wired into the window.
        content.layoutSubtreeIfNeeded()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    private func makeToolbar() -> ZoomToolbar {
        let toolbar = ZoomToolbar(frame: NSRect(x: 0, y: 0, width: 0, height: Self.toolbarHeight))
        toolbar.zoomOutTarget = imageView
        toolbar.zoomInTarget = imageView
        toolbar.resetTarget = imageView
        toolbar.imageDropTarget = imageView
        imageView.onImageZoomChange = { [weak toolbar] zoom in
            toolbar?.updateZoom(zoom)
        }
        return toolbar
    }
}

/// Container that lays out its toolbar (top strip) and image view (below it)
/// using manual frames in `layout()`, so initial sizing and resizes both work
/// regardless of when the window actually assigns a real frame.
private final class ContentView: NSView {
    let toolbarHeight: CGFloat
    var imageView: NSView? {
        didSet { installSubview(oldValue, with: imageView) }
    }
    var toolbar: NSView? {
        didSet { installSubview(oldValue, with: toolbar) }
    }

    init(toolbarHeight: CGFloat) {
        self.toolbarHeight = toolbarHeight
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 1).cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let bounds = self.bounds
        let toolbarHeight = min(self.toolbarHeight, bounds.height)

        toolbar?.frame = NSRect(
            x: 0,
            y: bounds.height - toolbarHeight,
            width: bounds.width,
            height: toolbarHeight
        )
        imageView?.frame = NSRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: max(bounds.height - toolbarHeight, 0)
        )
    }

    private func installSubview(_ old: NSView?, with new: NSView?) {
        guard let new else { return }
        if let old, old !== new {
            old.removeFromSuperview()
        }
        new.autoresizingMask = []
        addSubview(new)
    }
}

/// Top strip with a native macOS zoom segmented control, centered horizontally.
/// All frame-based (matches the rest of the app's non-constraint style).
private final class ZoomToolbar: NSVisualEffectView {
    var zoomOutTarget: AnyObject?
    var zoomInTarget: AnyObject?
    var resetTarget: AnyObject?
    var imageDropTarget: ImageCanvasView?

    private let zoomControl: NSSegmentedControl
    private let separator = NSBox()

    override init(frame frameRect: NSRect) {
        zoomControl = NSSegmentedControl(
            labels: ["", "1×", ""],
            trackingMode: .momentary,
            target: nil,
            action: nil
        )
        super.init(frame: frameRect)

        material = .headerView
        blendingMode = .withinWindow
        state = .followsWindowActiveState
        registerForDraggedTypes([.fileURL])

        configureZoomControl()
        addSubview(zoomControl)

        separator.boxType = .separator
        addSubview(separator)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()

        zoomControl.sizeToFit()
        zoomControl.frame.origin = CGPoint(
            x: floor((bounds.width - zoomControl.frame.width) / 2),
            y: floor((bounds.height - zoomControl.frame.height) / 2)
        )
        separator.frame = NSRect(x: 0, y: 0, width: bounds.width, height: 1)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        imageDropTarget?.draggingEntered(sender) ?? []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        imageDropTarget?.performDragOperation(sender) ?? false
    }

    private func configureZoomControl() {
        zoomControl.target = self
        zoomControl.action = #selector(performZoomAction(_:))
        zoomControl.segmentStyle = .rounded
        zoomControl.controlSize = .small
        zoomControl.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        zoomControl.focusRingType = .exterior

        zoomControl.setImage(Self.symbol(named: "minus.magnifyingglass", description: "缩小"), forSegment: 0)
        zoomControl.setImageScaling(.scaleProportionallyDown, forSegment: 0)
        zoomControl.setWidth(34, forSegment: 0)
        zoomControl.setToolTip("缩小", forSegment: 0)

        zoomControl.setWidth(62, forSegment: 1)
        updateZoom(1)

        zoomControl.setImage(Self.symbol(named: "plus.magnifyingglass", description: "放大"), forSegment: 2)
        zoomControl.setImageScaling(.scaleProportionallyDown, forSegment: 2)
        zoomControl.setWidth(34, forSegment: 2)
        zoomControl.setToolTip("放大", forSegment: 2)
    }

    private static func symbol(named name: String, description: String) -> NSImage? {
        NSImage(
            systemSymbolName: name,
            accessibilityDescription: description
        )?.withSymbolConfiguration(.init(pointSize: 12, weight: .medium))
    }

    func updateZoom(_ zoom: CGFloat) {
        let label = Self.zoomLabel(for: zoom)
        zoomControl.setLabel(label, forSegment: 1)
        zoomControl.setToolTip("当前倍率 \(label)，点按恢复为适合窗口", forSegment: 1)
        zoomControl.setAccessibilityLabel("图片缩放，当前倍率 \(label)")
    }

    private static func zoomLabel(for zoom: CGFloat) -> String {
        let fractionDigits: Int
        switch zoom {
        case ..<10:
            fractionDigits = 2
        case ..<100:
            fractionDigits = 1
        default:
            fractionDigits = 0
        }

        var number = String(format: "%.*f", fractionDigits, zoom)
        if number.contains(".") {
            number = number.replacingOccurrences(
                of: #"\.?0+$"#,
                with: "",
                options: .regularExpression
            )
        }
        return "\(number)×"
    }

    @objc private func performZoomAction(_ sender: NSSegmentedControl) {
        let actionAndTarget: (Selector, AnyObject?)?
        switch sender.selectedSegment {
        case 0:
            actionAndTarget = (#selector(ImageCanvasView.zoomOut), zoomOutTarget)
        case 1:
            actionAndTarget = (#selector(ImageCanvasView.resetZoom), resetTarget)
        case 2:
            actionAndTarget = (#selector(ImageCanvasView.zoomIn), zoomInTarget)
        default:
            actionAndTarget = nil
        }

        if let (action, target) = actionAndTarget {
            NSApp.sendAction(action, to: target, from: sender)
        }
    }
}
