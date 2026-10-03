import JuiceCore
import SwiftUI

/// The alert bar: a battery-shaped 0–100 % track tinted by alert level, with a draggable marker per
/// percent threshold and each device's silhouette riding above it at its live level.
struct ThresholdBar: View {
  @Binding var profile: AlertProfile
  let devices: [SnapshotDevice]

  private let deviceRow: CGFloat = 22
  private let trackHeight: CGFloat = 22
  private let nubWidth: CGFloat = 5
  private let knob: CGFloat = 14

  var body: some View {
    GeometryReader { geo in
      let width = geo.size.width - nubWidth - 2
      ZStack(alignment: .topLeading) {
        deviceGlyphs(width: width)
        track(width: width)
          .offset(y: deviceRow + 4)
        ForEach(ThresholdLayout.markers(profile), id: \.levelID) { marker in
          markerView(marker, width: width)
        }
      }
      .coordinateSpace(name: "thresholdBar")
    }
    .frame(height: deviceRow + 4 + trackHeight + knob + 20)
    .padding(.vertical, 4)
  }

  private func x(_ percent: Int, _ width: CGFloat) -> CGFloat { width * CGFloat(percent) / 100 }

  private func fill(_ tint: IconTint) -> Color {
    tint.color.map { $0.opacity(0.75) } ?? Color.primary.opacity(0.07)
  }

  private func track(width: CGFloat) -> some View {
    HStack(spacing: 2) {
      ZStack(alignment: .leading) {
        ForEach(ThresholdLayout.segments(profile), id: \.from) { seg in
          Rectangle()
            .fill(seg.levelID == nil ? Color.primary.opacity(0.07) : fill(seg.tint))
            .frame(width: max(0, x(seg.to, width) - x(seg.from, width)))
            .offset(x: x(seg.from, width))
        }
      }
      .frame(width: width, height: trackHeight, alignment: .leading)
      .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.primary.opacity(0.25)))
      // The battery terminal.
      RoundedRectangle(cornerRadius: 1.5).fill(Color.primary.opacity(0.25)).frame(width: nubWidth - 2, height: 9)
    }
  }

  private func deviceGlyphs(width: CGFloat) -> some View {
    ForEach(devices.filter { $0.level != nil }) { d in
      let p = d.level?.equivalentPercent ?? 0
      Image(systemName: d.kind.gaugeSymbols.fill)
        .font(.system(size: 13))
        .foregroundStyle(d.tint.color ?? Color.primary.opacity(0.75))
        .frame(width: 20, height: deviceRow)
        .offset(x: x(p, width) - 10)
        .help("\(d.displayName): \(Format.level(d.level ?? .percent(0)))")
        .accessibilityLabel("\(d.displayName) at \(Format.level(d.level ?? .percent(0)))")
    }
  }

  private func markerView(_ m: ThresholdLayout.Marker, width: CGFloat) -> some View {
    let mx = x(m.threshold, width)
    let name = profile.levels[m.levelIndex].name
    return ZStack(alignment: .top) {
      Rectangle()
        .fill(Color.primary.opacity(0.75))
        .frame(width: 2, height: trackHeight + 6)
      Circle()
        .fill(Color(nsColor: .controlBackgroundColor))
        .overlay(Circle().strokeBorder(m.tint.color ?? Color.secondary, lineWidth: 2.5))
        .frame(width: knob, height: knob)
        .offset(y: trackHeight + 4)
      Text("\(m.threshold)%")
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .monospacedDigit()
        .fixedSize()
        .offset(y: trackHeight + knob + 5)
    }
    .frame(width: 44)
    .contentShape(Rectangle())
    .offset(x: mx - 22, y: deviceRow + 1)
    .gesture(
      DragGesture(minimumDistance: 0, coordinateSpace: .named("thresholdBar"))
        .onChanged { value in
          let percent = Int((value.location.x / max(width, 1) * 100).rounded())
          ThresholdLayout.setThreshold(percent, levelAt: m.levelIndex, in: &profile)
        }
    )
    .help("\(name): drag to change")
    .accessibilityElement()
    .accessibilityLabel("\(name) threshold")
    .accessibilityValue("\(m.threshold) percent")
    .accessibilityAdjustableAction { direction in
      let step = direction == .increment ? 1 : -1
      ThresholdLayout.setThreshold(m.threshold + step, levelAt: m.levelIndex, in: &profile)
    }
  }
}
