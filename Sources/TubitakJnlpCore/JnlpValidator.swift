import Foundation

public struct JnlpValidationPolicy: Sendable {
  public let trustedHost: String
  public let requiredCodebasePathPrefix: String
  public let maximumFileSize: Int

  public init(
    trustedHost: String = "e-imza.tubitak.gov.tr",
    requiredCodebasePathPrefix: String = "/sublimity-ess/jnlp/",
    maximumFileSize: Int = 1_048_576
  ) {
    self.trustedHost = trustedHost.lowercased()
    self.requiredCodebasePathPrefix = requiredCodebasePathPrefix
    self.maximumFileSize = maximumFileSize
  }
}

public enum JnlpValidator {
  public static func isTrusted(
    fileURL: URL,
    whereFromsData: Data,
    policy: JnlpValidationPolicy = .init()
  ) -> Bool {
    guard fileURL.pathExtension.lowercased() == "jnlp",
      isTrustedOrigin(whereFromsData, policy: policy),
      let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
      let fileSize = values.fileSize,
      fileSize <= policy.maximumFileSize,
      let documentData = try? Data(contentsOf: fileURL, options: [.mappedIfSafe])
    else {
      return false
    }

    return isTrustedDocument(documentData, policy: policy)
  }

  public static func isTrustedOrigin(
    _ whereFromsData: Data,
    policy: JnlpValidationPolicy = .init()
  ) -> Bool {
    guard
      let value = try? PropertyListSerialization.propertyList(
        from: whereFromsData,
        options: [],
        format: nil
      ),
      let origins = value as? [String],
      let firstOrigin = origins.first,
      let originURL = URL(string: firstOrigin)
    else {
      return false
    }

    return isTrustedHTTPSURL(originURL, policy: policy)
  }

  public static func isTrustedDocument(
    _ documentData: Data,
    policy: JnlpValidationPolicy = .init()
  ) -> Bool {
    let delegate = JnlpParserDelegate()
    let parser = XMLParser(data: documentData)
    parser.delegate = delegate
    parser.shouldResolveExternalEntities = false

    guard parser.parse(),
      delegate.sawJnlpRoot,
      let codebaseString = delegate.codebase,
      let codebaseURL = URL(string: codebaseString),
      isTrustedHTTPSURL(codebaseURL, policy: policy),
      isAllowedCodebasePath(codebaseURL.path, policy: policy),
      !delegate.jarReferences.isEmpty
    else {
      return false
    }

    return delegate.jarReferences.allSatisfy { reference in
      guard let jarURL = URL(string: reference, relativeTo: codebaseURL)?.absoluteURL else {
        return false
      }
      return jarURL.pathExtension.lowercased() == "jar" && isTrustedHTTPSURL(jarURL, policy: policy)
    }
  }

  private static func isTrustedHTTPSURL(
    _ url: URL,
    policy: JnlpValidationPolicy
  ) -> Bool {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
      components.scheme?.lowercased() == "https",
      components.host?.lowercased() == policy.trustedHost,
      components.user == nil,
      components.password == nil
    else {
      return false
    }

    return components.port == nil || components.port == 443
  }

  private static func isAllowedCodebasePath(
    _ path: String,
    policy: JnlpValidationPolicy
  ) -> Bool {
    let requiredPath =
      policy.requiredCodebasePathPrefix.hasSuffix("/")
      ? String(policy.requiredCodebasePathPrefix.dropLast())
      : policy.requiredCodebasePathPrefix
    return path == requiredPath || path.hasPrefix(requiredPath + "/")
  }
}

private final class JnlpParserDelegate: NSObject, XMLParserDelegate {
  var sawJnlpRoot = false
  var codebase: String?
  var jarReferences: [String] = []
  private var sawFirstElement = false

  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String] = [:]
  ) {
    let localName = elementName.split(separator: ":").last.map(String.init) ?? elementName

    if !sawFirstElement {
      sawFirstElement = true
      guard localName.lowercased() == "jnlp" else {
        parser.abortParsing()
        return
      }
      sawJnlpRoot = true
      codebase = attributeDict["codebase"]?.trimmingCharacters(in: .whitespacesAndNewlines)
      return
    }

    if localName.lowercased() == "jar",
      let reference = attributeDict["href"]?.trimmingCharacters(in: .whitespacesAndNewlines),
      !reference.isEmpty
    {
      jarReferences.append(reference)
    }
  }
}
