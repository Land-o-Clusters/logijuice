import Foundation

public protocol ReportChannel: AnyObject, Sendable {
  func send(_ bytes: [UInt8]) throws
  func setReportHandler(_ handler: @escaping @Sendable ([UInt8]) -> Void)
}

public enum HIDPPError: Error, Equatable, Sendable {
  case timeout
  case sendFailed
  case closed
  case protocolError(code: UInt8)
}

/// Serializes HID++ requests on one receiver and routes replies by software ID, so logijuice
/// coexists with Logi Options+ on the same non-exclusively opened device (spec §3).
public actor RequestBroker {
  public static let defaultSoftwareID: UInt8 = 0x0A

  public nonisolated let events: AsyncStream<HIDPPFrame>
  public let softwareID: UInt8

  private let channel: ReportChannel
  private let eventSink: AsyncStream<HIDPPFrame>.Continuation
  private let inbound: AsyncStream<[UInt8]>
  private let inboundSink: AsyncStream<[UInt8]>.Continuation
  private var pending: Pending?
  private var nextToken = 0
  private var inFlight = false
  private var waiters: [CheckedContinuation<Void, Never>] = []
  private var closed = false
  private var pump: Task<Void, Never>?

  private struct Pending {
    let token: Int
    let device: UInt8
    let featureIndex: UInt8
    let functionAndSoftwareID: UInt8
    let continuation: CheckedContinuation<[UInt8], Error>
  }

  public init(channel: ReportChannel, softwareID: UInt8 = RequestBroker.defaultSoftwareID) {
    precondition((1...0x0F).contains(softwareID), "software ID must be 1...15")
    self.channel = channel
    self.softwareID = softwareID
    let (events, eventSink) = AsyncStream.makeStream(of: HIDPPFrame.self)
    self.events = events
    self.eventSink = eventSink
    let (inbound, inboundSink) = AsyncStream.makeStream(of: [UInt8].self)
    self.inbound = inbound
    self.inboundSink = inboundSink
    channel.setReportHandler { bytes in inboundSink.yield(bytes) }
  }

  /// Begins consuming inbound reports in arrival order. Reports received earlier are buffered.
  public nonisolated func start() {
    Task { await self.beginPump() }
  }

  private func beginPump() {
    guard pump == nil, !closed else { return }
    let stream = inbound
    pump = Task { [weak self] in
      for await bytes in stream { await self?.handle(bytes) }
    }
  }

  public func request(device: UInt8, featureIndex: UInt8, function: UInt8, params: [UInt8] = [],
                      timeout: Duration = .seconds(2)) async throws -> [UInt8] {
    await acquire()
    defer { release() }
    if closed { throw HIDPPError.closed }
    let frame = HIDPPFrame.request(device: device, featureIndex: featureIndex, function: function,
                                   softwareID: softwareID, params: params)
    nextToken += 1
    let token = nextToken
    return try await withCheckedThrowingContinuation { continuation in
      pending = Pending(token: token, device: device, featureIndex: featureIndex,
                        functionAndSoftwareID: frame.functionAndSoftwareID, continuation: continuation)
      do {
        try channel.send(frame.bytes)
      } catch {
        pending = nil
        continuation.resume(throwing: HIDPPError.sendFailed)
        return
      }
      Task { [weak self] in
        try? await Task.sleep(for: timeout)
        await self?.expire(token)
      }
    }
  }

  public func close() {
    closed = true
    if let p = pending {
      pending = nil
      p.continuation.resume(throwing: HIDPPError.closed)
    }
    pump?.cancel()
    inboundSink.finish()
    eventSink.finish()
  }

  func handle(_ bytes: [UInt8]) {
    guard let frame = HIDPPFrame(bytes: bytes) else { return }
    if let p = pending, Self.matches(frame, p) {
      pending = nil
      if frame.isError {
        p.continuation.resume(throwing: HIDPPError.protocolError(code: frame.params.count > 1 ? frame.params[1] : 0))
      } else {
        p.continuation.resume(returning: frame.params)
      }
      return
    }
    if frame.isNotification || (frame.softwareID == 0 && !frame.isError) {
      eventSink.yield(frame)
    }
  }

  private func expire(_ token: Int) {
    guard let p = pending, p.token == token else { return }
    pending = nil
    p.continuation.resume(throwing: HIDPPError.timeout)
  }

  private static func matches(_ f: HIDPPFrame, _ p: Pending) -> Bool {
    guard f.deviceIndex == p.device else { return false }
    if f.isError {
      return f.functionAndSoftwareID == p.featureIndex && f.params.first == p.functionAndSoftwareID
    }
    return f.featureIndex == p.featureIndex && f.functionAndSoftwareID == p.functionAndSoftwareID
  }

  private func acquire() async {
    if !inFlight {
      inFlight = true
      return
    }
    await withCheckedContinuation { waiters.append($0) }
  }

  private func release() {
    if waiters.isEmpty {
      inFlight = false
    } else {
      waiters.removeFirst().resume()
    }
  }
}
