
CONTRACT_TEST_SCHEME="SimpleAwsDemo"
CONTRACT_TEST_WORKSPACE="SimpleAwsDemo.xcodeproj"
CONTRACT_TEST_PLAN="UITests"

PERFORMANCE_TEST_PLAN="PerformanceTests"

### START CONTRACT TEST - HARNESS CONFIGURATION
#
# Endpoint / region / app monitor id for the app under test. `scripts/run-contract-tests.sh`
# supplies them (defaulting the endpoint to the local AwsOtelUI server); they can also be set
# directly in the environment.
#
# `xcodebuild` copies `TEST_RUNNER_`-prefixed variables into the UI test runner's environment
# with the prefix stripped, and `UITests/EmptyUITests.swift` re-injects them into the app's
# launch environment — the runner and the app are different processes.
#
# These are `export`ed rather than written into the recipe so make never echoes their values:
# the app monitor id is a secret in CI. Unset variables export as empty, which the app treats
# exactly like unset (no `AwsExportOverride` is built).
TEST_RUNNER_AWS_OTEL_CONTRACT_EXPORT_ENDPOINT = $(AWS_OTEL_CONTRACT_EXPORT_ENDPOINT)
TEST_RUNNER_AWS_OTEL_CONTRACT_REGION = $(AWS_OTEL_CONTRACT_REGION)
TEST_RUNNER_AWS_OTEL_CONTRACT_APP_MONITOR_ID = $(AWS_OTEL_CONTRACT_APP_MONITOR_ID)
export TEST_RUNNER_AWS_OTEL_CONTRACT_EXPORT_ENDPOINT
export TEST_RUNNER_AWS_OTEL_CONTRACT_REGION
export TEST_RUNNER_AWS_OTEL_CONTRACT_APP_MONITOR_ID

### END CONTRACT TEST - HARNESS CONFIGURATION

### START CONTRACT TEST - DATA GENERATION OPTIONS

XCODEBUILD_OPTIONS_IOS_CONTRACT=\
	-project $(CONTRACT_TEST_WORKSPACE) \
	-scheme $(CONTRACT_TEST_SCHEME) \
	-testPlan $(CONTRACT_TEST_PLAN) \
	-destination 'platform=iOS Simulator,name=iPhone 16' \
	-scmProvider system \
	-packageAuthorizationProvider netrc

XCODEBUILD_OPTIONS_TVOS_CONTRACT=\
	-project $(CONTRACT_TEST_WORKSPACE) \
	-scheme $(CONTRACT_TEST_SCHEME) \
	-testPlan $(CONTRACT_TEST_PLAN) \
	-destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' \
	-scmProvider system \
	-packageAuthorizationProvider netrc

XCODEBUILD_OPTIONS_WATCHOS_CONTRACT=\
	-project $(CONTRACT_TEST_WORKSPACE) \
	-scheme $(CONTRACT_TEST_SCHEME) \
	-testPlan $(CONTRACT_TEST_PLAN) \
	-destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
	-scmProvider system \
	-packageAuthorizationProvider netrc

XCODEBUILD_OPTIONS_VISIONOS_CONTRACT=\
	-project $(CONTRACT_TEST_WORKSPACE) \
	-scheme $(CONTRACT_TEST_SCHEME) \
	-testPlan $(CONTRACT_TEST_PLAN) \
	-destination 'platform=visionOS Simulator,name=Apple Vision Pro,OS=26.0' \
	-scmProvider system \
	-packageAuthorizationProvider netrc

### END CONTRACT TEST  - DATA GENERATION OPTIONS

### START PERFORMANCE TEST OPTIONS

XCODEBUILD_OPTIONS_IOS_PERFORMANCE=\
	-project $(CONTRACT_TEST_WORKSPACE) \
	-scheme $(CONTRACT_TEST_SCHEME) \
	-testPlan $(PERFORMANCE_TEST_PLAN) \
	-destination 'platform=iOS Simulator,name=iPhone 16' \
	-scmProvider system \
	-packageAuthorizationProvider netrc

### END PERFORMANCE TEST OPTIONS

# Contract Test - Data Generation Commands
.PHONY: contract-test-generate-data-ios
contract-test-generate-data-ios: ## `xcodebuild test` automatically builds and tests
	xcodebuild test $(XCODEBUILD_OPTIONS_IOS_CONTRACT) | xcbeautify --renderer github-actions

.PHONY: contract-test-generate-data-tvos
contract-test-generate-data-tvos: ## `xcodebuild test` automatically builds and tests
	xcodebuild test $(XCODEBUILD_OPTIONS_TVOS_CONTRACT) | xcbeautify --renderer github-actions

.PHONY: contract-test-generate-data-watchos
contract-test-generate-data-watchos: ## `xcodebuild test` automatically builds and tests
	xcodebuild test $(XCODEBUILD_OPTIONS_WATCHOS_CONTRACT) | xcbeautify --renderer github-actions

.PHONY: contract-test-generate-data-visionos
contract-test-generate-data-visionos: ## `xcodebuild test` automatically builds and tests
	xcodebuild test $(XCODEBUILD_OPTIONS_VISIONOS_CONTRACT) | xcbeautify --renderer github-actions

# Performance Test Commands
.PHONY: performance-test-ios
performance-test-ios: ## `xcodebuild test` automatically builds and tests
	xcodebuild test $(XCODEBUILD_OPTIONS_IOS_PERFORMANCE) | xcbeautify 
