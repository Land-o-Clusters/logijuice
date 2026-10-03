import Foundation
import JuiceCore

public enum BatteryFeature: Hashable, Sendable {
  case unified(index: UInt8, percent: Bool)
  case legacy(index: UInt8)
  /// 0x1001 voltage-only (common on Lightspeed G-series); percent from a Li-ion curve. Untested on hardware.
  case voltage(index: UInt8)
  case none
}

public struct SlotInfo: Hashable, Sendable {
  public var slot: UInt8
  public var info: DeviceInfo
  public var battery: BatteryFeature

  public init(slot: UInt8, info: DeviceInfo, battery: BatteryFeature) {
    self.slot = slot
    self.info = info
    self.battery = battery
  }
}

public enum SessionEvent: Hashable, Sendable {
  case battery(slot: UInt8, BatteryReport)
  case linkUp(slot: UInt8)
  case linkDown(slot: UInt8)
}

/// Identifies paired devices and reads their batteries. Getter functions only (read-only, spec §1).
public actor ReceiverSession {
  private let broker: RequestBroker

  public init(broker: RequestBroker) { self.broker = broker }

  /// nil when the slot is empty or the device is asleep (no reply / error).
  public func identify(slot: UInt8) async -> SlotInfo? {
    guard (try? await broker.request(device: slot, featureIndex: 0, function: 1, params: [0, 0, 0x5A])) != nil else {
      return nil
    }

    var name = "Logitech device \(slot)"
    var kind = DeviceKind.other
    if let idx = await featureIndex(slot, .deviceNameType) {
      if let countParams = try? await broker.request(device: slot, featureIndex: idx, function: 0),
        let count = countParams.first, count > 0
      {
        var text = ""
        while text.utf8.count < Int(count) {
          guard let chunk = try? await broker.request(device: slot, featureIndex: idx, function: 1,
                                                      params: [UInt8(text.utf8.count)]) else { break }
          let part = FeatureParsers.nameChunk(chunk, remaining: Int(count) - text.utf8.count)
          if part.isEmpty { break }
          text += part
        }
        if !text.isEmpty { name = text }
      }
      if let t = try? await broker.request(device: slot, featureIndex: idx, function: 2), let v = t.first {
        kind = DeviceKind(hidppType: v)
      }
    }

    var id = DeviceID.slot(wpid: 0, slot: slot)
    if let idx = await featureIndex(slot, .deviceInformation),
      let p = try? await broker.request(device: slot, featureIndex: idx, function: 0),
      let info = FeatureParsers.deviceInformation(p)
    {
      if info.serialSupported,
        let sp = try? await broker.request(device: slot, featureIndex: idx, function: 2),
        let serial = FeatureParsers.serialNumber(sp)
      {
        id = .serial(serial)
      } else if let unit = info.unitID {
        id = .unit(unit)
      }
    }

    var battery = BatteryFeature.none
    if let idx = await featureIndex(slot, .unifiedBattery) {
      let caps = try? await broker.request(device: slot, featureIndex: idx, function: 0)
      battery = .unified(index: idx, percent: caps.map(FeatureParsers.unifiedBatteryPercentSupported) ?? false)
    } else if let idx = await featureIndex(slot, .batteryStatus) {
      battery = .legacy(index: idx)
    } else if let idx = await featureIndex(slot, .batteryVoltage) {
      battery = .voltage(index: idx)
    }

    return SlotInfo(slot: slot, info: DeviceInfo(id: id, name: name, kind: kind), battery: battery)
  }

  public func readBattery(_ slot: SlotInfo) async -> BatteryReport? {
    switch slot.battery {
    case .unified(let idx, let percent):
      guard let p = try? await broker.request(device: slot.slot, featureIndex: idx, function: 1) else { return nil }
      return FeatureParsers.unifiedBatteryStatus(p, percentSupported: percent)
    case .legacy(let idx):
      guard let p = try? await broker.request(device: slot.slot, featureIndex: idx, function: 0) else { return nil }
      return FeatureParsers.batteryStatus(p)
    case .voltage(let idx):
      guard let p = try? await broker.request(device: slot.slot, featureIndex: idx, function: 0) else { return nil }
      return FeatureParsers.batteryVoltage(p)
    case .none:
      return nil
    }
  }

  /// Maps an unsolicited frame (from `RequestBroker.events`) to a session event.
  public static func interpret(_ frame: HIDPPFrame, slots: [UInt8: SlotInfo]) -> SessionEvent? {
    if let notice = FeatureParsers.connectionNotice(frame) {
      return notice.linkUp ? .linkUp(slot: notice.slot) : .linkDown(slot: notice.slot)
    }
    guard frame.softwareID == 0, frame.function == 0, let s = slots[frame.deviceIndex] else { return nil }
    switch s.battery {
    case .unified(let idx, let percent) where frame.featureIndex == idx:
      return FeatureParsers.unifiedBatteryStatus(frame.params, percentSupported: percent).map { .battery(slot: s.slot, $0) }
    case .legacy(let idx) where frame.featureIndex == idx:
      return FeatureParsers.batteryStatus(frame.params).map { .battery(slot: s.slot, $0) }
    case .voltage(let idx) where frame.featureIndex == idx:
      return FeatureParsers.batteryVoltage(frame.params).map { .battery(slot: s.slot, $0) }
    default:
      return nil
    }
  }

  private func featureIndex(_ slot: UInt8, _ feature: FeatureID) async -> UInt8? {
    let id = feature.rawValue
    guard let p = try? await broker.request(device: slot, featureIndex: 0, function: 0,
                                            params: [UInt8(id >> 8), UInt8(id & 0xFF)]) else { return nil }
    return FeatureParsers.featureIndex(fromGetFeature: p)
  }
}
