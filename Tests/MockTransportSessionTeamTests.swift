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
}

// MARK: - Team permissions
extension MockTransportSessionTests {
    func testThatItDoesNotReturnErrorForTeamsWhereUserIsNotAMemberWhenNotEnforced() {
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
        XCTAssertEqual(response?.httpStatus, 200)
        XCTAssertNotNil(response?.payload)
    }
    
    func testThatItReturnsErrorForTeamsWhereUserIsNotAMemberWhenEnforced() {
        // Given
        var team: MockTeam!
        
        sut.performRemoteChanges { session in
            _ = session.insertSelfUser(withName: "Am I")
            team = session.insertTeam(withName: "name")
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // When
        sut.teamPermissionsEnforced = true
        let path = "/teams/\(team.identifier)"
        let response = self.response(forPayload: nil, path: path, method: .methodGET)
        
        // Then
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.httpStatus, 404)
        let payload = response?.payload?.asDictionary() as? [String : String]
        XCTAssertEqual(payload?["label"], "no-team")
    }
    
    func testThatItReturnsErrorForTeamMembersWhereUserIsNotAMemberWhenEnforced() {
        // Given
        var team: MockTeam!
        
        sut.performRemoteChanges { session in
            _ = session.insertSelfUser(withName: "Am I")
            team = session.insertTeam(withName: "name")
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // When
        sut.teamPermissionsEnforced = true
        let path = "/teams/\(team.identifier)/members"
        let response = self.response(forPayload: nil, path: path, method: .methodGET)
        
        // Then
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.httpStatus, 404)
        let payload = response?.payload?.asDictionary() as? [String : String]
        XCTAssertEqual(payload?["label"], "no-team")
    }

    func testThatItReturnsErrorForTeamMembersWhereUserDoesNotHavePermissionWhenEnforced() {
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
        sut.teamPermissionsEnforced = true
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

// MARK: - Members
extension MockTransportSessionTeamTests {
    
    func testMembersPayload() {
        // Given
        var member: MockMember!
        var user: MockUser!
        let permission1 = Permissions.TransportString.addTeamMember
        let permission2 = Permissions.TransportString.getTeamConversations

        sut.performRemoteChanges { session in
            let team = session.insertTeam(withName: "name")
            user = session.insertUser(withName: "Am I")
            member = session.insertMember(with: user, in: team)
            member.permissions = [
                Permissions(string: permission1.rawValue)!,
                Permissions(string: permission2.rawValue)!
            ]
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        // When
        let payload = member.payload.asDictionary() as? [String : Any]
        
        // Then
        let userId = payload?["user"]
        XCTAssertNotNil(userId)
        XCTAssertEqual(userId as? String, user.identifier)
        
        guard let permissions = payload?["permissions"] else { XCTFail("No permissions key"); return }
        guard let permissionData = permissions as? [String] else { XCTFail("Wrong permissions key type"); return }

        let permissionsSet = Set(permissionData)
        XCTAssertEqual(permissionsSet.count, 2)
        XCTAssert(permissionData.contains(permission1.rawValue))
        XCTAssert(permissionData.contains(permission2.rawValue))
    }
    
    func testThatItFetchesTeamMembers() {
        // Given
        var user1: MockUser!
        var user2: MockUser!
        var team: MockTeam!
        var creator: MockUser!
        
        sut.performRemoteChanges { session in
            team = session.insertTeam(withName: "name")
            team.assetKey = "1234-abc"
            creator = session.insertUser(withName: "creator")
            team.creator = creator
            user1 = session.insertUser(withName: "one")
            user2 = session.insertUser(withName: "two")
            _ = session.insertMember(with: user1, in: team)
            _ = session.insertMember(with: user2, in: team)
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
