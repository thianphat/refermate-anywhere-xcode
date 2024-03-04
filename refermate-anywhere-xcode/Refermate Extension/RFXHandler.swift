//
//  RFXHandler.swift
//  Refermate Extension
//
//  Created by James irwin on 8/11/23.
//

import WebKit

class RFXHandler : NSObject, WKURLSchemeHandler {
    
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard
            let url = urlSchemeTask.request.url,
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            urlSchemeTask.didFailWithError(NSError(domain: "com.irwinproject", code: 1))
            return
        }
        
        components.scheme = "https"
        let nURL = components.url!
        var request = URLRequest(url: nURL)
        if var headers = request.allHTTPHeaderFields {
            headers.merge(urlSchemeTask.request.allHTTPHeaderFields ?? [:]){(_, new) in new}
            request.allHTTPHeaderFields = headers
        } else {
            request.allHTTPHeaderFields = urlSchemeTask.request.allHTTPHeaderFields
        }
        
        if let bodyData = urlSchemeTask.request.httpBody {
            request.httpBody = bodyData
        }
        if let methodData = urlSchemeTask.request.httpMethod {
            request.httpMethod = methodData
        }
        
        let task = URLSession.shared.dataTask(with:request){data, response, error in
            
            guard
                let data = data,
                let response = response as? HTTPURLResponse,
                var headers = response.allHeaderFields as? [String:String]  else {
                let err = error ?? NSError(domain: "com.irwinproject", code: 1)
                return urlSchemeTask.didFailWithError(err)
            }
            headers["Access-Control-Allow-Origin"] = "*"
            headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
            headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
            
            guard let newResponse = HTTPURLResponse(
                url: url,
                statusCode: response.statusCode,
                httpVersion: "1.1",
                headerFields: headers) else {
                return urlSchemeTask.didFailWithError(NSError(domain: "com.irwinproject", code: 1))
            }
            
            urlSchemeTask.didReceive(newResponse)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        }
        task.resume()
    }
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
    }
}
