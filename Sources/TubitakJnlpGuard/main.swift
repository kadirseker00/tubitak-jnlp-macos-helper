import Darwin
import Foundation
import TubitakJnlpCore

private enum Command {
  case scan(URL)
  case authorize(URL)
  case help
}

private func downloadsDirectory() -> URL {
  FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
}

private func parseCommand(_ arguments: [String]) -> Command {
  guard let first = arguments.first else {
    return .scan(downloadsDirectory())
  }

  switch first {
  case "--scan":
    return .scan(downloadsDirectory())
  case "--authorize":
    return .authorize(downloadsDirectory())
  case "--scan-directory" where arguments.count == 2:
    return .scan(URL(fileURLWithPath: arguments[1], isDirectory: true))
  case "--help", "-h":
    return .help
  default:
    return .help
  }
}

private func printHelp() {
  print(
    """
    Usage: TubitakJnlpGuard [--scan | --authorize | --scan-directory PATH]

      --scan                 Scan the current user's Downloads directory.
      --authorize            Request Downloads access and record authorization.
      --scan-directory PATH  Scan a specific directory (development/testing).
    """
  )
}

private func writeAuthorizationMarker() throws {
  let supportDirectory = FileManager.default
    .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("TubitakJnlpGuard", isDirectory: true)
  try FileManager.default.createDirectory(
    at: supportDirectory,
    withIntermediateDirectories: true
  )
  try Data("authorized\n".utf8).write(
    to: supportDirectory.appendingPathComponent("authorization.ok"),
    options: [.atomic]
  )
}

private let command = parseCommand(Array(CommandLine.arguments.dropFirst()))

switch command {
case .help:
  printHelp()
  exit(EXIT_SUCCESS)

case .scan(let directory), .authorize(let directory):
  do {
    let summary = try JnlpScanner().scan(directoryURL: directory)
    print(
      "scan entries=\(summary.entriesExamined) " + "jnlp=\(summary.jnlpCandidates) "
        + "trusted=\(summary.trustedCandidates) "
        + "removed=\(summary.quarantineAttributesRemoved) " + "failures=\(summary.failures)"
    )
    if case .authorize = command {
      try writeAuthorizationMarker()
    }
    exit(summary.failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE)
  } catch {
    fputs("TubitakJnlpGuard: \(error.localizedDescription)\n", stderr)
    exit(EXIT_FAILURE)
  }
}
