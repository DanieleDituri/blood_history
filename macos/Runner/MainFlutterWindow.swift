import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Il contenuto Flutter si estende nella zona del titolo: la sidebar
    // gestisce l'area dei traffic-light (52px) senza il titolo nativo.
    self.styleMask.insert(.fullSizeContentView)
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true

    // La finestra è trascinabile cliccando su qualunque punto dello sfondo.
    self.isMovableByWindowBackground = true

    // Dimensione minima: sidebar (200px) + area contenuto minima.
    self.minSize = NSSize(width: 700, height: 480)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
