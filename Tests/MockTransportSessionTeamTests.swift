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
@testable import WireMockTransport

class MockTransportSessionTeamTests : MockTransportSessionTests {
    
    func testThatItInsertsTeam() {
        // Given
        let name1 = "foo"
        let name2 = "bar"

        var team1: MockTeam!
        var team2: MockTeam!

        // When
        sut.performRemoteChanges { session in
            team1 = session.insertTeam(withName: name1)
            team2 = session.insertTeam(withName: name2)
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // Then
        XCTAssertEqual(team1.name, name1)
        XCTAssertNotNil(team1.identifier)
        XCTAssertEqual(team2.name, name2)
        XCTAssertNotNil(team2.identifier)
        XCTAssertNotEqual(team1.identifier, team2.identifier)
    }
    
    func testThatItCreatesTeamPayload() {
        // Given
        var team: MockTeam!
        var creator: MockUser!
        
        sut.performRemoteChanges { session in
            team = session.insertTeam(withName: "name")
            team.assetKey = "1234-abc"
            creator = session.insertUser(withName: "creator")
            team.creator = creator
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // When
        let payload = team.payload.asDictionary() as? [String : String]

        // Then
        XCTAssertEqual(payload?["id"], team.identifier)
        XCTAssertEqual(payload?["creator"], creator.identifier)
        XCTAssertEqual(payload?["name"], team.name)
        XCTAssertEqual(payload?["icon_key"], team.assetKey)
    }
    
    func testThatItFetchesTeam() {
        // Given
        var team: MockTeam!
        var creator: MockUser!
        
        sut.performRemoteChanges { session in
            team = session.insertTeam(withName: "name")
            team.assetKey = "1234-abc"
            creator = session.insertUser(withName: "creator")
            team.creator = creator
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))

        // When
        let path = "/teams/\(team.identifier)"
        let response = self.response(forPayload: nil, path: path, method: .methodGET)
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.httpStatus, 200)
        XCTAssertNotNil(response?.payload)

        // Then
        let payload = response?.payload?.asDictionary() as? [String : String]
        XCTAssertEqual(payload?["id"], team.identifier)
        XCTAssertEqual(payload?["creator"], creator.identifier)
        XCTAssertEqual(payload?["name"], team.name)
        XCTAssertEqual(payload?["icon_key"], team.assetKey)
    }
    
    func testThatItFetchesAllTeams() {
        // Given
        var team1: MockTeam!
        var team2: MockTeam!

        sut.performRemoteChanges { session in
            team1 = session.insertTeam(withName: "some")
            team2 = session.insertTeam(withName: "other")
        }
        
        // When
        let path = "/teams"
        let response = self.response(forPayload: nil, path: path, method: .methodGET)
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.httpStatus, 200)
        XCTAssertNotNil(response?.payload)

        // Then
        let payload = response?.payload?.asDictionary() as? [String : Any]
        guard let teams = payload?["teams"] as? [[String : Any]] else {
            XCTFail("Should have teams array")
            return
        }
        XCTAssertEqual(teams.count, 2)
        
        let identifiers = Set(teams.flatMap { $0["id"] as? String })
        XCTAssertEqual(identifiers, [team1.identifier, team2.identifier])
    }
    
    func testThatConversationReturnsTeamInPayload() {
        // Given
        var team: MockTeam!
        var creator: MockUser!
        var conversation: MockConversation!
        
        sut.performRemoteChanges { session in
            team = session.insertTeam(withName: "name")
            team.assetKey = "1234-abc"
            creator = session.insertUser(withName: "creator")
            team.creator = creator
            conversation = session.insertConversation(withCreator: creator, otherUsers: [session.insertSelfUser(withName: "Am I")], type: .oneOnOne)
            conversation.team = team
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // When
        let payload = conversation.transportData().asDictionary() as? [String : Any]
        guard let teamData = payload?["team"] as? [String : Any] else {
            XCTFail("Should have team data")
            return
        }
        
        // Then
        let teamId = teamData["teamid"]
        XCTAssertNotNil(teamId)
        XCTAssertEqual(teamId as? String, team.identifier)
        
        let managed = teamData["managed"]
        XCTAssertNotNil(managed)
        XCTAssertEqual(managed as? Bool, false)
    }

}
