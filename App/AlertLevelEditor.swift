import JuiceCore
import SwiftUI

/// One line per level: on/off, color, name, timing, threshold. Percent thresholds are dragged on the alert bar;
/// "days left" thresholds use the stepper here.
struct LevelRow: View {
  @Binding var level: AlertLevel
  let showAdvanced: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 10) {
        Toggle("\(level.name) enabled", isOn: $level.enabled)
          .labelsHidden()
          .toggleStyle(.switch)
          .controlSize(.small)
        GlassDropdown(selection: $level.tint,
                      options: [(.none, "No color"), (.yellow, "Yellow"), (.red, "Red")],
                      swatch: { $0.color ?? Color.secondary.opacity(0.25) },
                      accessibilityName: "\(level.name) icon color")
        TextField("Name", text: $level.name)
          .labelsHidden()
          .textFieldStyle(.plain)
          .font(.system(.body, design: .rounded).weight(.medium))
          .frame(width: 88)
          .padding(.horizontal, 10)
          .padding(.vertical, 4)
          .background(Color.primary.opacity(0.06), in: Capsule())
        GlassDropdown(selection: $level.timing,
                      options: [(.now, "Alert right away"), (.nextMoment, "Wait for a natural moment")],
                      accessibilityName: "\(level.name) timing")
        Spacer(minLength: 4)
        TriggerEditor(trigger: $level.trigger, levelName: level.name)
      }
      if showAdvanced {
        HStack(spacing: 8) {
          Text("Repeat").foregroundStyle(.secondary)
          GlassDropdown(selection: $level.repeatPolicy,
                        options: [(.never, "Never"), (.everyHours(4), "Every 4 hours"),
                                  (.everyHours(12), "Every 12 hours"), (.daily, "Daily")],
                        accessibilityName: "\(level.name) repeat")
        }
        .font(.callout)
        .padding(.leading, 52)
      }
    }
    .opacity(level.enabled ? 1 : 0.45)
  }
}

struct TriggerEditor: View {
  @Binding var trigger: Trigger
  let levelName: String

  private var unit: Binding<Bool> {
    Binding(
      get: { if case .percentAtOrBelow = trigger { return true } else { return false } },
      set: { trigger = $0 ? .percentAtOrBelow(20) : .forecastDaysAtOrBelow(3) })
  }

  var body: some View {
    HStack(spacing: 6) {
      switch trigger {
      case .percentAtOrBelow(let p):
        Text("≤ \(p)%")
          .font(.system(.body, design: .rounded).weight(.semibold))
          .monospacedDigit()
          .help("Drag the marker on the bar to change")
      case .forecastDaysAtOrBelow(let d):
        Text("≤ \(Int(d)) days")
          .font(.system(.body, design: .rounded).weight(.semibold))
          .monospacedDigit()
        Stepper("\(levelName) days left",
                value: Binding(get: { Int(d) }, set: { trigger = .forecastDaysAtOrBelow(Double($0)) }), in: 1...30)
          .labelsHidden()
      }
      GlassDropdown(selection: unit, options: [(true, "%"), (false, "days left")],
                    accessibilityName: "\(levelName) threshold unit")
    }
  }
}
