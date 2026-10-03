import XCTest
@testable import JuiceCore

final class NudgeSchedulerTests: XCTestCase {
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)  // 2027-01-15 08:00:00 UTC

  func decision(_ id: String, _ timing: Timing, device: String = "A") -> AlertDecision {
    AlertDecision(
      device: .serial(device),
      kind: .level(id: id, name: id, timing: timing, severity: 0, isRepeat: false),
      reading: Reading(device: .serial(device), level: .percent(15), charging: false, observedAt: t0))
  }

  func testNextMomentIsHeldUntilAMoment() {
    var s = NudgeScheduler(maxWait: 8 * 3600)
    XCTAssertEqual(s.schedule(decision("low", .nextMoment), now: t0), [])
    XCTAssertEqual(s.pending.count, 1)
    let out = s.onMoment(.screenLocked, now: t0 + 60)
    XCTAssertEqual(out.map(\.moment), [.screenLocked])
    XCTAssertEqual(out.first?.decision, decision("low", .nextMoment))
    XCTAssertTrue(s.pending.isEmpty)
  }

  func testNowIsImmediateAndSupersedesPendingForSameDevice() {
    var s = NudgeScheduler(maxWait: 8 * 3600)
    _ = s.schedule(decision("low", .nextMoment), now: t0)
    _ = s.schedule(decision("low", .nextMoment, device: "B"), now: t0)
    let out = s.schedule(decision("veryLow", .now), now: t0 + 10)
    XCTAssertEqual(out, [Delivery(decision: decision("veryLow", .now), moment: nil)])
    XCTAssertEqual(s.pending.map(\.decision.device), [.serial("B")])
  }

  func testNewerNudgeReplacesOlderForSameDevice() {
    var s = NudgeScheduler(maxWait: 8 * 3600)
    _ = s.schedule(decision("low", .nextMoment), now: t0)
    _ = s.schedule(decision("low2", .nextMoment), now: t0 + 5)
    XCTAssertEqual(s.pending.count, 1)
    XCTAssertEqual(s.pending.first?.queuedAt, t0)  // keeps the original wait clock
  }

  func testMaxWaitDeliversOnTick() {
    var s = NudgeScheduler(maxWait: 8 * 3600)
    _ = s.schedule(decision("low", .nextMoment), now: t0)
    XCTAssertEqual(s.onTick(now: t0 + 8 * 3600 - 1), [])
    XCTAssertEqual(s.onTick(now: t0 + 8 * 3600).map(\.moment), [.maxWait])
    XCTAssertTrue(s.pending.isEmpty)
  }

  func testDropPendingWhenCharging() {
    var s = NudgeScheduler(maxWait: 8 * 3600)
    _ = s.schedule(decision("low", .nextMoment), now: t0)
    s.dropPending(for: .serial("A"))
    XCTAssertEqual(s.onMoment(.willSleep, now: t0 + 1), [])
  }

  func testFullyChargedIsImmediate() {
    var s = NudgeScheduler(maxWait: 8 * 3600)
    let full = AlertDecision(device: .serial("A"), kind: .fullyCharged,
                             reading: Reading(device: .serial("A"), level: .percent(100), charging: false, observedAt: t0))
    XCTAssertEqual(s.schedule(full, now: t0), [Delivery(decision: full, moment: nil)])
  }

  func testNextEndOfDay() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    XCTAssertEqual(NudgeScheduler.nextEndOfDay(after: t0, hour: 17, minute: 30, calendar: cal),
                   t0 + 9.5 * 3600)
    XCTAssertEqual(NudgeScheduler.nextEndOfDay(after: t0 + 10 * 3600, hour: 17, minute: 30, calendar: cal),
                   t0 + 9.5 * 3600 + 86_400)
  }

  func testSchedulerRoundTripsThroughJSON() throws {
    var s = NudgeScheduler(maxWait: 3600)
    _ = s.schedule(decision("low", .nextMoment), now: t0)
    XCTAssertEqual(try JuiceJSON.decoder.decode(NudgeScheduler.self, from: JuiceJSON.encoder.encode(s)), s)
  }
}
