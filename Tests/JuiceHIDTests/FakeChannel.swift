import Foundation
@testable import JuiceHID

/// In-memory ReportChannel. `responder` maps each sent report to the reports the "receiver" sends back.
final class FakeChannel: ReportChannel, @unchecked Sendable {
  private let lock = NSLock()
  private var handler: (@Sendable ([UInt8]) -> Void)?
  private var _sent: [[UInt8]] = []
  var responder: (([UInt8]) -> [[UInt8]])?
  var failSends = false

  var sent: [[UInt8]] { lock.withLock { _sent } }

  func send(_ bytes: [UInt8]) throws {
    if failSends { throw HIDPPError.sendFailed }
    lock.withLock { _sent.append(bytes) }
    for reply in responder?(bytes) ?? [] { inject(reply) }
  }

  func setReportHandler(_ handler: @escaping @Sendable ([UInt8]) -> Void) {
    lock.withLock { self.handler = handler }
  }

  func inject(_ bytes: [UInt8]) {
    let h = lock.withLock { handler }
    h?(bytes)
  }
}

func long(_ b: [UInt8]) -> [UInt8] { b + Array(repeating: 0, count: 20 - b.count) }
