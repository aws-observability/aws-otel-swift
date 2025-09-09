//
//  ViewController.swift
//  SimpleAwsUiKitDemo
//
//  Created by Kambhampaty, Rekha on 9/8/25.
//

import UIKit

class ViewController: UIViewController {
  // UI Elements
  private let scrollView = UIScrollView()
  private let contentView = UIView()
  private let titleLabel = UILabel()
  private let stackView = UIStackView()
  private let resultTextView = UITextView()
  private let activityIndicator = UIActivityIndicatorView(style: .medium)

  // State
  private var isLoading = false {
    didSet {
      updateLoadingState()
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    setupConstraints()
  }

  private func setupUI() {
    view.backgroundColor = .systemBackground

    // Title
    titleLabel.text = "ADOT Swift Demo"
    titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
    titleLabel.textAlignment = .center

    // Stack view for buttons
    stackView.axis = .vertical
    stackView.spacing = 12
    stackView.distribution = .fill

    // Add buttons
    stackView.addArrangedSubview(createButton(title: "List S3 Buckets", icon: "📁", action: #selector(listS3BucketsAction)))
    stackView.addArrangedSubview(createButton(title: "4xx HTTP Request", icon: "🌐", action: #selector(make4xxRequestAction)))
    stackView.addArrangedSubview(createButton(title: "5xx HTTP Request", icon: "🌐", action: #selector(make5xxRequestAction)))
    stackView.addArrangedSubview(createButton(title: "Get Cognito Identity", icon: "🔑", action: #selector(getCognitoIdentityAction)))
    stackView.addArrangedSubview(createButton(title: "Show UIKit Demo", icon: "📊", backgroundColor: .systemGreen, action: #selector(showUIKitDemoAction)))
    stackView.addArrangedSubview(createButton(title: "Peek session", icon: "ℹ️", action: #selector(peekSessionAction)))
    stackView.addArrangedSubview(createButton(title: "Renew session", icon: "🔄", action: #selector(renewSessionAction)))
    stackView.addArrangedSubview(createButton(title: "Simulate ANR (2 sec)", icon: "⚠️", action: #selector(simulateANRAction)))
    stackView.addArrangedSubview(createButton(title: "Trigger Crash", icon: "⚠️", backgroundColor: .systemRed, action: #selector(triggerCrashAction)))

    // Result text view
    resultTextView.text = "AWS API results will appear here"
    resultTextView.isEditable = false
    resultTextView.backgroundColor = .systemBackground
    resultTextView.layer.cornerRadius = 10
    resultTextView.layer.borderWidth = 1
    resultTextView.layer.borderColor = UIColor.systemGray4.cgColor

    // Activity indicator
    activityIndicator.hidesWhenStopped = true

    // Scroll view setup
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    contentView.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    stackView.translatesAutoresizingMaskIntoConstraints = false
    resultTextView.translatesAutoresizingMaskIntoConstraints = false
    activityIndicator.translatesAutoresizingMaskIntoConstraints = false

    view.addSubview(scrollView)
    scrollView.addSubview(contentView)
    contentView.addSubview(titleLabel)
    contentView.addSubview(stackView)
    contentView.addSubview(resultTextView)
    contentView.addSubview(activityIndicator)
  }

  private func setupConstraints() {
    NSLayoutConstraint.activate([
      // Scroll view
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      // Content view
      contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
      contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
      contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
      contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
      contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

      // Title
      titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
      titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

      // Stack view
      stackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
      stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

      // Activity indicator
      activityIndicator.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 16),
      activityIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

      // Result text view
      resultTextView.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
      resultTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
      resultTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
      resultTextView.heightAnchor.constraint(equalToConstant: 200),
      resultTextView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
    ])
  }

  private func createButton(title: String, icon: String, backgroundColor: UIColor = .systemBlue, action: Selector) -> UIButton {
    let button = UIButton(type: .system)
    button.setTitle("\(icon) \(title)", for: .normal)
    button.backgroundColor = backgroundColor
    button.setTitleColor(.white, for: .normal)
    button.layer.cornerRadius = 10
    button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
    button.addTarget(self, action: action, for: .touchUpInside)
    button.heightAnchor.constraint(equalToConstant: 50).isActive = true
    return button
  }

  private func updateLoadingState() {
    DispatchQueue.main.async {
      if self.isLoading {
        self.activityIndicator.startAnimating()
      } else {
        self.activityIndicator.stopAnimating()
      }

      // Disable/enable buttons
      self.stackView.arrangedSubviews.compactMap { $0 as? UIButton }.forEach { button in
        button.isEnabled = !self.isLoading
        button.alpha = self.isLoading ? 0.6 : 1.0
      }
    }
  }

  private func updateResult(_ message: String) {
    DispatchQueue.main.async {
      self.resultTextView.text = message
    }
  }

  // MARK: - Button Actions

  @objc private func listS3BucketsAction() {
    isLoading = true
    updateResult("Listing S3 buckets...")

    // Simulate async operation
    DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
      self.isLoading = false
      self.updateResult("S3 Buckets: bucket1, bucket2, bucket3")
    }
  }

  @objc private func make4xxRequestAction() {
    isLoading = true
    updateResult("Making 4xx HTTP request...")

    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
      self.isLoading = false
      self.updateResult("HTTP 404: Not Found")
    }
  }

  @objc private func make5xxRequestAction() {
    isLoading = true
    updateResult("Making 5xx HTTP request...")

    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
      self.isLoading = false
      self.updateResult("HTTP 500: Internal Server Error")
    }
  }

  @objc private func getCognitoIdentityAction() {
    isLoading = true
    updateResult("Getting Cognito Identity...")

    DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
      self.isLoading = false
      self.updateResult("Cognito Identity: us-east-1:12345678-1234-1234-1234-123456789012")
    }
  }

  @objc private func showUIKitDemoAction() {
    updateResult("UIKit Demo is already showing!")
  }

  @objc private func peekSessionAction() {
    updateResult("Session ID: ABC123\nUser ID: user-456\nSession Start: \(Date())")
  }

  @objc private func renewSessionAction() {
    updateResult("Session renewed successfully")
    peekSessionAction()
  }

  @objc private func simulateANRAction() {
    updateResult("Simulating ANR for 2 seconds...")

    // Block main thread for 2 seconds (simulating ANR)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      Thread.sleep(forTimeInterval: 2)
      self.updateResult("ANR simulation completed")
    }
  }

  @objc private func triggerCrashAction() {
    updateResult("Triggering crash...")

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      // Trigger crash with array out of bounds
      let array: [String] = []
      _ = array[10] // This will crash
    }
  }
}
