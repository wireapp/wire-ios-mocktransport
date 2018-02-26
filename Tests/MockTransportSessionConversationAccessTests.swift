////
// Wire
// Copyright (C) 2018 Wire Swiss GmbH
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

class MockTransportSessionConversationAccessTests: MockTransportSessionTests {

    var team: MockTeam!
    var selfUser: MockUser!
    var conversation: MockConversation!

    override func setUp() {
        super.setUp()
        sut.performRemoteChanges { session in
            self.selfUser = session.insertSelfUser(withName: "me")
            self.team = session.insertTeam(withName: "A Team", isBound: true)
            self.conversation = session.insertTeamConversation(to: self.team, with: [session.insertUser(withName: "some")], creator: self.selfUser)

        }
        XCTAssert(self.waitForAllGroupsToBeEmpty(withTimeout: 0.5))
    }

    override func tearDown() {
        team = nil
        selfUser = nil
        conversation = nil
        super.tearDown()
    }

    func testThatSettingAccessModeReturnsErrorWhenConversationDoesNotExist() {
        // when
        let response = self.response(forPayload: [:] as ZMTransportData , path: "/conversations/123456/access", method: .methodPUT)

        // then
        XCTAssertEqual(response?.httpStatus, 404)
    }

    func testThatSettingAccessModeReturnsErrorWhenMissingAccess() {
        // given
        let payload = [
            "access_role": "verified",
        ] as ZMTransportData

        // when
        let response = self.response(forPayload: payload , path: "/conversations/\(self.conversation.identifier)/access", method: .methodPUT)

        // then
        XCTAssertEqual(response?.httpStatus, 400)
    }

    func testThatSettingAccessModeReturnsErrorWhenMissingAccessRole() {
        // given
        let payload = [
            "access": ["invite"],
            ] as ZMTransportData

        // when
        let response = self.response(forPayload: payload , path: "/conversations/\(self.conversation.identifier)/access", method: .methodPUT)

        // then
        XCTAssertEqual(response?.httpStatus, 400)
    }

    func testThatSettingAccessModeReturnsCorrectDataInPayload() {

        let role = "team"
        let access = ["invite", "code"]
        // given
        let payload = [
            "access_role": role,
            "access": access,
            ] as ZMTransportData

        // when
        let response = self.response(forPayload: payload , path: "/conversations/\(self.conversation.identifier)/access", method: .methodPUT)

        // then
        XCTAssertEqual(response?.httpStatus, 200)
        guard let receivedPayload = response?.payload as? [String: Any] else { XCTFail(); return }
        guard let payloadData = receivedPayload["data"] as? [String: Any] else { XCTFail(); return }
        guard let responseRole = payloadData["access_role"] as? String else { XCTFail(); return }
        guard let responseAccess = payloadData["access"] as? [String] else { XCTFail(); return }


        XCTAssertEqual(responseRole, role)
        XCTAssertEqual(responseAccess, access)
    }
}
