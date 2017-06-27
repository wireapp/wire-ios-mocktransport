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

@objc public final class MockTeam: NSManagedObject, EntityNamedProtocol {
    @NSManaged public var conversations: Set<MockConversation>?
    @NSManaged public var members: Set<MockMember>
    @NSManaged public var creator: MockUser?
    @NSManaged public var name: String?
    @NSManaged public var pictureAssetKey: String?
    @NSManaged public var pictureAssetId: String
    @NSManaged public var identifier: String
    @NSManaged public var createdAt: Date

    public static var entityName = "Team"
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        identifier = NSUUID.create().transportString()
        createdAt = Date()
    }
}

extension MockTeam {
    public static func predicateWithIdentifier(identifier: String) -> NSPredicate {
        return NSPredicate(format: "%K == %@", #keyPath(MockTeam.identifier), identifier)
    }
    
    @objc(containsUser:)
    public func contains(user: MockUser) -> Bool {
        guard let userMembership = user.membership else { return false }
        return members.contains(userMembership)
    }
    
    @objc
    public static func insert(in context: NSManagedObjectContext, name: String?, assetId: String?, assetKey: String?) -> MockTeam {
        let team: MockTeam = insert(in: context)
        team.name = name
        team.pictureAssetId = assetId ?? ""
        team.pictureAssetKey = assetKey
        return team
    }
    
    var payloadValues: [String : String?] {
        return [
            "id": identifier,
            "name" : name,
            "icon_key" : pictureAssetKey,
            "icon" : pictureAssetId,
            "creator" : creator?.identifier
        ]
    }
    
    var payload: ZMTransportData {
        return payloadValues as NSDictionary
    }
}
