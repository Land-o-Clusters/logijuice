import AppKit

/// Draws each device's own silhouette as a battery gauge, so the icon can't be mistaken for the Mac's battery.
/// Wide glyphs (keyboard) fill left→right; tall glyphs (mouse) fill bottom→top. Several gauges sit side by side.
/// Only the filled part and the percentage take an alert color; the empty part stays the menu bar's own color.
/// While a device charges, its fill and bolt are green instead (charging re-arms its alerts, so nothing is lost).
enum MenuBarIcon {
  struct Gauge: Hashable {
    var outline: String
    var fill: String
    var fraction: Double
    var tint: NSColor?
    var charging: Bool
    var text: String?
  }

  static let glyphPointSize: CGFloat = 14
  static let emptyAlpha: CGFloat = 0.3
  static let gaugeSpacing: CGFloat = 7
  static let minimumVisibleFill = 0.15

  /// Pale green on a dark menu bar. A light bar needs a deeper green, because a pale fill would read lighter than the
  /// dimmed empty part and the gauge would look inverted.
  static let chargingColor = NSColor(name: "logijuice.charging") { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      ? NSColor(srgbRed: 0.62, green: 0.92, blue: 0.66, alpha: 1)
      : NSColor(srgbRed: 0.16, green: 0.62, blue: 0.30, alpha: 1)
  }

  private struct Prepared {
    var gauge: Gauge
    var outline: NSImage
    var fill: NSImage?
    var bolt: NSImage?
    var label: NSAttributedString?
    var width: CGFloat
  }

  static func render(_ gauges: [Gauge], pointSize: CGFloat = glyphPointSize) -> NSImage {
    let scale = pointSize / glyphPointSize
    let anyTint = gauges.contains { $0.tint != nil || $0.charging }
    // Template images are recolored by the menu bar (light/dark, wallpaper-adaptive). Once anything is tinted the
    // image can't be template, so the neutral parts use labelColor, which resolves in the status item's appearance.
    let neutral: NSColor = anyTint ? .labelColor : .black
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
    let boltConfig = NSImage.SymbolConfiguration(pointSize: 9 * scale, weight: .bold)
    let font = NSFont.monospacedDigitSystemFont(ofSize: 12 * scale, weight: .medium)

    let prepared: [Prepared] = gauges.compactMap { g in
      guard let outline = NSImage(systemSymbolName: g.outline, accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else { return nil }
      let fill = NSImage(systemSymbolName: g.fill, accessibilityDescription: nil)?.withSymbolConfiguration(config)
      let bolt = g.charging
        ? NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)?.withSymbolConfiguration(boltConfig)
        : nil
      let label = g.text.map {
        NSAttributedString(string: $0, attributes: [.font: font, .foregroundColor: g.tint ?? neutral])
      }
      let width = outline.size.width + (bolt.map { $0.size.width + 1 } ?? 0)
        + (label.map { ceil($0.size().width) + 3 } ?? 0)
      return Prepared(gauge: g, outline: outline, fill: fill, bolt: bolt, label: label, width: width)
    }
    guard !prepared.isEmpty else { return NSImage(size: NSSize(width: 16, height: 16)) }

    let height = max(17 * scale, prepared.map(\.outline.size.height).max() ?? 17)
    let totalWidth = ceil(prepared.map(\.width).reduce(0, +) + gaugeSpacing * CGFloat(prepared.count - 1))
    let image = NSImage(size: NSSize(width: totalWidth, height: height), flipped: false) { rect in
      var x: CGFloat = 0
      for p in prepared {
        let glyph = p.outline.size
        let glyphRect = NSRect(x: x, y: (rect.height - glyph.height) / 2, width: glyph.width, height: glyph.height)
        // A visual floor keeps a nearly-empty fill (and its alert color) visible in the glyph's rounded end;
        // the exact level is in the text beside it.
        let level = p.gauge.fraction > 0 ? max(minimumVisibleFill, min(1, p.gauge.fraction)) : 0
        let solid = p.fill ?? p.outline
        drawSymbol(solid, in: glyphRect, color: neutral, alpha: emptyAlpha, clip: nil)
        if level > 0 {
          let clip = glyph.width > glyph.height
            ? NSRect(x: glyphRect.minX, y: glyphRect.minY, width: glyphRect.width * level, height: glyphRect.height)
            : NSRect(x: glyphRect.minX, y: glyphRect.minY, width: glyphRect.width, height: glyphRect.height * level)
          let color = p.gauge.charging ? chargingColor : p.gauge.tint ?? neutral
          drawSymbol(solid, in: glyphRect, color: color, alpha: 1, clip: clip)
        }
        x = glyphRect.maxX
        if let bolt = p.bolt {
          let boltRect = NSRect(x: x + 1, y: (rect.height - bolt.size.height) / 2, width: bolt.size.width,
                                height: bolt.size.height)
          drawSymbol(bolt, in: boltRect, color: chargingColor, alpha: 1, clip: nil)
          x = boltRect.maxX
        }
        if let label = p.label {
          let size = label.size()
          label.draw(at: NSPoint(x: x + 3, y: (rect.height - size.height) / 2))
          x += ceil(size.width) + 3
        }
        x += gaugeSpacing
      }
      return true
    }
    image.isTemplate = !anyTint
    image.accessibilityDescription = "Logitech battery"
    return image
  }

  /// Draws a symbol in one color at a given opacity, optionally clipped, isolated in its own layer.
  private static func drawSymbol(_ image: NSImage, in rect: NSRect, color: NSColor, alpha: CGFloat, clip: NSRect?) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    ctx.saveGState()
    if let clip { ctx.clip(to: clip) }
    ctx.setAlpha(alpha)
    ctx.beginTransparencyLayer(in: rect, auxiliaryInfo: nil)
    image.draw(in: rect)
    color.set()
    rect.fill(using: .sourceAtop)
    ctx.endTransparencyLayer()
    ctx.restoreGState()
  }
}
