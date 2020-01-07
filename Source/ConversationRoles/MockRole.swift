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

@objc public final class MockRole: NSManagedObject, EntityNamedProtocol {
    public static let nameKey = #keyPath(MockRole.name)
    public static let teamKey = #keyPath(MockRole.team)
    public static let conversationKey = #keyPath(MockRole.conversation)
    
    @NSManaged public var name: String
    @NSManaged public var actions: Set<MockAction>
    @NSManaged public var team: MockTeam?
    @NSManaged public var conversation: MockConversation?
    @NSManaged public var participantRoles: Set<MockParticipantRole>
    
    public static var entityName = "Role"
}

extension MockRole {
    @objc
    public static func insert(in context: NSManagedObjectContext, name: String, actions: Set<MockAction>) -> MockRole {
        let role: MockRole = insert(in: context)
        role.name = name
        role.actions = actions
        
        return role
    }
    
    var payloadValues: [String : Any?] {
        return [
            "conversation_role" : name,
            "actions" : actions.map({$0.payload})
        ]
    }
    
    var payload: ZMTransportData {
        return payloadValues as NSDictionary
    }
}

extension MockRole {
    @objc(existingRoleWithName:team:conversation:managedObjectContext:)
    public static func existingRole(with name: String,
                                    team: MockTeam?,
                                    conversation: MockConversation?,
                             managedObjectContext: NSManagedObjectContext) -> MockRole? {
        let namePredicate = NSPredicate(format: "%K == %@", #keyPath(MockRole.name), name)
        let teamOrConvoPredicate: NSPredicate
       
        teamOrConvoPredicate = (team != nil) ? NSPredicate(format: "%K == %@", MockRole.teamKey, team!) :
                                                    NSPredicate(format: "%K == %@", MockRole.conversationKey, conversation!)
        let rolePredicate: NSPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            namePredicate,
            teamOrConvoPredicate
            ])
        
        return MockRole.fetch(in: managedObjectContext, withPredicate: rolePredicate)
    }
}

extension MockRole {
    @objc
    public static func admin(managedObjectContext: NSManagedObjectContext) -> MockRole {
        return self.insert(in: managedObjectContext, name: MockConversation.admin, actions: MockTeam.createAdminActions(context: managedObjectContext))
    }
    
    @objc
    public static func member(managedObjectContext: NSManagedObjectContext) -> MockRole {
        return self.insert(in: managedObjectContext, name: MockConversation.member, actions: MockTeam.createMemberActions(context: managedObjectContext))
    }
}
