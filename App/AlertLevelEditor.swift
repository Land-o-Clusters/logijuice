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
        TextField("Name", text: $level.name).frame(width: 76)
        TriggerEditor(trigger: $level.trigger)
        Picker("", selection: $level.timing) {
          Text("now").tag(Timing.now)
          Text("at a natural moment").tag(Timing.nextMoment)
        }
        .labelsHidden()
        .fixedSize()
        TintPicker(tint: $level.tint)
      }
      if showAdvanced {
        Picker("Repeat", selection: $level.repeatPolicy) {
          Text("never").tag(RepeatPolicy.never)
          Text("every 4 h").tag(RepeatPolicy.everyHours(4))
          Text("every 12 h").tag(RepeatPolicy.everyHours(12))
          Text("daily").tag(RepeatPolicy.daily)
        }
        .fixedSize()
        .padding(.leading, 28)
      }
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
      Picker("", selection: $tint) {
        Text("no color").tag(IconTint.none)
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
      switch trigger {
      case .percentAtOrBelow(let p):
        Stepper("≤ \(p)", value: Binding(get: { p }, set: { trigger = .percentAtOrBelow($0) }), in: 1...95)
          .fixedSize()
      case .forecastDaysAtOrBelow(let d):
        Stepper("≤ \(Int(d))", value: Binding(get: { Int(d) }, set: { trigger = .forecastDaysAtOrBelow(Double($0)) }),
                in: 1...30)
          .fixedSize()
      }
      Picker("", selection: isPercent) {
        Text("%").tag(true)
        Text("days left").tag(false)
      }
      .labelsHidden()
      .fixedSize()
    }
  }
}
