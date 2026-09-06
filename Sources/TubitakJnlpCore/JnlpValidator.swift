import Foundation

public struct JnlpValidationPolicy: Sendable {
  public let trustedHost: String
  public let requiredCodebasePathPrefix: String
  public let maximumFileSize: Int
  public let allowedRuntimeSupplierURLs: Set<String>

  public init(
    trustedHost: String = "e-imza.tubitak.gov.tr",
    requiredCodebasePathPrefix: String = "/sublimity-ess/jnlp/",
    maximumFileSize: Int = 1_048_576,
    allowedRuntimeSupplierURLs: Set<String> = [
      "http://java.sun.com/products/autodl/j2se"
    ]
  ) {
    self.trustedHost = trustedHost.lowercased()
    self.requiredCodebasePathPrefix = requiredCodebasePathPrefix
    self.maximumFileSize = maximumFileSize
    self.allowedRuntimeSupplierURLs = allowedRuntimeSupplierURLs
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
      delegate.isSupported,
      delegate.launchDescriptorCount == 1,
      let codebaseString = delegate.codebase,
      let codebaseURL = URL(string: codebaseString),
      isTrustedHTTPSURL(codebaseURL, policy: policy),
      isAllowedCodebasePath(codebaseURL.path, policy: policy),
      let jnlpReference = delegate.jnlpReference,
      isTrustedResource(
        jnlpReference,
        relativeTo: codebaseURL,
        requiredExtension: "jnlp",
        policy: policy
      ),
      delegate.runtimeSupplierReferences.allSatisfy(
        policy.allowedRuntimeSupplierURLs.contains
      ),
      !delegate.jarReferences.isEmpty
    else {
      return false
    }

    return delegate.jarReferences.allSatisfy { reference in
      isTrustedResource(
        reference,
        relativeTo: codebaseURL,
        requiredExtension: "jar",
        policy: policy
      )
    }
  }

  private static func isTrustedResource(
    _ reference: String,
    relativeTo codebaseURL: URL,
    requiredExtension: String,
    policy: JnlpValidationPolicy
  ) -> Bool {
    guard let resourceURL = URL(string: reference, relativeTo: codebaseURL)?.absoluteURL else {
      return false
    }

    return resourceURL.pathExtension.lowercased() == requiredExtension
      && isTrustedHTTPSURL(resourceURL, policy: policy)
      && isAllowedCodebasePath(resourceURL.path, policy: policy)
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
  var isSupported = true
  var codebase: String?
  var jnlpReference: String?
  var jarReferences: [String] = []
  var runtimeSupplierReferences: [String] = []
  var launchDescriptorCount = 0
  private var sawFirstElement = false
  private var elementStack: [String] = []

  func parser(
    _ parser: XMLParser,
    didStartElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?,
    attributes attributeDict: [String: String] = [:]
  ) {
    let localName = elementName.split(separator: ":").last.map(String.init) ?? elementName
    let normalizedName = localName.lowercased()

    if !sawFirstElement {
      sawFirstElement = true
      guard normalizedName == "jnlp" else {
        parser.abortParsing()
        return
      }
      sawJnlpRoot = true
      codebase = attributeDict["codebase"]?.trimmingCharacters(in: .whitespacesAndNewlines)
      jnlpReference = attributeDict["href"]?.trimmingCharacters(in: .whitespacesAndNewlines)
      elementStack.append(normalizedName)
      return
    }

    let parentName = elementStack.last
    elementStack.append(normalizedName)

    if normalizedName == "jnlp" || (normalizedName == "resources" && parentName != "jnlp") {
      isSupported = false
    }

    if parentName == "resources" {
      guard ["jar", "java", "j2se"].contains(normalizedName) else {
        isSupported = false
        return
      }
    } else if ["jar", "java", "j2se"].contains(normalizedName) {
      isSupported = false
      return
    }

    switch normalizedName {
    case "jar":
      guard
        let reference = attributeDict["href"]?.trimmingCharacters(in: .whitespacesAndNewlines),
        !reference.isEmpty
      else {
        isSupported = false
        return
      }
      jarReferences.append(reference)

    case "java", "j2se":
      if let reference = attributeDict["href"] {
        let trimmedReference = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReference.isEmpty else {
          isSupported = false
          return
        }
        runtimeSupplierReferences.append(trimmedReference)
      }

    case "application-desc", "applet-desc":
      guard parentName == "jnlp" else {
        isSupported = false
        return
      }
      launchDescriptorCount += 1

    case "installer-desc", "component-desc":
      isSupported = false

    default:
      break
    }
  }

  func parser(
    _ parser: XMLParser,
    didEndElement elementName: String,
    namespaceURI: String?,
    qualifiedName qName: String?
  ) {
    if !elementStack.isEmpty {
      elementStack.removeLast()
    }
  }
}
