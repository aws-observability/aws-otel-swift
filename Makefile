# AWS OpenTelemetry Swift - Build Automation
# Provides commands for building and testing across Apple platforms
# Usage: make <target>
#
# Tested Devices:
#   iOS: iPhone 16 (latest available iOS version)
#   tvOS: Apple TV 4K (3rd generation) (latest available tvOS version)
#   watchOS: Apple Watch Series 10 (46mm) (latest available watchOS version)
#   visionOS: Apple Vision Pro (visionOS v26.0) - DISABLED: not supported by aws-sdk-swift

PROJECT_NAME="aws-otel-swift-Package"

UNIT_TEST_PLAN="UnitTestPlan"
CONTRACT_TEST_PLAN="ContractTestPlan"

XCODEBUILD_OPTIONS_IOS=\
	-configuration Debug \
	-destination 'platform=iOS Simulator,name=iPhone 16' \
	-scheme $(PROJECT_NAME) \
	-testPlan $(UNIT_TEST_PLAN) \
	-test-iterations 5 \
    -retry-tests-on-failure \
	-workspace .

XCODEBUILD_OPTIONS_TVOS=\
	-configuration Debug \
	-destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
	-scheme $(PROJECT_NAME) \
	-testPlan $(UNIT_TEST_PLAN) \
	-test-iterations 5 \
    -retry-tests-on-failure \
	-workspace .

XCODEBUILD_OPTIONS_WATCHOS=\
	-configuration Debug \
	-destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
	-scheme $(PROJECT_NAME) \
	-testPlan $(UNIT_TEST_PLAN) \
	-test-iterations 5 \
    -retry-tests-on-failure \
	-workspace .

# visionOS temporarily disabled due to dependency compatibility issues with aws-sdk-swift
# XCODEBUILD_OPTIONS_VISIONOS=\
#	-configuration Debug \
#	-destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=26.0' \
#	-scheme $(PROJECT_NAME) \
#	-test-iterations 5 \
#    -retry-tests-on-failure \
#	-workspace .

### START CONTRACT TEST - RUN OPTIONS

XCODE_OPTIONS_IOS_CONTRACT_RUN=\
	-configuration Debug \
	-destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5' \
	-scheme $(PROJECT_NAME) \
	-testPlan $(CONTRACT_TEST_PLAN) \
	-workspace .

XCODE_OPTIONS_TVOS_CONTRACT_RUN=\
	-configuration Debug \
	-destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
	-scheme $(PROJECT_NAME) \
	-testPlan $(CONTRACT_TEST_PLAN) \
	-workspace .

XCODE_OPTIONS_WATCHOS_CONTRACT_RUN=\
	-configuration Debug \
	-destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
	-scheme $(PROJECT_NAME) \
	-testPlan $(CONTRACT_TEST_PLAN) \
	-workspace .

# visionOS temporarily disabled due to dependency compatibility issues with aws-sdk-swift
# XCODE_OPTIONS_VISIONOS_CONTRACT_RUN=\
# 	-configuration Debug \
# 	-destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=26.0' \
# 	-scheme $(PROJECT_NAME) \
# 	-testPlan $(CONTRACT_TEST_PLAN) \
# 	-workspace .

### END CONTRACT TEST - RUN OPTIONS

# Setup Commands
.PHONY: setup-brew
setup-brew:  ## Install required tools (xcbeautify)
	brew update && brew install xcbeautify

# Coverage Commands
.PHONY: check-coverage
check-coverage:  ## Run tests with coverage and check thresholds
	./scripts/check-coverage.sh

.PHONY: lint-format
lint-format:  ## Run SwiftFormat linting
	find . -name '*.swift' -not -path './.build/*' | xargs swiftformat --lint

.PHONY: lint-swift
lint-swift:  ## Run SwiftLint
	find . -name '*.swift' -not -path './.build/*' | xargs swiftlint lint --strict

.PHONY: format
format:  ## Auto-fix formatting issues with SwiftFormat
	find . -name '*.swift' -not -path './.build/*' | xargs swiftformat

