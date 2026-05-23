# Changelog

All notable changes to this project will be documented in this file.

> **Note:** This CHANGELOG was created starting from version 1.0.0. Earlier changes are not documented here.

## Unreleased

### Changed
- Replace PLCrashReporter with KSCrash backtrace for live stack trace collection in hang detection ([#104](https://github.com/aws-observability/aws-otel-swift/pull/104))

### Fixed
- Pin `opentelemetry-swift-core`, `opentelemetry-swift`, `aws-sdk-swift`, and `smithy-swift` to exact versions to prevent SPM from resolving to incompatible newer releases ([#103](https://github.com/aws-observability/aws-otel-swift/pull/103))


