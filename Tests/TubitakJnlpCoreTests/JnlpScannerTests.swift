import Foundation
import Testing

@testable import TubitakJnlpCore

@Suite("TUBITAK JNLP scanner")
struct JnlpScannerTests {
  @Test("Trusted TUBITAK JNLP loses only its quarantine attribute")
  func removesQuarantineFromTrustedJnlp() throws {
    let fixture = try Fixture()
    defer { fixture.cleanUp() }

    let file = try fixture.makeJnlp(
      name: "trusted.jnlp",
      origin: "https://e-imza.tubitak.gov.tr/sublimity-ess/jnlp/job.jnlp",
      codebase: "https://e-imza.tubitak.gov.tr/sublimity-ess/jnlp/",
      jarReference: "client.jar",
      runtimeSupplierReference: "http://java.sun.com/products/autodl/j2se"
    )
    let whereFromsData = try ExtendedAttributes.data(
      for: ExtendedAttributes.whereFroms,
      at: file
    )
    let whereFroms = try #require(whereFromsData)
    let document = try Data(contentsOf: file)

    #expect(JnlpValidator.isTrustedOrigin(whereFroms))
    #expect(JnlpValidator.isTrustedDocument(document))
    #expect(JnlpValidator.isTrusted(fileURL: file, whereFromsData: whereFroms))

    let summary = try JnlpScanner().scan(directoryURL: fixture.directory)

    #expect(summary.jnlpCandidates == 1)
    #expect(summary.trustedCandidates == 1)
    #expect(summary.quarantineAttributesRemoved == 1)
    #expect(try ExtendedAttributes.data(for: ExtendedAttributes.quarantine, at: file) == nil)
    #expect(try ExtendedAttributes.data(for: ExtendedAttributes.whereFroms, at: file) != nil)
  }

  @Test("Native library resources remain quarantined")
  func preservesQuarantineForNativeLibrary() throws {
    let fixture = try Fixture()
    defer { fixture.cleanUp() }

    let file = try fixture.makeJnlp(
      name: "native-library.jnlp",
      origin: "https://e-imza.tubitak.gov.tr/sublimity-ess/jnlp/job.jnlp",
      codebase: "https://e-imza.tubitak.gov.tr/sublimity-ess/jnlp/",
      jarReference: "client.jar",
      additionalResource: #"<nativelib href="native.jar" />"#
    )

    let summary = try JnlpScanner().scan(directoryURL: fixture.directory)

    #expect(summary.trustedCandidates == 0)
    #expect(try ExtendedAttributes.data(for: ExtendedAttributes.quarantine, at: file) != nil)
  }

  @Test("Extension JNLP resources remain quarantined")
  func preservesQuarantineForExtension() throws {
    let fixture = try Fixture()
    defer { fixture.cleanUp() }

    let file = try fixture.makeJnlp(
      name: "extension.jnlp",
      origin: "https://e-imza.tubitak.gov.tr/sublimity-ess/jnlp/job.jnlp",
      codebase: "https://e-imza.tubitak.gov.tr/sublimity-ess/jnlp/",
      jarReference: "client.jar",
      additionalResource: #"<extension href="component.jnlp" />"#
    )

    let summary = try JnlpScanner().scan(directoryURL: fixture.directory)

    #expect(summary.trustedCandidates == 0)
    #expect(try ExtendedAttributes.data(for: ExtendedAttributes.quarantine, at: file) != nil)
  }

  @Test("JAR outside the trusted codebase path remains quarantined")
  func preservesQuarantineForJarOutsideCodebasePath() throws {
    let fixture = try Fixture()
    defer { fixture.cleanUp() }

    let file = try fixture.makeJnlp(
      name: "outside-codebase.jnlp",
      origin: "https://e-imza.tubitak.gov.tr/sublimity-ess/jnlp/job.jnlp",
      codebase: "https://e-imza.tubitak.gov.tr/sublimity-ess/jnlp/",
      jarReference: "https://e-imza.tubitak.gov.tr/other/client.jar"
    )

    let summary = try JnlpScanner().scan(directoryURL: fixture.directory)

    #expect(summary.trustedCandidates == 0)
    #expect(try ExtendedAttributes.data(for: ExtendedAttributes.quarantine, at: file) != nil)
  }

  @Test("Unexpected Java runtime supplier remains quarantined")
  func preservesQuarantineForUnexpectedRuntimeSupplier() throws {
    let fixture = try Fixture()
    defer { fixture.cleanUp() }

    let file = try fixture.makeJnlp(
      name: "runtime-supplier.jnlp",
      origin: "https://e-imza.tubitak.gov.tr/sublimity-ess/jnlp/job.jnlp",
      codebase: "https://e-imza.tubitak.gov.tr/sublimity-ess/jnlp/",
      jarReference: "client.jar",
      runtimeSupplierReference: "https://example.com/jre"
    )

    let summary = try JnlpScanner().scan(directoryURL: fixture.directory)

    #expect(summary.trustedCandidates == 0)
    #expect(try ExtendedAttributes.data(for: ExtendedAttributes.quarantine, at: file) != nil)
  }

