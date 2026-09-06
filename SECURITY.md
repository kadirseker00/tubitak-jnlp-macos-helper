# Security Policy

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting feature for security-sensitive findings. Do not attach live JNLP files, signing job identifiers, certificates, or personal documents to a public issue.

For non-sensitive defects, open a regular GitHub issue with a minimal synthetic example.

## Scope

The project intentionally removes `com.apple.quarantine` only after checking the downloaded file's origin metadata and supported JNLP resource locations. It accepts `jar` and `java`/`j2se` under `resources` and rejects unsupported resource types. A bypass of any of those checks is considered a security issue.

The project does not audit or attest to Java code served by `e-imza.tubitak.gov.tr`. Browser-written `kMDItemWhereFroms` metadata is not cryptographic proof of origin, and files can be modified after validation.
