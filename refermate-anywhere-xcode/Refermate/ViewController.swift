//
//  ViewController.swift
//  Refermate
//
//  Created by James irwin on 8/7/23.
//

import Cocoa
import SafariServices
import WebKit

let extensionBundleIdentifier = "com.refermate.macos.extension"

class ViewController: NSViewController, WKNavigationDelegate, WKScriptMessageHandler {

    @IBOutlet var webView: WKWebView!
    var isExtensionEnabled: Bool = UserDefaults.standard.bool(forKey: "Installed")
    let timer = DispatchSource.makeTimerSource()
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "RefermateStore") // Replace with your data model file name
        container.loadPersistentStores(completionHandler: { (_, error) in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        })
        return container
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        

        self.webView.navigationDelegate = self

        self.webView.configuration.userContentController.add(self, name: "controller")

        self.webView.loadFileURL(Bundle.main.url(forResource: "Main", withExtension: "html")!, allowingReadAccessTo: Bundle.main.resourceURL!)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if #available(macOS 13, *) {
            webView.evaluateJavaScript("show('mac', \(isExtensionEnabled), true)")

        } else {
            webView.evaluateJavaScript("show('mac', \(isExtensionEnabled), false)")

        }
        timer.schedule(deadline: .now(), repeating: .seconds(1), leeway: .seconds(1))
        timer.setEventHandler{
            SFSafariExtensionManager.getStateOfSafariExtension(withIdentifier: extensionBundleIdentifier) { (state, error) in
                
                guard let state = state, error == nil else {
                    // Insert code to inform the user that something went wrong.
                    return
                }
                guard state.isEnabled != self.isExtensionEnabled else {
                    return //No change to the state dont do anything
                }
                self.isExtensionEnabled = state.isEnabled
                UserDefaults.standard.set(self.isExtensionEnabled, forKey: "Installed")
                DispatchQueue.main.async {
                    if !self.isExtensionEnabled {
                        print("opening uninstall window")
                        NSWorkspace.shared.open(URL(string: "https://www.refermate.com/extension_uninstalled")!)
                    } else {
                        print("opening install window")
                        NSWorkspace.shared.open(URL(string: "https://refermate.com/extension_installed_apple_permissions_instructions")!)
                    }
                    if #available(macOS 13, *) {
                        webView.evaluateJavaScript("show('mac', \(state.isEnabled), true)")
    
                    } else {
                        webView.evaluateJavaScript("show('mac', \(state.isEnabled), false)")
    
                    }
                }
            }
        }
        timer.resume()
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if (message.body as! String == "open-preferences") {
            SFSafariApplication.showPreferencesForExtension(withIdentifier: extensionBundleIdentifier) { error in
                guard error == nil else {
                    // Insert code to inform the user that something went wrong.
                    return
                }
            }
        }
        
        if (message.body as! String == "close-app-window") {
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    }

}
