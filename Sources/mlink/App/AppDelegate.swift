import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()

        let controller = MainWindowController()
        controller.showWindow(self)
        mainWindowController = controller
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc private func newDocument(_ sender: Any?) {
        mainWindowController?.newDocument()
    }

    @objc private func newTab(_ sender: Any?) {
        mainWindowController?.newTab()
    }

    @objc private func openDocument(_ sender: Any?) {
        mainWindowController?.openDocument()
    }

    @objc private func saveDocument(_ sender: Any?) {
        _ = mainWindowController?.saveDocument()
    }

    @objc private func saveDocumentAs(_ sender: Any?) {
        _ = mainWindowController?.saveDocumentAs()
    }

    @objc private func closeCurrentTab(_ sender: Any?) {
        mainWindowController?.closeCurrentTab()
    }

    @objc private func toggleFavorite(_ sender: Any?) {
        mainWindowController?.toggleFavoriteForCurrentTab()
    }

    @objc private func showAboutPanel(_ sender: Any?) {
        let bundle = Bundle.main
        let appName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? "mLink"
        let version = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "Unknown"
        let build = (bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "Unknown"
        let buildTime = (bundle.object(forInfoDictionaryKey: "MLinkBuildTime") as? String) ?? "Unknown"

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "关于 \(appName)"
        alert.informativeText = "版本号: \(version) (Build \(build))\n编译时间: \(buildTime)\n作者: 多宝 (hzchenkj@gmail.com)"
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu(title: "MainMenu")

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "Application")
        appMenuItem.submenu = appMenu

        let aboutItem = appMenu.addItem(
            withTitle: "关于 mLink",
            action: #selector(showAboutPanel(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = self
        appMenu.addItem(NSMenuItem.separator())

        appMenu.addItem(
            withTitle: "Quit mLink",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)

        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu

        fileMenu.addItem(
            withTitle: "New",
            action: #selector(newDocument(_:)),
            keyEquivalent: "n"
        ).target = self

        let newTabItem = fileMenu.addItem(
            withTitle: "New Tab",
            action: #selector(newTab(_:)),
            keyEquivalent: "t"
        )
        newTabItem.target = self

        fileMenu.addItem(
            withTitle: "Open...",
            action: #selector(openDocument(_:)),
            keyEquivalent: "o"
        ).target = self

        fileMenu.addItem(NSMenuItem.separator())

        fileMenu.addItem(
            withTitle: "Save",
            action: #selector(saveDocument(_:)),
            keyEquivalent: "s"
        ).target = self

        let saveAsItem = fileMenu.addItem(
            withTitle: "Save As...",
            action: #selector(saveDocumentAs(_:)),
            keyEquivalent: "S"
        )
        saveAsItem.keyEquivalentModifierMask = [.command, .shift]
        saveAsItem.target = self

        let closeTabItem = fileMenu.addItem(
            withTitle: "Close Tab",
            action: #selector(closeCurrentTab(_:)),
            keyEquivalent: "w"
        )
        closeTabItem.target = self

        fileMenu.addItem(NSMenuItem.separator())
        let favoriteItem = fileMenu.addItem(
            withTitle: "Toggle Favorite",
            action: #selector(toggleFavorite(_:)),
            keyEquivalent: "d"
        )
        favoriteItem.keyEquivalentModifierMask = [.command, .shift]
        favoriteItem.target = self

        mainMenu.addItem(setupEditMenu())

        NSApp.mainMenu = mainMenu
    }

    private func setupEditMenu() -> NSMenuItem {
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu

        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        return editMenuItem
    }
}
