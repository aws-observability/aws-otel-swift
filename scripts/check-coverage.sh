#!/bin/bash

# AWS OpenTelemetry Swift - Coverage Check Script
# Checks both repository-wide and PR-specific coverage thresholds

set -e

REPO_COVERAGE_THRESHOLD=70
PR_COVERAGE_THRESHOLD=70
COVERAGE_FILE="coverage.txt"

# Generate coverage report
echo "Generating coverage report..."
swift test --skip ContractTests --enable-code-coverage
xcrun llvm-cov report .build/debug/aws-otel-swiftPackageTests.xctest/Contents/MacOS/aws-otel-swiftPackageTests -instr-profile .build/debug/codecov/default.profdata --format=text > "$COVERAGE_FILE"

# Check repository coverage
echo "Checking repository coverage..."
head -1 "$COVERAGE_FILE"
grep "^Sources/" "$COVERAGE_FILE"
sources_coverage=$(grep "^Sources/" "$COVERAGE_FILE" | awk '{lines += $8; missed += $9} END {if (lines > 0) print ((lines - missed) / lines * 100); else print 0}')
echo "Sources directory code coverage: ${sources_coverage}%"

if (( $(echo "$sources_coverage < $REPO_COVERAGE_THRESHOLD" | bc -l) )); then
    echo "❌ Sources coverage ${sources_coverage}% is below minimum threshold of ${REPO_COVERAGE_THRESHOLD}%"
    exit 1
else
    echo "✅ Sources coverage ${sources_coverage}% meets minimum threshold of ${REPO_COVERAGE_THRESHOLD}%"
fi

# Check PR coverage (only if we can detect changed files)
if git rev-parse --verify origin/main >/dev/null 2>&1; then
    echo "Checking PR coverage..."
    git fetch origin main
    changed_sources=$(git diff --name-only origin/main...HEAD | grep '^Sources/.*\.swift$' || true)

    if [ -n "$changed_sources" ]; then
        echo "Checking coverage for changed files:"
        echo "$changed_sources"
        echo "Coverage for changed files:"
        head -1 "$COVERAGE_FILE"
        echo "$changed_sources" | while read file; do grep "^$file" "$COVERAGE_FILE" || true; done

        changed_coverage=$(echo "$changed_sources" | while read file; do grep "^$file" "$COVERAGE_FILE" || true; done | awk '{lines += $8; missed += $9} END {if (lines > 0) print ((lines - missed) / lines * 100); else print 100}')
        echo "Changed files coverage: ${changed_coverage}%"
        
        if (( $(echo "$changed_coverage < $PR_COVERAGE_THRESHOLD" | bc -l) )); then
            echo "❌ Changed files coverage ${changed_coverage}% is below minimum threshold of ${PR_COVERAGE_THRESHOLD}%"
            exit 1
        else
            echo "✅ Changed files coverage ${changed_coverage}% meets minimum threshold of ${PR_COVERAGE_THRESHOLD}%"
        fi
    else
        echo "No Swift files changed in Sources directory"
    fi
else
    echo "Skipping PR coverage check (origin/main not available)"
fi

echo "✅ All coverage checks passed"