import Foundation

public class HttpRequestInterceptor: URLProtocol {
  private var dataTask: URLSessionDataTask?

  override public class func canInit(with request: URLRequest) -> Bool {
    return true
  }

  override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
    return AwsSigV4Authenticator.signHeadersSync(urlRequest: request)
  }

  override public func startLoading() {
    let config = URLSessionConfiguration.default
    config.protocolClasses = []
    let session = URLSession(configuration: config)

    dataTask = session.dataTask(with: request) { [weak self] data, response, error in
      guard let self = self else { return }

      if let error = error {
        self.client?.urlProtocol(self, didFailWithError: error)
        return
      }

      if let response = response {
        self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
      }

      if let data = data {
        self.client?.urlProtocol(self, didLoad: data)
      }

      self.client?.urlProtocolDidFinishLoading(self)
    }

    dataTask?.resume()
  }

  override public func stopLoading() {
    dataTask?.cancel()
  }
}
