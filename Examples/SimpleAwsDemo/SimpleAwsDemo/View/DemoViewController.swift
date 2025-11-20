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

import UIKit
import SwiftUI
import AwsOpenTelemetryCore

/**
 * A simple UIKit view controller that demonstrates telemetry generation.
 * This controller will be captured by the bundle filtering instrumentation
 * since it belongs to the main app bundle.
 */
class DemoViewController: UIViewController {
  private let titleLabel = UILabel()
  private let descriptionLabel = UILabel()
  private let actionButton = UIButton(type: .system)
  private let closeButton = UIButton(type: .system)

  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    print("[DemoViewController] viewDidLoad called - should generate telemetry")
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    print("[DemoViewController] viewWillAppear called - should generate telemetry")
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    print("[DemoViewController] viewDidAppear called - should generate telemetry")
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    print("[DemoViewController] viewWillDisappear called - should generate telemetry")
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    print("[DemoViewController] viewDidDisappear called - should generate telemetry")
  }

  private func setupUI() {
    view.backgroundColor = .systemBackground

    // Configure title label
    titleLabel.text = "UIKit Demo View"
    titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
    titleLabel.textAlignment = .center
    titleLabel.translatesAutoresizingMaskIntoConstraints = false

    // Configure description label
    descriptionLabel.text = "This UIKit view controller generates telemetry spans that will be captured by the automatic UIKit views instrumentation."
    descriptionLabel.font = .systemFont(ofSize: 16)
    descriptionLabel.textAlignment = .center
    descriptionLabel.numberOfLines = 0
    descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

    // Configure action button
    actionButton.setTitle("Perform Action", for: .normal)
    actionButton.backgroundColor = .systemBlue
    actionButton.setTitleColor(.white, for: .normal)
    actionButton.layer.cornerRadius = 8
    actionButton.translatesAutoresizingMaskIntoConstraints = false
    actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)

    // Configure close button
    closeButton.setTitle("Close", for: .normal)
    closeButton.backgroundColor = .systemGray
    closeButton.setTitleColor(.white, for: .normal)
    closeButton.layer.cornerRadius = 8
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)

    // Add subviews
    view.addSubview(titleLabel)
    view.addSubview(descriptionLabel)
    view.addSubview(actionButton)
    view.addSubview(closeButton)

    // Setup constraints
    NSLayoutConstraint.activate([
      titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
      titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

      descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
      descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

      actionButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 40),
      actionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
      actionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
      actionButton.heightAnchor.constraint(equalToConstant: 50),

      closeButton.topAnchor.constraint(equalTo: actionButton.bottomAnchor, constant: 20),
      closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
      closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
      closeButton.heightAnchor.constraint(equalToConstant: 50)
    ])
  }

  @objc private func actionButtonTapped() {
    print("[DemoViewController] Action button tapped")

    // Show an alert to demonstrate more UI interaction
    let alert = UIAlertController(
      title: "Action Performed",
      message: "This action demonstrates UIKit interaction within the telemetry-enabled view controller.",
      preferredStyle: .alert
    )

    alert.addAction(UIAlertAction(title: "OK", style: .default))
    present(alert, animated: true)
  }

  @objc private func closeButtonTapped() {
    print("[DemoViewController] Close button tapped")
    dismiss(animated: true)
  }
}

/**
 * SwiftUI wrapper for the UIKit DemoViewController
 */
struct DemoViewControllerRepresentable: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> DemoViewController {
    return DemoViewController()
  }

  func updateUIViewController(_ uiViewController: DemoViewController, context: Context) {
    // No updates needed for this demo
  }
}

struct TracedDemoViewControllerRepresentable: View {
  var body: some View {
    AwsOTelTraceView("DemoViewControllerRepresentable") {
      DemoViewControllerRepresentable()
    }
  }
}
