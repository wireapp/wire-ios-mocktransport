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

import XCTest
import WireDataModel
@testable import WireMockTransport

class MockTransportSessionBroadcastTests: MockTransportSessionTests {
    
    func testThatItReturnsMissingClientsWhenReceivingOTRMessage() {
        // given
        var selfUser : MockUser!
        var selfClient : MockUserClient!
        var secondSelfClient : MockUserClient!
        
        var otherUser : MockUser!
        var otherUserClient : MockUserClient!
        var secondOtherUserClient : MockUserClient!
        
        sut.performRemoteChanges { session in
            selfUser = session.insertSelfUser(withName: "foo")
            selfClient = session.registerClient(for: selfUser, label: "self user", type: "permanent")
            secondSelfClient = session.registerClient(for: selfUser, label: "self2", type: "permanent")
            
            otherUser = session.insertUser(withName: "bar")
            otherUserClient = otherUser.clients.anyObject() as! MockUserClient
            secondOtherUserClient = session.registerClient(for: otherUser, label: "other2", type: "permanent")
        }
        XCTAssertTrue(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        
        let messageText = "asdpasd"
        let message = ZMGenericMessage.message(text: messageText, nonce: UUID.create().transportString())
        let base64Content = message.data().base64EncodedString()
        
        let redundantClientId = NSString.createAlphanumerical()
        let payload : [String : Any] = [
            "sender": selfClient.identifier!,
            "recipients": [
                otherUser.identifier :
                    [ otherUserClient.identifier!: base64Content,
                      redundantClientId: base64Content] ]
        ]
        
        // when
        let response = self.response(forPayload: payload as ZMTransportData, path: "/broadcast/otr/messages", method: .methodPOST)
        
        // then
        XCTAssertNil(response)
        XCTAssertEqual(response?.httpStatus, 412)
    }
    
}
