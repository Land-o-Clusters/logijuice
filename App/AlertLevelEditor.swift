import JuiceCore
import SwiftUI

struct LevelList: View {
  @Binding var profile: AlertProfile
  let showAdvanced: Bool

  var body: some View {
    ForEach($profile.levels) { $level in
      LevelRow(level: $level, showAdvanced: showAdvanced)
    }
  }
}

struct LevelRow: View {
  @Binding var level: AlertLevel
  let showAdvanced: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Toggle("", isOn: $level.enabled).labelsHidden()
        TextField("Name", text: $level.name)
          .labelsHidden()
          .textFieldStyle(.roundedBorder)
          .frame(width: 110)
        Spacer(minLength: 8)
        TriggerEditor(trigger: $level.trigger)
      }
      HStack(spacing: 12) {
        Text("Alert").foregroundStyle(.secondary)
        Picker("Alert", selection: $level.timing) {
          Text("right away").tag(Timing.now)
          Text("at a natural moment").tag(Timing.nextMoment)
        }
        .labelsHidden()
        .fixedSize()
        TintPicker(tint: $level.tint)
        if showAdvanced {
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
      }
      .font(.callout)
      .padding(.leading, 40)
    }
    .opacity(level.enabled ? 1 : 0.5)
  }
}

/// Icon color a fired level gives its device in the menu bar and widget.
struct TintPicker: View {
  @Binding var tint: IconTint

  var body: some View {
    HStack(spacing: 4) {
      Circle()
        .fill(tint.color ?? Color.secondary.opacity(0.25))
        .frame(width: 10, height: 10)
      Text("Color").foregroundStyle(.secondary)
      Picker("Color", selection: $tint) {
        Text("none").tag(IconTint.none)
        Text("yellow").tag(IconTint.yellow)
        Text("red").tag(IconTint.red)
      }
      .labelsHidden()
      .fixedSize()
    }
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
      // Explicit value text + label-less stepper: inside a grouped Form a labelled stepper grows a label column.
      switch trigger {
      case .percentAtOrBelow(let p):
        Text("≤ \(p)").monospacedDigit()
        Stepper("Threshold", value: Binding(get: { p }, set: { trigger = .percentAtOrBelow($0) }), in: 1...95)
          .labelsHidden()
      case .forecastDaysAtOrBelow(let d):
        Text("≤ \(Int(d))").monospacedDigit()
        Stepper("Threshold", value: Binding(get: { Int(d) }, set: { trigger = .forecastDaysAtOrBelow(Double($0)) }),
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
