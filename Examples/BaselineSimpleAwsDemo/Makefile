
PERFORMANCE_TEST_SCHEME="BaselineSimpleAwsDemo"
PERFORMANCE_TEST_WORKSPACE="BaselineSimpleAwsDemo.xcodeproj"

PERFORMANCE_TEST_PLAN="PerformanceTests"

### START PERFORMANCE TEST OPTIONS

XCODEBUILD_OPTIONS_IOS_PERFORMANCE=\
	-project $(PERFORMANCE_TEST_WORKSPACE) \
	-scheme $(PERFORMANCE_TEST_SCHEME) \
	-testPlan $(PERFORMANCE_TEST_PLAN) \
	-destination 'platform=iOS Simulator,name=iPhone 16' \
	-scmProvider system \
	-packageAuthorizationProvider netrc

# Performance Test Commands
.PHONY: performance-test-ios
performance-test-ios: ## `xcodebuild test` automatically builds and tests
	xcodebuild test $(XCODEBUILD_OPTIONS_IOS_PERFORMANCE) | xcbeautify --renderer github-actions
