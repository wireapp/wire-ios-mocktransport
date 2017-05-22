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

public extension MockTransportSession {
    @objc(pushEventsForTeamsWithInserted:updated:deleted:shouldSendEventsToSelfUser:)
    public func pushEventsForTeams(inserted: Set<NSManagedObject>, updated: Set<NSManagedObject>, deleted: Set<NSManagedObject>, shouldSendEventsToSelfUser: Bool) -> Array<MockPushEventProtocol> {
        guard shouldSendEventsToSelfUser else { return [] }
        
        let insertedEvents = inserted.flatMap { $0 as? MockTeam }.map(MockTeamEvent.Inserted)
        let updatedEvents =  updated.flatMap { $0 as? MockTeam }.map(MockTeamEvent.Updated)
        let deletedEvents = deleted.flatMap { $0 as? MockTeam }.map(MockTeamEvent.Deleted)
        let allEvents = insertedEvents + updatedEvents + deletedEvents
        
        return allEvents.map { MockPushEvent(with: $0.payload, uuid: UUID.create(), isTransient: false) }
    }
}
