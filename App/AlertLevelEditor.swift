import JuiceCore
import SwiftUI

struct LevelList: View {
  @Binding var profile: AlertProfile
  let showAdvanced: Bool
  var devices: [SnapshotDevice] = []
  var showsBar = true

  var body: some View {
    if showsBar {
      ThresholdBar(profile: $profile, devices: devices)
    }
    ForEach($profile.levels) { $level in
      LevelRow(level: $level, showAdvanced: showAdvanced)
    }
  }
}

/// One line per level; percent thresholds are edited on the alert bar, "days left" ones here.
struct LevelRow: View {
  @Binding var level: AlertLevel
  let showAdvanced: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 10) {
        Toggle("Enabled", isOn: $level.enabled).labelsHidden()
        TintPicker(tint: $level.tint)
        TextField("Name", text: $level.name)
          .labelsHidden()
          .textFieldStyle(.roundedBorder)
          .frame(width: 104)
        Picker("When", selection: $level.timing) {
          Text("alert right away").tag(Timing.now)
          Text("wait for a natural moment").tag(Timing.nextMoment)
        }
        .labelsHidden()
        .fixedSize()
        Spacer(minLength: 4)
        TriggerEditor(trigger: $level.trigger)
      }
      if showAdvanced {
        HStack(spacing: 8) {
          Text("Repeat").foregroundStyle(.secondary)
          Picker("Repeat", selection: $level.repeatPolicy) {
            Text("never").tag(RepeatPolicy.never)
            Text("every 4 h").tag(RepeatPolicy.everyHours(4))
            Text("every 12 h").tag(RepeatPolicy.everyHours(12))
            Text("daily").tag(RepeatPolicy.daily)
          }
          .labelsHidden()
          .fixedSize()
        }
        .font(.callout)
        .padding(.leading, 50)
      }
    }
    .opacity(level.enabled ? 1 : 0.5)
  }
}

/// Icon color a fired level gives its device in the menu bar and widget.
/// (A `Menu` can't draw a custom shape as its label on macOS, so the dot sits beside a compact picker.)
struct TintPicker: View {
  @Binding var tint: IconTint

  var body: some View {
    HStack(spacing: 3) {
      Circle()
        .fill(tint.color ?? Color.secondary.opacity(0.25))
        .overlay(Circle().strokeBorder(Color.primary.opacity(0.2)))
        .frame(width: 11, height: 11)
      Picker("Color", selection: $tint) {
        Text("none").tag(IconTint.none)
        Text("yellow").tag(IconTint.yellow)
        Text("red").tag(IconTint.red)
      }
      .labelsHidden()
      .fixedSize()
    }
    .frame(width: 96, alignment: .leading)
    .help("Icon color while this level is active")
  }
}

struct TriggerEditor: View {
  @Binding var trigger: Trigger

  private var isPercent: Binding<Bool> {
    Binding(
      get: { if case .percentAtOrBelow = trigger { return true } else { return false } },
      set: { trigger = $0 ? .percentAtOrBelow(20) : .forecastDaysAtOrBelow(3) })
  }

  var body: some View {
    HStack(spacing: 4) {
      switch trigger {
      case .percentAtOrBelow(let p):
        Text("≤ \(p)%")
          .font(.system(.body, design: .rounded).weight(.medium))
          .monospacedDigit()
      case .forecastDaysAtOrBelow(let d):
        Text("≤ \(Int(d))").font(.system(.body, design: .rounded).weight(.medium)).monospacedDigit()
        Stepper("Days left", value: Binding(get: { Int(d) }, set: { trigger = .forecastDaysAtOrBelow(Double($0)) }),
                in: 1...30)
          .labelsHidden()
      }
      Picker("Unit", selection: isPercent) {
        Text("%").tag(true)
        Text("days left").tag(false)
      }
      .labelsHidden()
      .fixedSize()
    }
  }
}
