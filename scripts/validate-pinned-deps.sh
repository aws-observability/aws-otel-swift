#!/bin/bash
# Validates that critical dependencies are pinned to exact versions in Package.swift.
# Returns non-zero if any dependency uses a range (from:) instead of exact pin.

set -euo pipefail

PACKAGE_SWIFT="${1:-Package.swift}"

FAILURES=0

check_exact_pin() {
  local dep_url="$1"
  local expected_version="$2"
  local dep_name
  dep_name=$(basename "$dep_url" .git)

  if grep -q "\"$dep_url\".*exact.*\"$expected_version\"" "$PACKAGE_SWIFT"; then
    echo "✓ $dep_name pinned to exact $expected_version"
  elif grep -q "\"$dep_url\"" "$PACKAGE_SWIFT"; then
    echo "✗ $dep_name NOT pinned to exact $expected_version"
    FAILURES=$((FAILURES + 1))
  else
    echo "? $dep_name not found in $PACKAGE_SWIFT"
    FAILURES=$((FAILURES + 1))
  fi
}

echo "Validating dependency pins in $PACKAGE_SWIFT..."
echo

check_exact_pin "https://github.com/open-telemetry/opentelemetry-swift-core.git" "2.2.0"
check_exact_pin "https://github.com/open-telemetry/opentelemetry-swift.git" "2.2.0"
check_exact_pin "https://github.com/awslabs/aws-sdk-swift" "1.3.32"
check_exact_pin "https://github.com/smithy-lang/smithy-swift" "0.134.0"

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAILED: $FAILURES dependencies not pinned correctly"
  exit 1
else
  echo "PASSED: All critical dependencies pinned to exact versions"
  exit 0
fi
