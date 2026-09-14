import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    backgroundColor = NSColor.black
    isOpaque = true
    contentView?.wantsLayer = true
    contentView?.layer?.backgroundColor = NSColor.black.cgColor

    let flutterViewController = FlutterViewController.init()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    let environment = ProcessInfo.processInfo.environment
    if let widthText = environment["FLUTTER_WINDOW_WIDTH"],
       let heightText = environment["FLUTTER_WINDOW_HEIGHT"],
       let width = Double(widthText),
       let height = Double(heightText),
       width > 0,
       height > 0 {
      self.setContentSize(NSSize(width: width, height: height))
      self.center()
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
