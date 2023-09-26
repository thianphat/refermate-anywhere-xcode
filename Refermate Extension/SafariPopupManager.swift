//
//  SafariPopupManager.swift
//  Refermate Extension
//
//  Created by James irwin on 8/7/23.
//

import WebKit


class SafariPopupManager: NSObject, WKNavigationDelegate, WKScriptMessageHandler, MessageSubscriber, WKUIDelegate {
    let handler : ScriptHandler = .popup
    let webView : WKWebView
    var msgr : MessageHandler!
    var vc: SafariExtensionViewController?
    
    var sessionCookie: String?
    var appUrl: URL! = Bundle.main.url(forResource: "popup", withExtension: "html")!
    //var appUrl = URL(string: "https://10.0.0.44:8080/popup.html")!
    
    //Handle data storage manually
    let datastore = WKWebsiteDataStore.nonPersistent()
    override init(){
    
        //Custom webview configuration
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = datastore
        configuration.setURLSchemeHandler(RFXHandler(), forURLScheme: "rfx")
        
        //configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 355, height: 650), configuration: configuration)
        
        super.init()
        
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.configuration.userContentController.add(self, name: "controller")
        webView.configuration.userContentController.add(self, name: "test")
        
        
        
        //Add saved cookies to the store
        if let cookies = UserDefaults.standard.array(forKey: "Cookies") as? [[String:Any]] {
            let list = cookies.compactMap(self.decodeCookie(_ :))
            setCookies(list)
        }
        
        loadApplication()
        
    }
    
    func loadApplication(){
        DispatchQueue.main.async {
            self.hideNativeButtons()
        }
        webView.loadFileURL(appUrl, allowingReadAccessTo: Bundle.main.resourceURL ?? appUrl)
        
    }
    //MARK: - Script Message Handling
    
    /**
     The Javascript context will message the client and here the client will respond appropriately
     */
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String:Any], let id = dict["id"] as? String else {
            print("Malformed command", message.body)
            return
        }
        return msgr.handle(id, dict, self)
    }
    //A convenience method to reduce the amount of opportunity to mishandle string eval (I might need a callback once I start supporting messages
    func commandResponse(_ id: String, _ message: String, _ completionHandler: ((Any?, Error?) -> Void)? = nil){
        self.webView.evaluateJavaScript("window.chrome.commandResponse('\(id)', \(message))", completionHandler: completionHandler)
    }
    
    func emitEvent(_ id: String,_ event: String, _ message: String, _ completionHandler: ((Any?, Error?)->Void)?){
        self.webView.evaluateJavaScript("window.chrome.emitEvent('\(event)', '\(id)', \(message))", completionHandler: completionHandler)
    }
    
    func setCurrentDomain(address: String) {
        self.webView.evaluateJavaScript("window.maclocation = '\(address)';")
    }
    
    func currentDomainUpdated(){
        loadApplication() //reload the application
    }
    func showNativeButtons(){
        vc?.backButton.isHidden = false
        vc?.closeButton.isHidden = false
        
        vc?.backButton.target = self
        vc?.closeButton.target = self
        vc?.backButton.action = #selector(goBackToApplication(_ :))
        vc?.closeButton.action = #selector(closeThePopover(_ :))
    }
    
    @objc func hideNativeButtons(){
        vc?.backButton.isHidden = true
        vc?.closeButton.isHidden = true
    }
    @objc func goBackToApplication(_ sender: NSButton){
        self.loadApplication()
    }
    
    @objc func closeThePopover(_ sender: NSButton){
        vc?.dismissPopover()
    }
    //MARK: - Navigation Delegate
    
    ///Based on the structure of the application the only places this will go is to the local file refermate and any necessary 3rd party to complete authentication. as such I will have to check for authentication here prior to passing cookies to url scheme handler
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        setCurrentDomain(address: msgr.currentDomain) //Reset this value anytime the page loads
        print(msgr.currentDomain)
        //Only do this if not on a file://
        guard let url = webView.url, url.scheme != "file" else {
            return} //Should perform tests to confirm that in production local pages are hosted at file:// not safariExtension
        datastore.httpCookieStore.getAllCookies{cookies in
            let cookieList = cookies.compactMap(self.encodeCookie(_:))
            UserDefaults.standard.set(cookieList, forKey: "Cookies")
            for cookie in cookies {
                HTTPCookieStorage.shared.setCookie(cookie) //Share the cookies with the application
            }
            return self.isSignedIn{ signedIn in
                if signedIn {
                    
                    self.loadApplication()
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url else {return nil}
        Safari.createTab(["url": url.absoluteString]){print("New tab should be visible")}
        return nil
    }
    
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        return .allow
    }
    
    func isSignedIn(completionHandler: @escaping (Bool)->Void){
        let url = URL(string: "https://refermate.com/extension?ver=2&scope=user,activity,transactions,store_subscriptions,liked_products")
        let task = URLSession.shared.dataTask(with: URLRequest(url: url!)){ data, response, error in
            if let data = data, let obj = JSON.dict(data){
                return completionHandler(obj["user"] != nil)
            }
            return completionHandler(false)
        }
        task.resume()
    }
    
    func encodeCookie(_ cookie: HTTPCookie) -> [String:Any]? {
        var dict: [String: Any] = [:]
        guard let properties = cookie.properties else {return nil}
        for (key, value) in properties {
            dict[key.rawValue] = value
        }
        return dict
    }
    
    func decodeCookie(_ dict: [String: Any]) -> HTTPCookie? {
        var props : [HTTPCookiePropertyKey: Any] = [:]
        for (key, value) in dict {
            props[.init(key)] = value
        }
        
        return HTTPCookie(properties: props)
    }
    
    
    func setCookies(_ cookies: [HTTPCookie]) {
        for cookie in cookies {
            datastore.httpCookieStore.setCookie(cookie)
            //first trying without reconstructing cookie
            HTTPCookieStorage.shared.setCookie(cookie)
        }
        
    }
    
    func removeAllCookies() {
        UserDefaults.standard.removeObject(forKey: "Cookies")
        
        datastore.httpCookieStore.getAllCookies{cookies in
            for cookie in cookies {
                self.datastore.httpCookieStore.delete(cookie)
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }
}

