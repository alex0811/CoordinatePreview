import AppKit

final class ImageWindowController: NSWindowController, NSWindowDelegate {
    var onClose: (() -> Void)?
    var onOpenImage: ((URL) -> Void)? {
        didSet {
            imageView.onOpenImage = onOpenImage
        }
    }

    private let imageView: ImageCanvasView

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

        window.title = imageURL.lastPathComponent
        window.contentView = imageView
        window.makeFirstResponder(imageView)
        window.backgroundColor = NSColor(calibratedWhite: 0.10, alpha: 1)
        window.minSize = CGSize(width: 360, height: 280)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
