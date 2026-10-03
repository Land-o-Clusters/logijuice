import JuiceCore
import SwiftUI

/// The device row's health line; opens a small explanation with a days-per-charge sparkline.
struct HealthLine: View {
  let report: HealthReport
  @State private var open = false

  var body: some View {
    Button { open.toggle() } label: {
      HStack(spacing: 4) {
        Image(systemName: "heart").font(.system(size: 9, weight: .semibold))
        Text(Format.health(report))
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .help("Battery health, estimated from your usage")
    .popover(isPresented: $open, arrowEdge: .bottom) { HealthDetail(report: report) }
  }
}

struct HealthDetail: View {
  let report: HealthReport

  private var since: String {
    guard let s = report.since else { return "" }
    return s.formatted(.dateTime.month(.abbreviated).day())
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Battery health").font(.system(.headline, design: .rounded))
      if report.series.count >= 2 {
        Sparkline(values: report.series)
          .frame(height: 46)
        Text("Days per full charge, one point per charge since \(since).")
          .font(.caption).foregroundStyle(.secondary)
      } else {
        Text("Health appears after \(HealthReport.runsNeeded) full charges. So far: \(report.completedRuns).")
          .font(.callout)
      }
      Text(report.cycles < 1 ? "Less than one full charge cycle recorded." : "About \(Int(report.cycles.rounded())) charge cycles recorded.")
        .font(.callout)
      Text("Estimated from how fast the battery drains. Logitech devices don't report capacity or cycle counts.")
        .font(.caption).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(14)
    .frame(width: 290)
  }
}

struct Sparkline: View {
  let values: [Double]

  var body: some View {
    GeometryReader { geo in
      let lo = (values.min() ?? 0) * 0.9
      let hi = max((values.max() ?? 1) * 1.05, lo + 1)
      let points = values.enumerated().map { i, v in
        CGPoint(x: geo.size.width * CGFloat(i) / CGFloat(max(values.count - 1, 1)),
                y: geo.size.height * (1 - CGFloat((v - lo) / (hi - lo))))
      }
      ZStack {
        Path { p in
          guard let first = points.first else { return }
          p.move(to: first)
          points.dropFirst().forEach { p.addLine(to: $0) }
        }
        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        if let last = points.last {
          Circle().fill(Color.accentColor).frame(width: 6, height: 6).position(last)
        }
      }
    }
    .accessibilityElement()
    .accessibilityLabel("Days per charge over time")
    .accessibilityValue(values.map { "\(Int($0.rounded()))" }.joined(separator: ", "))
  }
}
