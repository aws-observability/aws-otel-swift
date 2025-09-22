//
//  BaselineSimpleAwsDemoApp.swift
//  BaselineSimpleAwsDemo
//
//  Created by Kambhampaty, Rekha on 9/22/25.
//

import SwiftUI

@main
struct BaselineSimpleAwsDemoApp: App {
  private let cognitoPoolId = "YOUR_IDENTITY_POOL_ID_FROM_OUTPUT"
  private let region = "YOUR_REGION_FROM_OUTPUT"
  var body: some Scene {
    WindowGroup {
      LoaderView(cognitoPoolId: cognitoPoolId, region: region)
    }
  }
}
