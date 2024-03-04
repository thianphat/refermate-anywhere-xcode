//
//  SafariTools.swift
//  Refermate Extension
//
//  Created by James irwin on 8/8/23.
//

import SafariServices

struct Tab : Codable {
    let status: String
    let url: String?
}
class Safari {
    ///Just a convenience method to perform a regex match
    fileprivate static func match(pattern: String, string: String) -> Bool {
        do{
            let reg = try NSRegularExpression(pattern: pattern)
            // Search for matches in the input string
            let range = NSRange(location: 0, length: string.utf16.count)
            let matches = reg.matches(in: string, options: [], range: range)

            // If at least one match is found, the wildcard pattern is present
            return !matches.isEmpty
        } catch {
            print(error.localizedDescription)
            return false
        }
    }
    
    ///Correct the url to ensure it follows a common scheme
    fileprivate static func fixUrl(string: String) -> String {
        guard let url = URL(string: string), let host = url.host else {
            print("Not a url")
            return string
        }
        guard !match(pattern: #"^[^\.]*\.[^\.]\..*$"#, string: string) else {
            print("No Match")
            return string
        }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.host = "www.\(host)"
        return components?.url?.absoluteString ?? url.absoluteString
    }
    
    ///A method to test for wildcards like *
    fileprivate static func wildcard(_ string: String, pattern: String) -> Bool {
        let pred = NSPredicate(format: "self LIKE %@", pattern)
        return !NSArray(object: string).filtered(using: pred).isEmpty
    }
    
    static func matchUrl(_ url: String, _ pattern: String) -> Bool {
        let fUrl = fixUrl(string: url)
        print("Comparing \(fUrl) to \(pattern)")
        return wildcard(fUrl, pattern: pattern)
    }
    
    ///A tab can have multiple pages however I am unable to find a use case where this will occur during the state of the web.
    fileprivate static func queryTab(_ tab: SFSafariTab, _ query: [String:Any], _ completionHandler: @escaping ([Tab]) -> Void){
        return tab.getActivePage{page in
            guard let page = page else {return completionHandler([])}
            return page.getPropertiesWithCompletionHandler{properties in
                guard let properties = properties else {return completionHandler([Tab(status: "complete", url: nil)])}
                let t = Tab(status: "complete", url: properties.url?.absoluteString)
                guard let pattern = query["url"] as? String else {return completionHandler([t])} //No pattern to match against so all should be permitted
                guard let tUrl = t.url, matchUrl(tUrl, pattern) else {return completionHandler([])}
                return completionHandler([t])
                
            }
        }
    }
    
    fileprivate static func queryWindow(_ window: SFSafariWindow, _ query: [String:Any], _ completionHandler: @escaping ([Tab])->Void){
        if let activeTab = query["active"] as? Bool, activeTab {
            return window.getActiveTab{tab in
                guard let tab = tab else {return completionHandler([])}
                return queryTab(tab, query, completionHandler)
            }
        }
        return window.getAllTabs{tabs in
            var searched: Int = 0
            var tabList: [Tab] = []
            guard tabs.count > 0 else {return completionHandler([])}
            for tab in tabs {
                queryTab(tab, query){tbs in
                    tabList += tbs
                    searched += 1
                    if searched == tabs.count {
                        return completionHandler(tabList)
                    }
                }
            }
        }
    }
    
    /**
     The entry point this will attempt to replicate chromes query tabs function however safari does not provide as much information as chrome does
     */
    fileprivate static func queryApplication(_ query: [String:Any],_ completionHandler: @escaping ([Tab])->Void){
        if let currentWindow = query["currentWindow"] as? Bool, currentWindow{
            return SFSafariApplication.getActiveWindow{window in
                guard let win = window else {return completionHandler([])}
                return queryWindow(win, query, completionHandler)
            }
        }
        return SFSafariApplication.getAllWindows{windows in
            var searched: Int = 0
            var tabs: [Tab] = []
            guard windows.count > 0 else {return completionHandler([])}
            for window in windows {
                queryWindow(window, query){tbs in
                    tabs += tbs
                    searched += 1
                    if searched == windows.count {
                        
                        return completionHandler(tabs)
                    }
                }
            }
        }
    }
    
    static func queryTabs(_ query: [String:Any], _ completionHandler: @escaping (String)->Void){
        return queryApplication(query){tabs in
            guard let data = JSON.encode(tabs), let string = String(data: data, encoding: .utf8) else {
                return completionHandler("[]")
            }
            return completionHandler(string)
        }
    }
    
    static func getActiveTab(_ completionHandler: @escaping (Tab) -> Void){
        return SFSafariApplication.getActiveWindow{window in
            window?.getActiveTab{tab in
                guard let tab = tab else {return completionHandler(Tab(status: "complete", url: ""))}
                tab.getActivePage{page in
                    guard let page = page else {return completionHandler(Tab(status: "complete", url: ""))}
                    page.getPropertiesWithCompletionHandler{props in
                        guard let props = props, let addr = props.url?.absoluteString else {return completionHandler(Tab(status: "complete", url: ""))}
                        let t = Tab(status: "complete", url: addr)
                        return completionHandler(t)
                    }
                }
            }
        }
    }
    static func messageActivePage(_ name: String, _ userInfo: [String:Any]){
        return SFSafariApplication.getActiveWindow{window in
            guard let window = window else {return}
            return window.getActiveTab{tab in
                guard let tab = tab else {return}
                tab.getActivePage{ page in
                    guard let page = page else {return}
                    return page.dispatchMessageToScript(withName: name, userInfo: userInfo)
                }
            }
        }
    }
    
    static func createTab(_ options:[String:Any?],_ completionHandler: @escaping ()->Void){
        print(options);
        let url = URL(string:options["url"]! as! String)!
        print("Opening tab")
        DispatchQueue.main.async {
            SFSafariApplication.getActiveWindow{window in
                window!.openTab(with: url, makeActiveIfPossible: true){ _ in}
            }
        }
    }
    
    static func setBadgeText(_ text: String?) {
        SFSafariApplication.getActiveWindow{ window in
            guard let window = window else {return}
            window.getToolbarItem{ toolbarItem in
                guard let toolbarItem = toolbarItem else {return}
                toolbarItem.setBadgeText(text)
            }
        }
    }
    
    static func getCurrentDomain(_ completionHandler: @escaping (_ address: String) -> Void){
        return SFSafariApplication.getActiveWindow{window in
            window?.getActiveTab{tab in
                guard let tab = tab else {return completionHandler("")}
                tab.getActivePage{page in
                    guard let page = page else {return completionHandler("")}
                    page.getPropertiesWithCompletionHandler{props in
                        guard let props = props, let url = props.url, let domain = url.host else {return completionHandler("")}
                        return completionHandler(domain)
                    }
                }
            }
        }
    }
}
