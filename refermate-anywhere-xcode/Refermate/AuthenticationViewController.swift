//
//  AuthenticationViewController.swift
//  Refermate
//
//  Created by James irwin on 8/9/23.
//

import WebKit

class AuthenticationViewController : NSViewController, WKNavigationDelegate {
    @IBOutlet var webView: WKWebView!
    var url: URL? {
        didSet{
            guard let u = url, let wv = self.webView else {return}
            wv.load(URLRequest(url: u))
        }
    }
    override func viewDidLoad() {
        guard let url = self.url else {return}
        self.webView.load(URLRequest(url: url))
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("Page finished loading")
    }
}
