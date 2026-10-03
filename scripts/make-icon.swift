// Renders Resources/AppIcon.icns: the app's own idea — a mouse silhouette used as a battery gauge — filled
// ~70% with a liquid surface ("juice") on a citrus tile. Run: swift scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
  let s = CGFloat(px)
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  let ctx = NSGraphicsContext.current!.cgContext

  // macOS icon grid: 824/1024 artwork inside the canvas, continuous-corner tile.
  let inset = s * 100 / 1024
  let tile = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
  let tilePath = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.2237, yRadius: tile.width * 0.2237)
  NSGradient(colors: [NSColor(srgbRed: 1.00, green: 0.71, blue: 0.16, alpha: 1),
                      NSColor(srgbRed: 1.00, green: 0.45, blue: 0.10, alpha: 1)])!
    .draw(in: tilePath, angle: -90)

  // The mouse silhouette, as a template glyph.
  let config = NSImage.SymbolConfiguration(pointSize: s * 0.52, weight: .regular)
  let mouse = NSImage(systemSymbolName: "computermouse.fill", accessibilityDescription: nil)!
    .withSymbolConfiguration(config)!
  let g = mouse.size
  let glyphRect = NSRect(x: (s - g.width) / 2, y: (s - g.height) / 2 - s * 0.01, width: g.width, height: g.height)

  func drawGlyph(alpha: CGFloat, clip: NSBezierPath?) {
    ctx.saveGState()
    clip?.addClip()
    ctx.setAlpha(alpha)
    ctx.beginTransparencyLayer(in: glyphRect, auxiliaryInfo: nil)
    mouse.draw(in: glyphRect)
    NSColor.white.set()
    glyphRect.fill(using: .sourceAtop)
    ctx.endTransparencyLayer()
    ctx.restoreGState()
  }

  // Empty part: dim. Filled part: solid, with a gentle wave at the surface.
  drawGlyph(alpha: 0.38, clip: nil)
  let level = glyphRect.minY + glyphRect.height * 0.68
  let wave = NSBezierPath()
  wave.move(to: NSPoint(x: glyphRect.minX - 2, y: glyphRect.minY - 2))
  wave.line(to: NSPoint(x: glyphRect.minX - 2, y: level))
  let steps = 48
  for i in 0...steps {
    let t = CGFloat(i) / CGFloat(steps)
    let x = glyphRect.minX - 2 + t * (glyphRect.width + 4)
    wave.line(to: NSPoint(x: x, y: level + sin(t * .pi * 2.2) * glyphRect.height * 0.025))
  }
  wave.line(to: NSPoint(x: glyphRect.maxX + 2, y: glyphRect.minY - 2))
  wave.close()
  drawGlyph(alpha: 1, clip: wave)

  NSGraphicsContext.restoreGraphicsState()
  return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
  try render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
  try render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let out = root.appendingPathComponent("Resources/AppIcon.icns")
try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try task.run()
task.waitUntilExit()
try render(1024).write(to: FileManager.default.temporaryDirectory.appendingPathComponent("logijuice-icon-preview.png"))
print(task.terminationStatus == 0 ? "wrote \(out.path)" : "iconutil failed: \(task.terminationStatus)")
exit(task.terminationStatus)
