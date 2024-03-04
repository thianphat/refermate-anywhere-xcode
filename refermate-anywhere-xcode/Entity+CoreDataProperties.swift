//
//  Entity+CoreDataProperties.swift
//  Refermate Extension
//
//  Created by James irwin on 8/8/23.
//
//

import Foundation
import CoreData


extension Entity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Entity> {
        return NSFetchRequest<Entity>(entityName: "Entity")
    }

    @NSManaged public var key: String?
    @NSManaged public var value: Data?

}
