# Contributing Guidelines

Thank you for your interest in contributing to AWS Distro for OpenTelemetry Swift. We welcome bug reports, feature requests, documentation improvements, and code contributions.

## Getting Started

### Prerequisites

- Xcode 16.0 or later
- iOS Simulator (iPhone 16 recommended)
- Git hooks setup (run `./scripts/setup-all.sh`)

### Development Setup

Clone the repository and set up development tools:

```bash
git clone https://github.com/aws-observability/aws-otel-swift.git
cd aws-otel-swift
./scripts/setup-all.sh
```

## Reporting Issues

Before filing an issue, check existing open or recently closed issues to avoid duplicates.

Include the following information:

- Reproducible test case or steps
- Code version being used
- Relevant modifications made
- Environment details

## Contributing Code

### Before You Start

- Check existing PRs to avoid duplicate work
- Open an issue for significant changes to discuss approach

### Pull Request Process

1. **Fork** the repository
2. **Create a branch** from `main`
3. **Make focused changes** - avoid reformatting unrelated code
4. **Run tests** locally (see [Testing](#testing))
5. **Commit** with in [conventional commit format](https://www.conventionalcommits.org/en/v1.0.0/)
6. **Open a pull request** with detailed description
7. **Respond** to review feedback

## Testing

### Running Tests

**Via CLI:**

```bash
# Coverage and Quality
make check-coverage          # Run tests on macOS with coverage requirement (85% repository, 85% PR)
make lint                    # Run all linting checks
make format                  # Auto-fix formatting issues

# Platform Testing
make test-ios                # Run full test cycle for iOS
make test-tvos               # Run full test cycle for tvOS
make test-watchos            # Run full test cycle for watchOS
make test-visionos           # Run full test cycle for visionOS
make test-macos              # Run tests on macOS

# To run a specific test
make test-ios TEST=AwsOpenTelemetryCore/TestSuiteName
```

**Via Xcode:**

1. Open project in Xcode
2. Select `aws-otel-swift-Package` scheme
3. Choose iPhone 16 simulator
4. Press `Cmd+U`

## Version Management

Version bumping is handled automatically by CI workflows. For manual version control:

```bash
# Patch version (x.y.z → x.y.z+1)
./scripts/bump-version.sh patch

# Minor version (x.y.z → x.y+1.0)
./scripts/bump-version.sh minor

# Major version (x.y.z → x+1.0.0)
./scripts/bump-version.sh major

# Specific version
./scripts/bump-version.sh 2.1.3

# With commit and tag
./scripts/bump-version.sh patch --commit-tag
```

## Finding Work

Look for issues labeled `help wanted` or `good first issue` to get started.

## Code of Conduct

This project follows the [Amazon Open Source Code of Conduct](https://aws.github.io/code-of-conduct).

## Security Issues

Report security vulnerabilities through [AWS Security](http://aws.amazon.com/security/vulnerability-reporting/). **Do not** create public GitHub issues for security concerns.

## License

See [LICENSE](LICENSE) for project licensing. Contributors must confirm licensing of their contributions.
