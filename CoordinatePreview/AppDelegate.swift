import AppKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowControllers: [ImageWindowController] = []
    private var receivedOpenRequest = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureMainMenu()

        DispatchQueue.main.async { [weak self] in
            guard let self,
                  !self.receivedOpenRequest,
                  self.windowControllers.isEmpty else {
                return
            }
            self.openImages(nil)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        receivedOpenRequest = true
        urls.forEach(openImage(at:))
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc private func openImages(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.title = "打开图片"
        panel.prompt = "打开"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK else {
            if windowControllers.isEmpty {
                NSApp.terminate(nil)
            }
            return
        }

        panel.urls.forEach(openImage(at:))
    }

    private func openImage(at url: URL) {
        do {
            let controller = try ImageWindowController(imageURL: url)
            controller.onClose = { [weak self, weak controller] in
                guard let self, let controller else { return }
                self.windowControllers.removeAll { $0 === controller }
            }
            controller.onOpenImage = { [weak self] droppedURL in
                self?.openImage(at: droppedURL)
            }
            windowControllers.append(controller)
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "无法打开图片"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "Coordinate Preview")
        appMenu.addItem(
            withTitle: "退出 Coordinate Preview",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "文件")
        let openItem = NSMenuItem(
            title: "打开…",
            action: #selector(openImages(_:)),
            keyEquivalent: "o"
        )
        openItem.target = self
        fileMenu.addItem(openItem)
        fileMenu.addItem(.separator())
        fileMenu.addItem(
            withTitle: "关闭窗口",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "显示")
        let magnifierZoomItem = NSMenuItem(title: "放大镜倍率", action: nil, keyEquivalent: "")
        let magnifierZoomMenu = NSMenu(title: "放大镜倍率")
        for zoom in [6, 8, 12, 16] {
            let item = NSMenuItem(
                title: "\(zoom)×",
                action: #selector(ImageCanvasView.setMagnifierZoom(_:)),
                keyEquivalent: ""
            )
            item.tag = zoom
            magnifierZoomMenu.addItem(item)
        }
        magnifierZoomItem.submenu = magnifierZoomMenu
        viewMenu.addItem(magnifierZoomItem)
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        NSApp.mainMenu = mainMenu
    }
}
