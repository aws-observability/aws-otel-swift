
CONTRACT_TEST_SCHEME="SimpleAwsDemo"
CONTRACT_TEST_WORKSPACE="SimpleAwsDemo.xcodeproj"
CONTRACT_TEST_PLAN="UITests"

PERFORMANCE_TEST_PLAN="PerformanceTests"

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
