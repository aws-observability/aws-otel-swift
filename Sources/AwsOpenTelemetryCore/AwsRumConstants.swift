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

import Foundation

/**
 * Constants used by AWS RUM (Real User Monitoring) service.
 *
 * This struct defines string constants used for attribute keys and other
 * fixed values throughout the AWS OpenTelemetry SDK.
 */
public enum AwsRumConstants {
    /// Attribute key for the AWS Region
    public static let AWS_REGION = "awsRegion"
    
    /// Attribute key for the RUM App Monitor ID
    public static let RUM_APP_MONITOR_ID = "awsRumAppMonitorId"
    
    /// Attribute key for the RUM alias
    public static let RUM_ALIAS = "awsRumAlias"
}
