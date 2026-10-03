import Foundation

/// One JSON configuration for every file logijuice writes (settings, state, snapshot, sync).
public enum JuiceJSON {
  public static var encoder: JSONEncoder {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return e
  }

  public static var prettyEncoder: JSONEncoder {
    let e = encoder
    e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
    return e
  }

  public static var decoder: JSONDecoder {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
  }
}
