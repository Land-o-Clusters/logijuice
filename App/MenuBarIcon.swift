import AppKit

/// Draws the device's own silhouette as a battery gauge, so the icon can't be mistaken for the Mac's battery.
/// Wide glyphs (keyboard) fill left→right; tall glyphs (mouse) fill bottom→top.
enum MenuBarIcon {
  static let glyphPointSize: CGFloat = 14
  static let emptyAlpha: CGFloat = 0.3

  static func render(outline: String, fill: String, fraction: Double, tinted: Bool, charging: Bool,
                     text: String?) -> NSImage {
    let config = NSImage.SymbolConfiguration(pointSize: glyphPointSize, weight: .regular)
    guard let outlineImage = NSImage(systemSymbolName: outline, accessibilityDescription: nil)?
      .withSymbolConfiguration(config)
    else { return NSImage(size: NSSize(width: 16, height: 16)) }
    let fillImage = NSImage(systemSymbolName: fill, accessibilityDescription: nil)?.withSymbolConfiguration(config)
    let bolt = charging
      ? NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: 9, weight: .bold))
      : nil
    let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    let label = text.map { NSAttributedString(string: $0, attributes: [.font: font, .foregroundColor: NSColor.black]) }

    let glyph = outlineImage.size
    let boltWidth = bolt.map { $0.size.width + 1 } ?? 0
    let labelWidth = label.map { ceil($0.size().width) + 3 } ?? 0
    let height = max(glyph.height, 16)
    let size = NSSize(width: ceil(glyph.width + boltWidth + labelWidth), height: height)
    let level = max(0, min(1, fraction))

    let image = NSImage(size: size, flipped: false) { rect in
      let glyphRect = NSRect(x: 0, y: (rect.height - glyph.height) / 2, width: glyph.width, height: glyph.height)
      // "Empty" = the solid shape, dimmed (like the system battery glyph); falls back to the outline.
      if let fillImage {
        fillImage.draw(in: glyphRect, from: .zero, operation: .sourceOver, fraction: emptyAlpha)
      } else {
        outlineImage.draw(in: glyphRect)
      }
      if let fillImage, level > 0 {
        NSGraphicsContext.saveGraphicsState()
        let clip = glyph.width > glyph.height
          ? NSRect(x: glyphRect.minX, y: glyphRect.minY, width: glyphRect.width * level, height: glyphRect.height)
          : NSRect(x: glyphRect.minX, y: glyphRect.minY, width: glyphRect.width, height: glyphRect.height * level)
        NSBezierPath(rect: clip).addClip()
        fillImage.draw(in: glyphRect)
        NSGraphicsContext.restoreGraphicsState()
      }
      var x = glyphRect.maxX
      if let bolt {
        bolt.draw(in: NSRect(x: x + 1, y: (rect.height - bolt.size.height) / 2, width: bolt.size.width,
                             height: bolt.size.height))
        x += boltWidth
      }
      if let label {
        let textSize = label.size()
        label.draw(at: NSPoint(x: x + 3, y: (rect.height - textSize.height) / 2))
      }
      if tinted {
        NSColor.systemRed.set()
        rect.fill(using: .sourceAtop)
      }
      return true
    }
    // Template = the menu bar recolors it for light/dark; a fired alert keeps its red.
    image.isTemplate = !tinted
    image.accessibilityDescription = "Logitech battery"
    return image
  }
}
