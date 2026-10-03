import Foundation
import JuiceCLIKit
import JuiceStore

let args = Array(CommandLine.arguments.dropFirst())
if args.starts(with: ["debug", "capture"]) {
  exit(DebugCapture.run(arguments: Array(args.dropFirst(2))))
}
let code = CLI.run(
  args, snapshotURL: JuicePaths.standard().cliSnapshotURL,
  out: { print($0) },
  err: { FileHandle.standardError.write(Data(($0 + "\n").utf8)) })
exit(code)
