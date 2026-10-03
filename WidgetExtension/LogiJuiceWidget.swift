import JuiceCore
import JuiceStore
import SwiftUI
import WidgetKit

struct BatteryEntry: TimelineEntry {
  let date: Date
  let snapshot: Snapshot?
}

struct BatteryProvider: TimelineProvider {
  private func load() -> Snapshot? {
    guard let s = SnapshotStore(url: JuicePaths.standard().snapshotURL).read(), s.schema <= Snapshot.currentSchema else {
      return nil
    }
    return s
  }

  func placeholder(in context: Context) -> BatteryEntry { BatteryEntry(date: .now, snapshot: .preview) }

  func getSnapshot(in context: Context, completion: @escaping (BatteryEntry) -> Void) {
    completion(BatteryEntry(date: .now, snapshot: context.isPreview ? .preview : load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryEntry>) -> Void) {
    // The app reloads timelines on every change; the hourly refresh keeps "seen Xh ago" honest.
    completion(Timeline(entries: [BatteryEntry(date: .now, snapshot: load())],
                        policy: .after(.now.addingTimeInterval(3600))))
  }
}

extension IconTint {
  var color: Color? {
    switch self {
    case .none: return nil
    case .yellow: return .yellow
    case .red: return .red
    }
  }
}

struct Ring: View {
  let fraction: Double
  let tint: IconTint

  var body: some View {
    ZStack {
      Circle().stroke(.quaternary, lineWidth: 8)
      Circle()
        .trim(from: 0, to: max(0.02, min(1, fraction)))
        .stroke(tint.color ?? Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
        .rotationEffect(.degrees(-90))
    }
  }
}

struct SmallBatteryView: View {
  let device: SnapshotDevice
  let now: Date

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ZStack {
        Ring(fraction: Double(device.level?.equivalentPercent ?? 0) / 100, tint: device.tint)
        VStack(spacing: 2) {
          Image(systemName: device.charging ? "bolt.fill" : device.kind.symbolName).font(.caption)
          Text(device.level.map(Format.level) ?? "—").font(.title3.bold()).monospacedDigit()
        }
      }
      .frame(width: 80, height: 80)
      Spacer(minLength: 0)
      Text(device.displayName).font(.caption.bold()).lineLimit(1)
      Text(Format.subtitle(device, now: now)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct MediumBatteryView: View {
  let devices: [SnapshotDevice]
  let now: Date

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(devices) { d in
        HStack(spacing: 10) {
          Image(systemName: d.kind.symbolName).frame(width: 20)
          VStack(alignment: .leading, spacing: 1) {
            Text(d.displayName).font(.callout.bold()).lineLimit(1)
            Text(Format.subtitle(d, now: now)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
          }
          Spacer()
          if d.charging { Image(systemName: "bolt.fill").foregroundStyle(.yellow) }
          Text(d.level.map(Format.level) ?? "—")
            .font(.title3.bold()).monospacedDigit()
            .foregroundStyle(d.tint.color ?? Color.primary)
        }
      }
    }
  }
}

struct BatteryWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: BatteryEntry

  var body: some View {
    Group {
      if let snapshot = entry.snapshot, let first = snapshot.lowest ?? snapshot.devices.first {
        if family == .systemSmall {
          SmallBatteryView(device: first, now: entry.date)
        } else {
          MediumBatteryView(devices: Array(snapshot.devices.prefix(3)), now: entry.date)
        }
      } else {
        VStack(spacing: 6) {
          Image(systemName: "battery.0percent").font(.title2)
          Text("Open LogiJuice to start").font(.caption).multilineTextAlignment(.center)
        }
      }
    }
    .containerBackground(.fill.tertiary, for: .widget)
    .widgetURL(URL(string: "logijuice://open"))
  }
}

struct BatteryWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "LogiJuiceBattery", provider: BatteryProvider()) { entry in
      BatteryWidgetView(entry: entry)
    }
    .configurationDisplayName("Logitech Battery")
    .description("Battery for your receiver-connected Logitech keyboard and mouse.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main
struct LogiJuiceWidgets: WidgetBundle {
  var body: some Widget { BatteryWidget() }
}
