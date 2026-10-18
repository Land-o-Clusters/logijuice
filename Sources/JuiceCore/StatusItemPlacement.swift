import CoreGraphics
import Foundation

/// Detects a menu bar item that macOS has parked off the menu bar while the app still shows it (seen 2026-10-18,
/// after days of uptime: the item sat below the bottom edge of the screen until the app relaunched).
public enum StatusItemPlacement {
  /// How far from a screen's top edge, inside or above it, an item still counts as in the menu bar.
  public static let menuBarBand: CGFloat = 64
  /// Re-adding the item at most this often, so a cause re-adding can't fix doesn't churn the menu bar.
  public static let minimumInterval: TimeInterval = 600

  /// Frames are AppKit global coordinates (origin bottom-left). True when the app has items and none of them sits
  /// at the top edge of any screen.
  public static func isStranded(itemFrames: [CGRect], screenFrames: [CGRect]) -> Bool {
    guard !itemFrames.isEmpty, !screenFrames.isEmpty else { return false }
    return !itemFrames.contains { item in
      screenFrames.contains { screen in
        item.midX >= screen.minX && item.midX <= screen.maxX
          && item.midY >= screen.maxY - menuBarBand && item.midY <= screen.maxY + menuBarBand
      }
    }
  }

  public static func shouldReinsert(stranded: Bool, lastReinsert: Date?, now: Date) -> Bool {
    guard stranded else { return false }
    guard let lastReinsert else { return true }
    return now.timeIntervalSince(lastReinsert) >= minimumInterval
  }
}
