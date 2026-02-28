import AppKit

@main
enum Main {
    static func main() {
        let app = NSApplication.shared
        let appDelegate = AppDelegate()
        app.delegate = appDelegate
        app.setActivationPolicy(.regular)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}