.PHONY: lint
lint: lint-format lint-swift  ## Run all linting checks

# Build Commands - Compile code for each platform
.PHONY: build-ios
build-ios:  ## Build for iOS
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_IOS) build | xcbeautify

.PHONY: build-tvos
build-tvos:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_TVOS) build | xcbeautify

.PHONY: build-watchos
build-watchos:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_WATCHOS) build | xcbeautify

# Build-for-Testing Commands - Prepare test bundles (faster than full test)
.PHONY: build-for-testing-ios
build-for-testing-ios:  ## Build test bundles for iOS
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_IOS) build-for-testing | xcbeautify

.PHONY: build-for-testing-tvos
build-for-testing-tvos:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_TVOS) build-for-testing | xcbeautify

.PHONY: build-for-testing-watchos
build-for-testing-watchos:
	set -o pipefail && xcodebuild OTHER_LDFLAGS="$(OTHER_LDFLAGS) -fprofile-instr-generate" $(XCODEBUILD_OPTIONS_WATCHOS) build-for-testing | xcbeautify

# Test Commands - Full build + test cycle
.PHONY: test-ios
test-ios:  ## Run full test cycle for iOS
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_IOS) test | xcbeautify

.PHONY: test-tvos
test-tvos:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_TVOS) test | xcbeautify

.PHONY: test-watchos
test-watchos:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_WATCHOS) test | xcbeautify

# Test-without-Building Commands - Use pre-built test bundles (fast)
.PHONY: test-without-building-ios
test-without-building-ios:  ## Run tests using pre-built iOS bundles
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_IOS) test-without-building | xcbeautify

.PHONY: test-without-building-tvos
test-without-building-tvos:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_TVOS) test-without-building | xcbeautify

.PHONY: test-without-building-watchos
test-without-building-watchos:
	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_WATCHOS) test-without-building | xcbeautify

# Contract Test - Run Commands
.PHONY: contract-test-run-ios
contract-test-run-ios: ## `xcodebuild test` automatically builds and tests
	set -o pipefail && xcodebuild test $(XCODEBUILD_OPTIONS_IOS_CONTRACT_RUN) | xcbeautify

.PHONY: contract-test-run-tvos
contract-test-run-tvos: ## `xcodebuild test` automatically builds and tests
	set -o pipefail && xcodebuild test $(XCODEBUILD_OPTIONS_TVOS_CONTRACT_RUN) | xcbeautify

.PHONY: contract-test-run-watchos
contract-test-run-watchos: ## `xcodebuild test` automatically builds and tests
	set -o pipefail && xcodebuild test $(XCODEBUILD_OPTIONS_WATCHOS_CONTRACT_RUN) | xcbeautify

# visionOS targets temporarily disabled due to dependency compatibility issues with aws-sdk-swift
# .PHONY: build-visionos
# build-visionos:
#	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_VISIONOS) build | xcbeautify
#
# .PHONY: build-for-testing-visionos
# build-for-testing-visionos:
#	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_VISIONOS) build-for-testing | xcbeautify
#
# .PHONY: test-visionos
# test-visionos:
#	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_VISIONOS) test | xcbeautify
#
# .PHONY: test-without-building-visionos
# test-without-building-visionos:
#	set -o pipefail && xcodebuild $(XCODEBUILD_OPTIONS_VISIONOS) test-without-building | xcbeautify
# 
# .PHONY: contract-test-generate-data-visionos
# contract-test-generate-data-visionos: ## `xcodebuild test` automatically builds and tests
# 	set -o pipefail && xcodebuild test $(XCODEBUILD_OPTIONS_VISIONOS_CONTRACT) test-without-building | xcbeautify
# 
# .PHONY: contract-test-run-visionos
# contract-test-run-visionos: ## `xcodebuild test` automatically builds and tests
# 	set -o pipefail && xcodebuild test $(XCODEBUILD_OPTIONS_VISIONOS_CONTRACT_RUN) | xcbeautify
