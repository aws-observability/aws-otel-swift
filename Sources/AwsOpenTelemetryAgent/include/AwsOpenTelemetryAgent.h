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

#import <Foundation/Foundation.h>

// Forward declare the Swift class
@class AwsOpenTelemetryAgent ;

NS_ASSUME_NONNULL_BEGIN

/**
 * @class AwsOpenTelemetryAutoInit
 * @brief Provides automatic initialization for the AWS OpenTelemetry SDK.
 *
 * This class leverages the Objective-C runtime's +load method to automatically
 * initialize the AWS OpenTelemetry SDK when the application launches, without
 * requiring explicit initialization code in the application.
 */
@interface AwsOpenTelemetryAutoInit : NSObject

@end

NS_ASSUME_NONNULL_END
