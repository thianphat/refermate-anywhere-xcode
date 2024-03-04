//
//  MessageHandler.swift
//  Refermate Extension
//
//  Created by James irwin on 8/8/23.
//

import SafariServices

enum MessageError : Error {
    case malformedCommand
    case missingProperty(String)
}
enum ScriptHandler {
    case content, popup
}
protocol MessageSubscriber {
    var handler: ScriptHandler {get}
    func commandResponse(_ id: String,_ message: String, _ completionHandler: ((Any?, Error?)->Void)?)
    func emitEvent(_ id: String,_ event: String, _ message: String, _ completionHandler: ((Any?, Error?)->Void)?)
}
class MessageHandler {
    static let shared = MessageHandler()
    let id = UUID().uuidString
    var contentScript: MessageSubscriber?
    let popupScript: SafariPopupManager
    var responses: [String:MessageSubscriber] = [:]
    var timer: Timer?
    var currentDomain: String = "" {
        didSet{
            if oldValue != currentDomain {
                popupScript.currentDomainUpdated()
            }
        }
    }
    init(){
        popupScript = SafariPopupManager()
        popupScript.msgr = self
        
        guard UserDefaults.standard.bool(forKey: "installed") else {
            emitToAllSubscribers("", "onInstalled", "{\"details\":\"install\"}", popupScript)
            UserDefaults.standard.set(true, forKey: "installed")
            return
        }
    }
    func handle(_ id: String, _ dict: [String:Any], _ subscriber: MessageSubscriber) {
        guard let cmd = JSON.string(dict, "cmd") else {return}
        let responder = blanketResponder(cmd, id)
        switch cmd {
        case "queryTabs":
            return Safari.queryTabs(JSON.dict(dict, key: "parameters") ?? [:]){ tabs in
                return subscriber.commandResponse(id, tabs, responder)
            }
        case "getStorage":
            guard let keys = JSON.array(obj: dict, "parameters", String.self) else {
                print("getStorage encounted an error while collecting keys: No valid keys were provided")
                return 
            }
            
            let value = Storage.shared.getJSONString(keys)
            return subscriber.commandResponse(id, value, responder)
        case "setStorage":
            guard let parameters = JSON.dict(dict, key: "parameters") else {
                print("setStorage encountered an error: No parameters were provided")
                return
            }
            guard let changes = Storage.shared.setDict(parameters) else {
                return print("There was a problem")
            }
            
            emitToAllSubscribers(id, "onChanged", changes, subscriber)
            return subscriber.commandResponse(id,"", responder)
        case "removeStorage":
            guard let keys = JSON.array(obj: dict, "parameters", String.self) else {
                print("removeStorage encountered an error while collecting keys: No Valid keys were provided")
                return
            }
            if keys.contains("refermate-user") {
                popupScript.removeAllCookies()
            }
            guard let changes = Storage.shared.delete(keys) else {
                print("Delete failed")
                return
            }
            emitToAllSubscribers(id, "onChanged", changes, subscriber)
            return subscriber.commandResponse(id, "", responder)
        case "sendMessage":
            
            guard let parameters = JSON.string(dict, "parameters", .utf8) else {
                print("sendMessage encountered an error while getting the parameters")
                return
            }
            //print("Received message \(dict)")
            return emitToAllSubscribers(id, "onMessage", parameters, subscriber)
        case "respondToMessage":
            guard let sender = responses[id] else {
                print("respondToMessage encountered an error. Unable to locate the sender with the provided ID")
                print(responses)
                return
            }
            guard let message = JSON.string(dict, "message", .utf8) else {
                print("respondToMessage encountered an error. Unable to get a message from the sender")
                return
            }
            //print("Responding to message \(id) with \(message)")
            return sender.commandResponse(id, message, responder)
        case "openWindow":
            guard let obj = JSON.dict(dict, key: "parameters"), let addr = obj["url"] as? String, let url = URL(string: addr) else {
                print("Failed to create url", dict)
                return}
            //display back and close buttons
            if let target = (obj["target"] as? String), target == "_blank" {
                Safari.createTab(["url": addr]){}
            }
            
            popupScript.showNativeButtons()
            popupScript.webView.load(URLRequest(url: url))
        case "closeWindow":
            SafariExtensionViewController.shared.dismissPopover()
        case "createTab":
            guard let parameters = dict["parameters"] as? [String:Any] else {return}
            Safari.createTab(parameters){
            }
        case "copyText":
            guard let text = dict["text"] as? String else {return}
            print("Copying: \(text)")
            DispatchQueue.main.async {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            
            
        case "setBadgeText":
            print("Set Badge text", dict)
            guard let parameters = dict["parameters"] as? [String:Any], let text = parameters["text"] as? String else {
                print("Theres a lack of info", dict)
                return
            }
            Safari.setBadgeText(text)
        
        default:
            print("Unsupported Command - \(cmd)")
        }
    }
    
    func blanketResponder(_ cmd: String, _ id: String) -> (Any?, Error?) -> Void {
        return {data, error in
            if let error = error {
                print("\(cmd) encountered an error when sending the response to \(id) | \(error.localizedDescription)")
            }
            guard let data = data else {return}
            print("\(cmd) received a response from its command what do I do \(data)")
        }
    }
    
    func emitToAllSubscribers(_ id: String, _ event: String, _ message: String, _ sender: MessageSubscriber) {
        responses[id] = sender
        var subscribers: [MessageSubscriber] = [popupScript]
        if sender.handler != .content, let contentScript = contentScript {
            subscribers.append(contentScript)
        }
        subscribers.forEach{ subscriber in
            subscriber.emitEvent(id, event, message){data, error in
                if let error = error {
                    print("emitToAllSubscribers encounted an error while emmiting \(error.localizedDescription) \(id)")
                    return
                }
                guard let data = data else {return}
                print("emitToAllSubscribers got a response what do I do \(data)")
            }
        }
    }
    
}
