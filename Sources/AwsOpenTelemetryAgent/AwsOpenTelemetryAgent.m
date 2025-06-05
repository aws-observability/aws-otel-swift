/*
 * Copyright Amazon.com, Inc. or its affiliates.
 *
 * Licensed under the Apache License, Version 2.0 (the "License").
 * You may not use this file except in compliance with the License.
 * A copy of the License is located at
 *
 *  http://aws.amazon.com/apache2.0
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

#import "include/AwsOpenTelemetryAgent.h"

// Define a constant for the log prefix
static NSString * const kLogPrefix = @"[AwsOpenTelemetry";

@implementation AwsOpenTelemetryAutoInit

/**
 * @brief Automatically called when the class is loaded into memory.
 *
 * This method is invoked by the Objective-C runtime when the class is loaded,
 * before any application code executes. It performs initialization synchronously
 * to ensure that instrumentation is set up before any network requests or other
 * operations that need to be monitored.
 */
+ (void)load {
    NSLog(@"%@ +load method called, performing synchronous initialization", kLogPrefix);
    [self performAutoInit];
}

/**
 * @brief Performs the automatic initialization of the AWS OpenTelemetry SDK.
 *
 * This method:
 * 1. Locates the aws_config.json configuration file in the main bundle
 * 2. Accesses the Swift AwsOpenTelemetryAgent class through the Objective-C runtime
 * 3. Retrieves the shared instance of the AwsOpenTelemetryAgent class
 * 4. Invokes the initialization method on the shared instance
 *
 * The initialization process uses the Objective-C runtime to avoid circular dependencies
 * between Swift and Objective-C components. This method is called synchronously during
 * class loading to ensure that instrumentation is ready before any application code runs.
 */
+ (void)performAutoInit {
    NSLog(@"%@ Performing automatic initialization", kLogPrefix);
    
    // Locate the configuration file in the main bundle
    NSString *configPath = [[NSBundle mainBundle] pathForResource:@"aws_config" ofType:@"json"];
    if (!configPath) {
        NSLog(@"%@ Configuration file aws_config.json not found in the main bundle", kLogPrefix);
        return;
    }
    
    // Access the Swift API through the Objective-C runtime
    Class AwsOpenTelemetryClass = NSClassFromString(@"AwsOpenTelemetryCore.AwsOpenTelemetryAgent");
    if (!AwsOpenTelemetryClass) {
        NSLog(@"%@ Failed to find AwsOpenTelemetryAgent class", kLogPrefix);
        return;
    }
    
    // Get the shared instance
    SEL sharedSelector = NSSelectorFromString(@"shared");
    if (![AwsOpenTelemetryClass respondsToSelector:sharedSelector]) {
        NSLog(@"%@ Class does not respond to shared selector", kLogPrefix);
        return;
    }
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id sharedInstance = [AwsOpenTelemetryClass performSelector:sharedSelector];
    #pragma clang diagnostic pop
    
    if (!sharedInstance) {
        NSLog(@"%@ Failed to get shared instance", kLogPrefix);
        return;
    }
    
    // Initialize the SDK with the JSON configuration
    SEL initSelector = NSSelectorFromString(@"initializeWithJsonConfig");
    if (![sharedInstance respondsToSelector:initSelector]) {
        NSLog(@"%@ Shared instance does not respond to initializeWithJsonConfig", kLogPrefix);
        return;
    }
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    // Use NSInvocation to properly handle the BOOL return type
    NSMethodSignature *signature = [sharedInstance methodSignatureForSelector:initSelector];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:sharedInstance];
    [invocation setSelector:initSelector];
    [invocation invoke];
    
    BOOL success = NO;
    [invocation getReturnValue:&success];
    #pragma clang diagnostic pop
    
    if (success) {
        NSLog(@"%@ Automatic initialization successful", kLogPrefix);
    } else {
        NSLog(@"%@ Automatic initialization failed", kLogPrefix);
    }
}

@end
