import Foundation

public struct ScanSummary: Equatable, Sendable {
  public var entriesExamined = 0
  public var jnlpCandidates = 0
  public var trustedCandidates = 0
  public var quarantineAttributesRemoved = 0
  public var failures = 0

  public init() {}
}

public struct JnlpScanner: Sendable {
  private let policy: JnlpValidationPolicy

  public init(policy: JnlpValidationPolicy = .init()) {
    self.policy = policy
  }

  public func scan(directoryURL: URL) throws -> ScanSummary {
    let keys: [URLResourceKey] = [
      .isRegularFileKey,
      .isSymbolicLinkKey,
    ]
    let items = try FileManager.default.contentsOfDirectory(
      at: directoryURL,
      includingPropertiesForKeys: keys,
      options: [.skipsHiddenFiles]
    )

    var summary = ScanSummary()

    for fileURL in items {
      summary.entriesExamined += 1

      guard fileURL.pathExtension.lowercased() == "jnlp",
        let values = try? fileURL.resourceValues(forKeys: Set(keys)),
        values.isRegularFile == true,
        values.isSymbolicLink != true
      else {
        continue
      }
      summary.jnlpCandidates += 1

      do {
        guard
          try ExtendedAttributes.data(
            for: ExtendedAttributes.quarantine,
            at: fileURL
          ) != nil,
          let whereFromsData = try ExtendedAttributes.data(
            for: ExtendedAttributes.whereFroms,
            at: fileURL
          ),
          JnlpValidator.isTrusted(
            fileURL: fileURL,
            whereFromsData: whereFromsData,
            policy: policy
          )
        else {
          continue
        }

        summary.trustedCandidates += 1
        try ExtendedAttributes.remove(ExtendedAttributes.quarantine, at: fileURL)
        summary.quarantineAttributesRemoved += 1
      } catch {
        summary.failures += 1
      }
    }

    return summary
  }
}
