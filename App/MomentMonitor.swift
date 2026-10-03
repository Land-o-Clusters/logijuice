import AppKit
import JuiceCore

/// Turns system signals into natural moments for the nudge scheduler (spec §4).
@MainActor
final class MomentMonitor {
  var onMoment: ((Moment) -> Void)?
  private var observers: [NSObjectProtocol] = []
  private var endOfDayTimer: Timer?

  func start(endOfDayHour: Int, minute: Int) {
    observers.append(DistributedNotificationCenter.default().addObserver(
      forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
    ) { [weak self] _ in MainActor.assumeIsolated { self?.onMoment?(.screenLocked) } })
    let workspace = NSWorkspace.shared.notificationCenter
    for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
      observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.onMoment?(.willSleep) }
      })
    }
    reschedule(endOfDayHour: endOfDayHour, minute: minute)
  }

  func reschedule(endOfDayHour: Int, minute: Int) {
    endOfDayTimer?.invalidate()
    let fire = NudgeScheduler.nextEndOfDay(after: Date(), hour: endOfDayHour, minute: minute, calendar: .current)
    let timer = Timer(fire: fire, interval: 0, repeats: false) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.onMoment?(.endOfDay)
        self?.reschedule(endOfDayHour: endOfDayHour, minute: minute)
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    endOfDayTimer = timer
  }
}
