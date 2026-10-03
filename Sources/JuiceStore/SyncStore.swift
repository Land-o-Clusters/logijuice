import Foundation
import JuiceCore

/// `iCloud Drive/logijuice/<macID>.json`: each Mac writes only its own file (spec §6).
public struct SyncStore: Sendable {
  public let folder: URL
  public let macID: String

  public init(folder: URL, macID: String) {
    self.folder = folder
    self.macID = macID
  }

  /// iCloud Drive is on when its root (`com~apple~CloudDocs`) exists.
  public var isAvailable: Bool {
    FileManager.default.fileExists(atPath: folder.deletingLastPathComponent().path)
  }

  public var ownURL: URL { folder.appendingPathComponent("\(macID).json") }

  public func writeOwn(_ file: SyncFile) throws { try AtomicFile.write(file, to: ownURL) }

  public func readOthers() -> [SyncFile] {
    guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
    var files: [SyncFile] = []
    for name in names {
      if name.hasPrefix("."), name.hasSuffix(".icloud") {
        // Evicted by iCloud: ask for it; it'll be read on a later poll.
        let real = folder.appendingPathComponent(String(name.dropFirst().dropLast(".icloud".count)))
        try? FileManager.default.startDownloadingUbiquitousItem(at: real)
        continue
      }
      guard name.hasSuffix(".json"), name != "\(macID).json" else { continue }
      guard let data = try? Data(contentsOf: folder.appendingPathComponent(name)),
        let file = try? JuiceJSON.decoder.decode(SyncFile.self, from: data)
      else { continue }
      files.append(file)
    }
    return files.sorted { $0.macID < $1.macID }
  }
}
