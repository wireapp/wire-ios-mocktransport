//
// Wire
// Copyright (C) 2017 Wire Swiss GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//

import Foundation
import CoreData

@objc public class MockTeam: NSManagedObject {
    @NSManaged public var conversations: Set<MockConversation>?
    @NSManaged public var members: Set<MockMember>?
    @NSManaged public var creator: MockUser?
    @NSManaged public var name: String?
    @NSManaged public var assetKey: String?
    @NSManaged public var identifier: String
    
    static var entityName = "Team"
}

extension MockTeam {
    @objc
    public static func insert(in context: NSManagedObjectContext, name: String?, assetKey: String?) -> MockTeam {
        let entity = NSEntityDescription.entity(forEntityName: MockTeam.entityName, in: context)!
        let team = MockTeam(entity: entity, insertInto: context)
        team.name = name
        team.assetKey = assetKey
        team.identifier = NSUUID.create().transportString()
        return team
    }
    
    public static func fetch(in context: NSManagedObjectContext, identifier: String) -> MockTeam? {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: MockTeam.entityName)
        fetchRequest.predicate = NSPredicate(format: "%K == %@", #keyPath(MockTeam.identifier), identifier)
        let results = try? context.fetch(fetchRequest)
        return results?.first as? MockTeam
    }
    
    public static func fetchAll(in context: NSManagedObjectContext) -> [MockTeam] {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: MockTeam.entityName)
        let results = try? context.fetch(fetchRequest)
        let teams = results as? [MockTeam]
        return teams ?? []
    }
    
    var payload: ZMTransportData {
        let data: [String : String?] = [
            "id": identifier,
            "name" : name,
            "icon_key" : assetKey,
            "creator" : creator?.identifier
            ]
        return data as NSDictionary
    }
}
