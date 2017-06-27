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

// MARK: - Teams
class MockTransportSessionTeamTests : MockTransportSessionTests {
    
    func checkThat(response: ZMTransportResponse?, has team: MockTeam, file: StaticString = #file, line: UInt = #line) {
        
        XCTAssertNotNil(response, "Response should not be empty", file: file, line: line)
        XCTAssertEqual(response?.httpStatus, 200, "Http status should be 200", file: file, line: line)
        XCTAssertNotNil(response?.payload, "Response should have payload", file: file, line: line)
        
        // Then
        guard let payload = response?.payload as? [String : Any] else {
            XCTFail("Response payload should have team", file: file, line: line)
            return
        }
        
        let receivedTeamIdentifier = payload["id"] as? String
        let expectedTeamIdentifier = team.identifier
        XCTAssertEqual(receivedTeamIdentifier, expectedTeamIdentifier, file: file, line: line)
    }
    
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
            let selfUser = session.insertSelfUser(withName: "Am I")
            team = session.insertTeam(withName: "name", users: [selfUser])
            team.pictureAssetKey = "1234-abc"
            team.pictureAssetId = "123-1234-abc"
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
        XCTAssertEqual(payload?["icon_key"], team.pictureAssetKey)
        XCTAssertEqual(payload?["icon"], team.pictureAssetId)
    }
    
    func testThatItFetchesTeam() {
        // Given
        var team: MockTeam!
        var creator: MockUser!
        
        sut.performRemoteChanges { session in
            let selfUser = session.insertSelfUser(withName: "Am I")
            team = session.insertTeam(withName: "name", users: [selfUser])
            team.pictureAssetKey = "1234-abc"
            team.pictureAssetId = "123-1234-abc"
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
        XCTAssertEqual(payload?["icon_key"], team.pictureAssetKey)
        XCTAssertEqual(payload?["icon"], team.pictureAssetId)
    }

}

// MARK: - Team permissions
extension MockTransportSessionTeamTests {
    
    func testThatItReturnsErrorForNonExistingTeam() {
        // Given
        sut.performRemoteChanges { session in
            _ = session.insertSelfUser(withName: "Am I")
            _ = session.insertTeam(withName: "name")
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // When
        let path = "/teams/1234"
        let response = self.response(forPayload: nil, path: path, method: .methodGET)
        
        // Then
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.httpStatus, 404)
        let payload = response?.payload?.asDictionary() as? [String : String]
        XCTAssertEqual(payload?["label"], "no-team")
    }

    
    func testThatItReturnsErrorForTeamsWhereUserIsNotAMember() {
        // Given
        var team: MockTeam!
        
        sut.performRemoteChanges { session in
            _ = session.insertSelfUser(withName: "Am I")
            team = session.insertTeam(withName: "name")
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // When
        let path = "/teams/\(team.identifier)"
        let response = self.response(forPayload: nil, path: path, method: .methodGET)
        
        // Then
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.httpStatus, 404)
        let payload = response?.payload?.asDictionary() as? [String : String]
        XCTAssertEqual(payload?["label"], "no-team")
    }
    
    func testThatItReturnsErrorForTeamMembersWhereUserIsNotAMember() {
        // Given
        var team: MockTeam!
        
        sut.performRemoteChanges { session in
            _ = session.insertSelfUser(withName: "Am I")
            team = session.insertTeam(withName: "name")
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // When
        let path = "/teams/\(team.identifier)/members"
        let response = self.response(forPayload: nil, path: path, method: .methodGET)
        
        // Then
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.httpStatus, 403)
        let payload = response?.payload?.asDictionary() as? [String : String]
        XCTAssertEqual(payload?["label"], "no-team-member")
    }

    func testThatItReturnsErrorForTeamMembersWhereUserDoesNotHavePermission() {
        // Given
        var team: MockTeam!
        
        sut.performRemoteChanges { session in
            let selfUser = session.insertSelfUser(withName: "Am I")
            team = session.insertTeam(withName: "name")
            let member = session.insertMember(with: selfUser, in: team)
            member.permissions = []
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // When
        let path = "/teams/\(team.identifier)/members"
        let response = self.response(forPayload: nil, path: path, method: .methodGET)
        
        // Then
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.httpStatus, 403)
        let payload = response?.payload?.asDictionary() as? [String : String]
        XCTAssertEqual(payload?["label"], "operation-denied")
    }
}

// MARK: - Conversation
extension MockTransportSessionTeamTests {
    func testThatConversationReturnsTeamInPayload() {
        // Given
        var team: MockTeam!
        var creator: MockUser!
        var conversation: MockConversation!
        
        sut.performRemoteChanges { session in
            team = session.insertTeam(withName: "name")
            team.pictureAssetKey = "1234-abc"
            team.pictureAssetId = "123-1234-abc"
            
            creator = session.insertUser(withName: "creator")
            team.creator = creator
            conversation = session.insertTeamConversation(to: team, with: [creator, session.insertSelfUser(withName: "Am I")])
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // When
        let payload = conversation.transportData().asDictionary() as? [String : Any]
        
        // Then
        XCTAssertEqual(payload?["team"] as? String, team.identifier)
    }
}

// MARK: - Members
extension MockTransportSessionTeamTests {
    
    func testMembersPayload() {
        // Given
        var member: MockMember!
        var user: MockUser!
        let permission1 = Permissions.addTeamMember
        let permission2 = Permissions.getTeamConversations

        sut.performRemoteChanges { session in
            let team = session.insertTeam(withName: "name")
            user = session.insertUser(withName: "Am I")
            member = session.insertMember(with: user, in: team)
            member.permissions = [permission1, permission2]
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // When
        let payload = member.payload.asDictionary() as? [String : Any]
        
        // Then
        let userId = payload?["user"]
        XCTAssertNotNil(userId)
        XCTAssertEqual(userId as? String, user.identifier)
        
        guard let permissionsPayload = payload?["permissions"] as? [String: Any] else { return XCTFail("No permissions payload") }
        guard let permissionsValue = permissionsPayload["self"] as? NSNumber else { return XCTFail("No permissions value") }
        let permissions = Permissions(rawValue: permissionsValue.int64Value)
        XCTAssertEqual(permissions, [permission1, permission2])
    }
    
    func testThatItFetchesTeamMembers() {
        // Given
        var user1: MockUser!
        var user2: MockUser!
        var team: MockTeam!
        
        sut.performRemoteChanges { session in
            user1 = session.insertSelfUser(withName: "one")
            user2 = session.insertUser(withName: "two")

            team = session.insertTeam(withName: "name", users: [user1, user2])
            team.pictureAssetKey = "1234-abc"
            team.pictureAssetId = "123-1234-abc"
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // When
        let path = "/teams/\(team.identifier)/members"
        let response = self.response(forPayload: nil, path: path, method: .methodGET)
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.httpStatus, 200)
        XCTAssertNotNil(response?.payload)
        
        // Then
        let payload = response?.payload?.asDictionary() as? [String : Any]
        guard let teams = payload?["members"] as? [[String : Any]] else {
            XCTFail("Should have teams array")
            return
        }
        XCTAssertEqual(teams.count, 2)
        
        let identifiers = Set(teams.flatMap { $0["user"] as? String })
        XCTAssertEqual(identifiers, [user1.identifier, user2.identifier])
    }
}
