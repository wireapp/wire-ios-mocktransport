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

extension MockConversation {
    @objc public static func insertConversationInto(context: NSManagedObjectContext, forTeam team: MockTeam, with users:[MockUser]) -> MockConversation {
        let conversation = NSEntityDescription.insertNewObject(forEntityName: "Conversation", into: context) as! MockConversation
        conversation.type = .group
        conversation.team = team
        conversation.identifier = UUID.create().transportString()
        conversation.lastEventTime = Date()
        conversation.mutableOrderedSetValue(forKey: #keyPath(MockConversation.activeUsers)).addObjects(from: users)
        return conversation
    }
}
