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
import XCTest
import WireDataModel
@testable import WireMockTransport

// MARK: - Team events
class MockTransportSessionTeamEventsTests : MockTransportSessionTests {
    
    func check(event: TestPushChannelEvent?, hasType type: ZMTUpdateEventType, team: MockTeam, data: [String : String]? = nil, file: StaticString = #file, line: UInt = #line) {
        check(event: event, hasType: type, teamIdentifier: team.identifier, data: data, file: file, line: line)
    }
    
    func check(event: TestPushChannelEvent?, hasType type: ZMTUpdateEventType, teamIdentifier: String, data: [String : String]? = nil, file: StaticString = #file, line: UInt = #line) {
        guard let event = event else { XCTFail("Should have event", file: file, line: line); return }
        
        XCTAssertEqual(event.type, type, "Wrong type", file: file, line: line)
        
        guard let payload = event.payload as? [String : Any] else { XCTFail("Event should have payload", file: file, line: line); return }
        
        XCTAssertEqual(payload["team"] as? String, teamIdentifier, "Wrong team identifier", file: file, line: line)
        
        guard let expectedData = data else {
            return
        }
        guard let data = payload["data"] as? [String : String] else { XCTFail("Event payload should have data", file: file, line: line); return }

        for (key, value) in expectedData {
            XCTAssertEqual(data[key], value, "Event payload data does not contain key: \"\(key)\"", file: file, line: line)
        }
    }
    
    func testThatItCreatesEventsForInsertedTeams() {
        // Given
        let name1 = "foo"
        let name2 = "bar"
        
        var team1: MockTeam!
        var team2: MockTeam!
        
        createAndOpenPushChannel()
        
        // When
        sut.performRemoteChanges { session in
            team1 = session.insertTeam(withName: name1)
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        sut.performRemoteChanges { session in
            team2 = session.insertTeam(withName: name2)
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // Then
        let events = pushChannelReceivedEvents as! [TestPushChannelEvent]
        XCTAssertEqual(events.count, 2)
        
        check(event: events.first, hasType: .ZMTUpdateEventTeamCreate, team: team1)
        check(event: events.last, hasType: .ZMTUpdateEventTeamCreate, team: team2)
    }
    
    func testThatItCreatesEventsForDeletedTeams() {
        // Given
        var team: MockTeam!
        var teamIdentifier: String!
        
        sut.performRemoteChanges { session in
            team = session.insertTeam(withName: "some")
            teamIdentifier = team.identifier
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        createAndOpenPushChannel()

        // When
        sut.performRemoteChanges { session in
            session.delete(team)
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // Then
        let events = pushChannelReceivedEvents as! [TestPushChannelEvent]
        XCTAssertEqual(events.count, 1)
        
        check(event: events.first, hasType: .ZMTUpdateEventTeamDelete, teamIdentifier: teamIdentifier)
    }
    
    func testThatItCreatesEventsForUpdatedTeams() {
        // Given
        var team: MockTeam!
        
        sut.performRemoteChanges { session in
            team = session.insertTeam(withName: "some")
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        createAndOpenPushChannel()
        
        // When
        let newName = "other"
        let assetKey = "123-082"
        let assetId = "541-992"
        sut.performRemoteChanges { session in
            team.name = newName
            team.pictureAssetId = assetId
            team.pictureAssetKey = assetKey
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // Then
        let events = pushChannelReceivedEvents as! [TestPushChannelEvent]
        XCTAssertEqual(events.count, 1)
        
        let updateData = [
            "name" : newName,
            "icon" : assetId,
            "icon_key" : assetKey
        ]
        check(event: events.first, hasType: .ZMTUpdateEventTeamUpdate, team: team, data: updateData)
    }
}
