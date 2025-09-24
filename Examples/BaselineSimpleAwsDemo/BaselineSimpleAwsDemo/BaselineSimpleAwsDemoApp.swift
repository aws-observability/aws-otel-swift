//
//  BaselineSimpleAwsDemoApp.swift
//  BaselineSimpleAwsDemo
//
//  Created by Kambhampaty, Rekha on 9/22/25.
//

import SwiftUI

@main
struct BaselineSimpleAwsDemoApp: App {
  private let cognitoPoolId = "us-east-1:ac7df0bd-a16a-4756-9857-960afb12bd97"
  private let region = "us-east-1"
  var body: some Scene {
    WindowGroup {
      LoaderView(cognitoPoolId: cognitoPoolId, region: region)
    }
  }
}
