//
//  Storage.swift
//  Refermate Extension
//
//  Created by James irwin on 8/8/23.
//

import Foundation
import CoreData

struct Item : Codable {
    let value: Data
    let expiry: Int
}



class Storage {
    static let shared = Storage()
    
    //MARK: - Core Data
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "RefermateStore") // Replace with your data model file name
        container.loadPersistentStores(completionHandler: { (_, error) in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        })
        return container
    }()
    
    var context : NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    func fetch(_ request: NSFetchRequest<Entity>) -> [Entity]? {
        return try? context.fetch(request)
    }
    
    func get(_ key: String) -> Entity?{
        let fetchRequest: NSFetchRequest<Entity> = Entity.fetchRequest()
        let keyPredicate = NSPredicate(format: "key == %@", key)
        fetchRequest.predicate = keyPredicate
        let fetched = fetch(fetchRequest)
        return fetched?.first
    }
    
    
    
    func save() -> String? {
        do{
            try context.save()
            return nil
        } catch {
            return error.localizedDescription
        }
    }
    @discardableResult
    func delete(_ keys: [String]) -> String? {
        var changes: [String:[String:String]] = [:]
        for key in keys {
            guard let entity = get(key) else { continue }
            changes[key] = [
                "oldValue": String(data: entity.value!, encoding: .utf8)!
            ]
            context.delete(entity)
        }
        do{
            try context.save()
            return JSON.string(changes)
        } catch {
            print("DELETE ERROR: \(error.localizedDescription)")
            return nil
        }
    }
    @discardableResult
    func delete(_ key: String) -> String? {
        guard let entity = get(key) else { return "No Entity to delete"}
        return delete(entity)
    }
    @discardableResult
    func delete(_ entity: Entity) -> String? {
        do{
            context.delete(entity)
            try context.save()
            return nil
        } catch {
            return error.localizedDescription
        }
    }
    
    
    //MARK: - Data
    func setData(_ key: String, _ value: Data) -> [String:String]?{
        
        let fetched = get(key)
        var changes : [String:String] = [
            "newValue": String(data: value, encoding: .utf8)!
        ]
        if let d = fetched?.value {
            changes["oldValue"] = String(data: d, encoding: .utf8)!
        }
        let entity: Entity
        if let fetchedEntity = fetched {
            fetchedEntity.value = value
            entity = fetchedEntity
        } else {
            entity = Entity(context: context)
            entity.key = key
            entity.value = value
        }
        
        if let saveError = save() {
            return nil
        }
        return changes
    }

    func getData(_ key: String) -> Data? {
        let fetchRequest: NSFetchRequest<Entity> = Entity.fetchRequest()
        let keyPredicate = NSPredicate(format: "key == %@", key)
        fetchRequest.predicate = keyPredicate
        let context = persistentContainer.viewContext
        guard let entries = try? context.fetch(fetchRequest) else {return nil}
        return entries.first?.value
    }
    
    func getDict(_ key: String) -> [String:Any]? {
        return getAny(key) as? [String:Any]
    }
    
    func setDict(_ dict: [String:Any]) -> String? {
        var changes : [String:[String:String?]] = [:]
        for (key, value) in dict{
            guard let data = JSON.data(value) else {
                continue
            }
            guard let change = setData(key, data) else {
                continue
            }
            changes[key] = change
        }
        //check if anything went in

        if changes.count > 0 {
            return JSON.string(changes)
        }
        return nil
    }
    
    //MARK: - String
    func getString(_ key: String, using encoding: String.Encoding = .utf8) -> String? {
        guard let entity = getData(key) else {return nil}
        return String(data: entity, encoding: encoding)
    }
    
    func setString(_ key: String, _ value: String, using encoding: String.Encoding = .utf8) -> String? {
        guard let data = value.data(using: encoding) else {
            return "Unable to encode the data"
        }
        let change = setData(key, data)
        return JSON.string([key: change])
    }
    
    func getAny(_ key: String) -> Any? {
        guard let data = getData(key) else {return nil}
        return JSON.toAny(data)

    }
    
    /**
     Converts value to a JSONString acceptable by the client
     */
    func getJSONString(_ keys: [String]) -> String {
        var results: [String:Any?] = [:]
        for key in keys {
            
            if let obj = getAny(key) {
                results[key] = obj
            } else {
                results[key] = NSNull()
            }
        }
        if let str = JSON.string(results) {
            return str
        }
        print("JSON Failed to Encode")
        return "{}"
    }
    
    
    
    func empty(_ key: String) -> String {
        return "{}"
    }
    
    
    func getItem(key: String, domain: String?) -> Data?{
        let computedKey = domain != nil ? "\(key)\(domain!)":"\(key)"
        guard let fetched = get(computedKey), let item = JSON.decode(Item.self, fetched.value!) else {return nil}
        let now = getSeconds(date: Date())
        if now > item.expiry {
            delete(fetched)
        }
        return item.value
    }
    

    func clearAll(){
        let fetchRequest : NSFetchRequest<Entity> = Entity.fetchRequest()
        do{
            let objs = try context.fetch(fetchRequest)
            for object in objs {
                context.delete(object)
            }
            try context.save()
        } catch {
            print("error clearing DB")
        }
    }
    
    func getSeconds(date: Date) -> Int {
        let refDate = Date(timeIntervalSinceReferenceDate: 0)
        return Int(date.timeIntervalSince(refDate))
    }
}