  @Test("External root JNLP reference remains quarantined")
  func preservesQuarantineForExternalRootReference() throws {
    let fixture = try Fixture()
    defer { fixture.cleanUp() }

    let file = try fixture.makeJnlp(
      name: "external-root.jnlp",
      origin: "https://e-imza.tubitak.gov.tr/sublimity-ess/jnlp/job.jnlp",
      codebase: "https://e-imza.tubitak.gov.tr/sublimity-ess/jnlp/",
      jarReference: "client.jar",
      jnlpReference: "https://example.com/job.jnlp"
    )

    let summary = try JnlpScanner().scan(directoryURL: fixture.directory)

    #expect(summary.trustedCandidates == 0)
    #expect(try ExtendedAttributes.data(for: ExtendedAttributes.quarantine, at: file) != nil)
  }

  @Test("Lookalike origin host remains quarantined")
  func preservesQuarantineForLookalikeOrigin() throws {
    let fixture = try Fixture()
    defer { fixture.cleanUp() }

    let file = try fixture.makeJnlp(
      name: "lookalike.jnlp",
      origin: "https://e-imza.tubitak.gov.tr.example.com/job.jnlp",
      codebase: "https://e-imza.tubitak.gov.tr/sublimity-ess/jnlp/",
      jarReference: "client.jar"
    )

    let summary = try JnlpScanner().scan(directoryURL: fixture.directory)

    #expect(summary.trustedCandidates == 0)
    #expect(summary.quarantineAttributesRemoved == 0)
    #expect(try ExtendedAttributes.data(for: ExtendedAttributes.quarantine, at: file) != nil)
  }

  @Test("External JAR reference remains quarantined")
  func preservesQuarantineForExternalJar() throws {
    let fixture = try Fixture()
    defer { fixture.cleanUp() }

    let file = try fixture.makeJnlp(
      name: "external-jar.jnlp",
      origin: "https://e-imza.tubitak.gov.tr/sublimity-ess/jnlp/job.jnlp",
      codebase: "https://e-imza.tubitak.gov.tr/sublimity-ess/jnlp/",
      jarReference: "https://example.com/client.jar"
    )

    let summary = try JnlpScanner().scan(directoryURL: fixture.directory)

    #expect(summary.trustedCandidates == 0)
    #expect(try ExtendedAttributes.data(for: ExtendedAttributes.quarantine, at: file) != nil)
  }

  @Test("Unexpected codebase path remains quarantined")
  func preservesQuarantineForUnexpectedCodebasePath() throws {
    let fixture = try Fixture()
    defer { fixture.cleanUp() }

    let file = try fixture.makeJnlp(
      name: "unexpected-path.jnlp",
      origin: "https://e-imza.tubitak.gov.tr/sublimity-ess/jnlp/job.jnlp",
      codebase: "https://e-imza.tubitak.gov.tr/other/",
      jarReference: "client.jar"
    )

    let summary = try JnlpScanner().scan(directoryURL: fixture.directory)

    #expect(summary.trustedCandidates == 0)
    #expect(try ExtendedAttributes.data(for: ExtendedAttributes.quarantine, at: file) != nil)
  }

  @Test("Symlinks are ignored")
  func ignoresSymlinks() throws {
    let fixture = try Fixture()
    defer { fixture.cleanUp() }

    let target = try fixture.makeJnlp(
      name: "target.txt",
      origin: "https://e-imza.tubitak.gov.tr/sublimity-ess/jnlp/job.jnlp",
      codebase: "https://e-imza.tubitak.gov.tr/sublimity-ess/jnlp/",
      jarReference: "client.jar"
    )
    let link = fixture.directory.appendingPathComponent("link.jnlp")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

    let summary = try JnlpScanner().scan(directoryURL: fixture.directory)

    #expect(summary.jnlpCandidates == 0)
    #expect(try ExtendedAttributes.data(for: ExtendedAttributes.quarantine, at: target) != nil)
  }
}

private final class Fixture {
  let directory: URL

  init() throws {
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("TubitakJnlpGuardTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
  }

  func cleanUp() {
    try? FileManager.default.removeItem(at: directory)
  }

  func makeJnlp(
    name: String,
    origin: String,
    codebase: String,
    jarReference: String,
    runtimeSupplierReference: String? = nil,
    additionalResource: String = "",
    jnlpReference: String = "job.jnlp"
  ) throws -> URL {
    let file = directory.appendingPathComponent(name)
    let runtimeSupplierAttribute = runtimeSupplierReference.map { " href=\"\($0)\"" } ?? ""
    let document = """
      <jnlp spec="1.0+" codebase="\(codebase)" href="\(jnlpReference)">
        <information>
          <title>TUBITAK E-Signature</title>
          <vendor>TUBITAK</vendor>
        </information>
        <resources>
          <java version="1.8*"\(runtimeSupplierAttribute) />
          <jar href="\(jarReference)" />
          \(additionalResource)
        </resources>
        <security><all-permissions /></security>
        <application-desc main-class="example.Main" />
      </jnlp>
      """
    try Data(document.utf8).write(to: file)

    let whereFroms = try PropertyListSerialization.data(
      fromPropertyList: [origin, "https://e-imza.tubitak.gov.tr/"],
      format: .binary,
      options: 0
    )
    try ExtendedAttributes.set(ExtendedAttributes.whereFroms, data: whereFroms, at: file)
    try ExtendedAttributes.set(
      ExtendedAttributes.quarantine,
      data: Data("0081;00000000;Test;TEST-ID".utf8),
      at: file
    )
    return file
  }
}
