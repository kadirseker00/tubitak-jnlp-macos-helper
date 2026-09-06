import Darwin
import Foundation

public enum ExtendedAttributeError: Error, LocalizedError {
  case operationFailed(operation: String, attribute: String, code: Int32)

  public var errorDescription: String? {
    switch self {
    case .operationFailed(let operation, let attribute, let code):
      let message = String(cString: strerror(code))
      return "\(operation) failed for \(attribute): \(message) (errno \(code))"
    }
  }
}

public enum ExtendedAttributes {
  public static let quarantine = "com.apple.quarantine"
  public static let whereFroms = "com.apple.metadata:kMDItemWhereFroms"

  public static func data(for attribute: String, at url: URL) throws -> Data? {
    let size = url.path.withCString { path in
      attribute.withCString { name in
        getxattr(path, name, nil, 0, 0, 0)
      }
    }

    if size < 0 {
      if errno == ENOATTR || errno == ENODATA {
        return nil
      }
      throw ExtendedAttributeError.operationFailed(
        operation: "getxattr",
        attribute: attribute,
        code: errno
      )
    }

    var result = Data(count: size)
    let bytesRead = result.withUnsafeMutableBytes { buffer in
      url.path.withCString { path in
        attribute.withCString { name in
          getxattr(path, name, buffer.baseAddress, size, 0, 0)
        }
      }
    }

    guard bytesRead >= 0 else {
      throw ExtendedAttributeError.operationFailed(
        operation: "getxattr",
        attribute: attribute,
        code: errno
      )
    }

    if bytesRead != size {
      result.count = bytesRead
    }
    return result
  }

  public static func remove(_ attribute: String, at url: URL) throws {
    let status = url.path.withCString { path in
      attribute.withCString { name in
        removexattr(path, name, 0)
      }
    }

    guard status == 0 else {
      if errno == ENOATTR || errno == ENODATA {
        return
      }
      throw ExtendedAttributeError.operationFailed(
        operation: "removexattr",
        attribute: attribute,
        code: errno
      )
    }
  }

  static func set(_ attribute: String, data: Data, at url: URL) throws {
    let status = data.withUnsafeBytes { buffer in
      url.path.withCString { path in
        attribute.withCString { name in
          setxattr(path, name, buffer.baseAddress, data.count, 0, 0)
        }
      }
    }

    guard status == 0 else {
      throw ExtendedAttributeError.operationFailed(
        operation: "setxattr",
        attribute: attribute,
        code: errno
      )
    }
  }
}
