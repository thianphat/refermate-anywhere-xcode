//
//  JsonTools.swift
//  Refermate Extension
//
//  Created by James irwin on 8/8/23.
//

import Foundation

class JSON {
    //MARK: - Any handlers
    static func toAny(_ data: Data) -> Any? {
        return try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
    }
    
    //MARK: - Dict handlers
    static func dict(_ str: String) -> [String:Any]? {
        guard let data = str.data(using: .utf8) else {
            return nil;
        }
        return JSON.dict(data)
    }
    static func dict(_ obj: Any) -> [String:Any]? {
        return obj as? [String:Any]
    }
    
    static func dict(_ data: Data) -> [String:Any]? {
        guard let obj = toAny(data), let dict = dict(obj) else { return nil }
        return dict
    }
    
    static func dict(_ obj: [String:Any], key: String)->[String:Any]?{
        return obj[key] as? [String:Any]
    }
    
    //MARK: - Data handlers
    
    static func data(_ obj: Any) -> Data? {
        do{
            return try JSONSerialization.data(withJSONObject: obj, options: .fragmentsAllowed)
        } catch {
            print(error.localizedDescription)
            return nil
        }
    }
    
    static func data(_ obj: [String:Any],_ key: String) -> Data? {
        guard let p = obj[key] else {return nil}
        return data(p)
    }
    
    //MARK: - String handlers
    static func string(_ obj: Any) -> String? {
        guard let data = data(obj) else {return nil}
        return String(data: data, encoding: .utf8)
    }
    
    static func string(_ obj: [String:Any], _ key: String) -> String? {
        return obj[key] as? String
    }
    
    static func string(_ obj: [String:Any], _ key: String, _ encoding: String.Encoding) -> String?{
        guard let data = data(obj, key) else {return nil}
        return String(data: data, encoding: encoding)
    }
    
    //MARK: - Array Methods
    static func array<T : Codable>(obj: [String:Any], _ key: String,_ type:T.Type) -> [T]? {
        guard let v = obj[key] else { return nil }
        if let val = v as? T {
            return [val]
        }
        return v as? [T]
    }
    //MARK: - Encoder and Decoders
    static func encode(_ obj: Encodable) -> Data? {
        return try? JSONEncoder().encode(obj)
    }
    
    static func decode<T: Decodable>(_ type: T.Type, _ data: Data) -> T?{
        return try? JSONDecoder().decode(type.self, from: data)
    }
    
    static func decode<T: Decodable>(_ type: T.Type, _ obj: Any) -> T?{
        guard let d = data(obj) else {return nil}
        return decode(type.self, d)
    }
}
