//
// Copyright (c) 2019, Salesforce.com, inc.
// All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
// For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/BSD-3-Clause
//

import UIKit
import WebKit

class TestViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {

    var webView: WKWebView?
    var statusLabel: UILabel?
    var bridge: TestBridge!

    override func viewDidLoad() {
        super.viewDidLoad()

        let statusLabel = UILabel()
        self.view.addSubview(statusLabel)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        statusLabel.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        if #available(iOS 11.0, *) {
            statusLabel.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor).isActive = true
        } else {
            statusLabel.topAnchor.constraint(equalTo: self.view.topAnchor).isActive = true
        }
        statusLabel.backgroundColor =  UIColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)
        statusLabel.textAlignment = .center
        statusLabel.text = "Running"
        statusLabel.accessibilityIdentifier = "nimbus.test.statusLabel"
        self.statusLabel = statusLabel

        let userContentController = WKUserContentController()
        let testScript = Bundle.main.url(forResource: "test", withExtension: "js")
            .flatMap { try? NSString(contentsOf: $0, encoding: String.Encoding.utf8.rawValue ) }
            .flatMap { WKUserScript(source: $0 as String, injectionTime: .atDocumentEnd, forMainFrameOnly: true) }
        userContentController.addUserScript(testScript!)
        userContentController.add(self, name: "testFinished")

        let config = WKWebViewConfiguration()
        config.userContentController = userContentController
        let webView = WKWebView(frame: CGRect.zero, configuration: config)

        bridge = TestBridge(host: self, webView: webView)

        // Connect the webview to our demo bridge
        let c = webView.addConnection(to: bridge!, as: "DemoAppBridge")
        c.bind(TestBridge.showAlert, as: "showAlert")
        c.bind(TestBridge.currentTime, as: "currentTime")
        c.bind(TestBridge.withCallback, as: "withCallback")

        let testHtml = Bundle.main.url(forResource: "test", withExtension: "html")
            .flatMap { try? NSString(contentsOf: $0, encoding: String.Encoding.utf8.rawValue ) }
        self.view.addSubview(webView)
        self.webView = webView
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor).isActive = true
        webView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor).isActive = true
        webView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        webView.loadHTMLString(testHtml! as String, baseURL: nil)
    }

    func webView(_ webView: WKWebView,
                 didFinish navigation: WKNavigation!) {
        runMochaTest()
    }

    func runMochaTest() {
        webView!.evaluateJavaScript("""
                mocha.checkLeaks();
                mocha.run();
            """)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "testFinished", let messageBody = message.body as? String {
            if let numOfFailures = scrapeHtmlForFailureString(html: messageBody) {
                if numOfFailures > 0 {
                    self.statusLabel?.backgroundColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
                    self.statusLabel?.text = "Fail"
                } else {
                    self.statusLabel?.backgroundColor = UIColor(red: 135/255, green: 206/255, blue: 250/255, alpha: 1.0)
                    self.statusLabel?.text = "Pass"
                }
            }
        }
    }

    func scrapeHtmlForFailureString(html: String) -> Int? {
        if let range = html.range(of:"failures:</a> <em>") {
            let bound = range.upperBound
            let firstPassSubstring = html[bound...]
            let indexOfClosingEmTag = firstPassSubstring.index(of: "<")
            let distance = firstPassSubstring.distance(from: firstPassSubstring.startIndex, to: indexOfClosingEmTag!)
            let numOfFailuresText = firstPassSubstring.prefix(distance)
            let numOfFailures = Int(numOfFailuresText)
            return numOfFailures
        }
        return nil
    }

}