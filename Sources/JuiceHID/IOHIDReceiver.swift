import Foundation
import IOKit.hid

public enum HIDPPInterface {
  public static let vendorID = 0x046D
  /// Bolt, Unifying, Unifying (newer).
  public static let receiverProductIDs = [0xC548, 0xC52B, 0xC532]
  public static let usagePage = 0xFF00
  static let shortUsage = 0x0001
  static let longUsage = 0x0002
}

private func intProperty(_ d: IOHIDDevice, _ key: String) -> Int {
  (IOHIDDeviceGetProperty(d, key as CFString) as? Int) ?? -1
}

/// All vendor-page collections of one physical receiver. Opened non-exclusively (coexists with Options+).
public final class IOHIDReceiverChannel: ReportChannel, @unchecked Sendable {
  public let devices: [IOHIDDevice]
  private let lock = NSLock()
  private var handler: (@Sendable ([UInt8]) -> Void)?
  private var buffers: [UnsafeMutablePointer<UInt8>] = []
  private var opened: [IOHIDDevice] = []

  public init(devices: [IOHIDDevice]) throws {
    self.devices = devices
    let context = Unmanaged.passUnretained(self).toOpaque()
    for device in devices {
      guard IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else { continue }
      let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
      buffers.append(buffer)
      opened.append(device)
      IOHIDDeviceRegisterInputReportCallback(device, buffer, 64, { ctx, _, _, _, reportID, report, length in
        guard let ctx else { return }
        let channel = Unmanaged<IOHIDReceiverChannel>.fromOpaque(ctx).takeUnretainedValue()
        var bytes = Array(UnsafeBufferPointer(start: report, count: length))
        if bytes.first != UInt8(truncatingIfNeeded: reportID) { bytes.insert(UInt8(truncatingIfNeeded: reportID), at: 0) }
        channel.deliver(bytes)
      }, context)
      IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }
    guard !opened.isEmpty else { throw HIDPPError.sendFailed }
  }

  deinit {
    close()
    buffers.forEach { $0.deallocate() }
  }

  public func send(_ bytes: [UInt8]) throws {
    guard let first = bytes.first else { throw HIDPPError.sendFailed }
    let wanted = first == 0x10 ? HIDPPInterface.shortUsage : HIDPPInterface.longUsage
    guard let target = opened.first(where: { intProperty($0, kIOHIDPrimaryUsageKey) == wanted }) ?? opened.first else {
      throw HIDPPError.closed
    }
    let result = IOHIDDeviceSetReport(target, kIOHIDReportTypeOutput, CFIndex(first), bytes, bytes.count)
    guard result == kIOReturnSuccess else { throw HIDPPError.sendFailed }
  }

  public func setReportHandler(_ handler: @escaping @Sendable ([UInt8]) -> Void) {
    lock.withLock { self.handler = handler }
  }

  public func close() {
    for device in opened {
      IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
      IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
    }
    opened = []
  }

  private func deliver(_ bytes: [UInt8]) {
    let h = lock.withLock { handler }
    h?(bytes)
  }
}

/// Watches for the receiver arriving and leaving (the hub switching Macs). Main run loop only.
public final class ReceiverMonitor {
  public var onArrive: ((IOHIDReceiverChannel) -> Void)?
  public var onDepart: (() -> Void)?

  private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
  private var matched: [IOHIDDevice] = []
  private var channel: IOHIDReceiverChannel?
  private var settle: DispatchWorkItem?

  public init() {}

  public func start() {
    let criteria = HIDPPInterface.receiverProductIDs.map {
      [kIOHIDVendorIDKey: HIDPPInterface.vendorID, kIOHIDProductIDKey: $0,
       kIOHIDDeviceUsagePageKey: HIDPPInterface.usagePage] as [String: Any]
    }
    IOHIDManagerSetDeviceMatchingMultiple(manager, criteria as CFArray)
    let context = Unmanaged.passUnretained(self).toOpaque()
    IOHIDManagerRegisterDeviceMatchingCallback(manager, { ctx, _, _, device in
      guard let ctx else { return }
      Unmanaged<ReceiverMonitor>.fromOpaque(ctx).takeUnretainedValue().added(device)
    }, context)
    IOHIDManagerRegisterDeviceRemovalCallback(manager, { ctx, _, _, device in
      guard let ctx else { return }
      Unmanaged<ReceiverMonitor>.fromOpaque(ctx).takeUnretainedValue().removed(device)
    }, context)
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
  }

  private func added(_ device: IOHIDDevice) {
    matched.append(device)
    // Collections of one receiver arrive one by one; wait for them to settle.
    settle?.cancel()
    let work = DispatchWorkItem { [weak self] in self?.emit() }
    settle = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
  }

  private func emit() {
    guard channel == nil, let first = matched.first else { return }
    let location = intProperty(first, kIOHIDLocationIDKey)
    let group = matched.filter { intProperty($0, kIOHIDLocationIDKey) == location }
    guard let ch = try? IOHIDReceiverChannel(devices: group) else { return }
    channel = ch
    onArrive?(ch)
  }

  private func removed(_ device: IOHIDDevice) {
    matched.removeAll { $0 == device }
    if let ch = channel, ch.devices.contains(device) {
      ch.close()
      channel = nil
      onDepart?()
      if !matched.isEmpty { emit() }  // a second receiver was also attached
    }
  }
}
