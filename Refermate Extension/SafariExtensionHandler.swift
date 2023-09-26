//
//  SafariExtensionHandler.swift
//  Refermate Extension
//
//  Created by James irwin on 8/7/23.
//

import SafariServices



class SafariExtensionHandler: SFSafariExtensionHandler, MessageSubscriber {
    let handler: ScriptHandler = .content
    let msgr : MessageHandler = .shared
    
    override init() {
        super.init()
        msgr.contentScript = self
        
        //Popup ui must be hosted via http server to allow CORS to function properly.
        
    }
    
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        // This method will be called when a content script provided by your extension calls safari.extension.dispatchMessage("message").
        page.getPropertiesWithCompletionHandler { properties in
            let parameters : Any?
            
            if let param = userInfo?["parameters"] {
                parameters = param
            } else {
                parameters = userInfo?["message"]
            }
            guard let id = userInfo?["id"] as? String, parameters != nil else {
                print("Unable to collect the appropriate data")
                return
            }
            let dict: [String:Any] = [
                "cmd": messageName,
                "parameters": parameters!
            ]
            self.msgr.handle(id, dict, self)
        }
    }

    override func toolbarItemClicked(in window: SFSafariWindow) {
        // This method will be called when your toolbar item is clicked.
    }
    
    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {
        // This is called when Safari's state changed in some way that would require the extension's toolbar item to be validated again.
        Safari.getActiveTab{tab in
            guard let data = JSON.encode(tab), let str = String(data:data, encoding: .utf8) else {return}
            self.msgr.emitToAllSubscribers("rando", "onUpdated", str, self.msgr.popupScript) //popup script sender ensures all subscribers are notified
            self.updateCurrentDomain()
        }
        
        validationHandler(true, "")
    }
    
    
    override func popoverWillShow(in window: SFSafariWindow) {
        popoverViewController().view.addSubview(msgr.popupScript.webView, positioned: .below, relativeTo: nil)
        msgr.popupScript.vc = popoverViewController()
    }
    override func popoverDidClose(in window: SFSafariWindow) {
        msgr.popupScript.webView.removeFromSuperview()
    }
    
    func updateCurrentDomain() {
        Safari.getCurrentDomain{domain in
            self.msgr.currentDomain = domain
        }
    }
    func commandResponse(_ id: String, _ message: String, _ completionHandler: ((Any?, Error?) -> Void)?) {
        let dict : [String:Any] = [
            "id": id,
            "message": message
        ]
        //api provides no support for completionHandler
        Safari.messageActivePage("commandResponse", dict)
    }
    
    func emitEvent(_ id: String, _ event: String, _ message: String, _ completionHandler: ((Any?, Error?) -> Void)?) {
        
        Safari.messageActivePage(event, [
            "id": id,
            "message": message
        ])
        
    }
    
    override func popoverViewController() -> SafariExtensionViewController {
        return SafariExtensionViewController.shared
    }
    
    
}
