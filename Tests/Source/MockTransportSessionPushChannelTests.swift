//
// Wire
// Copyright (C) 2021 Wire Swiss GmbH
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

extension MockTransportSessionTests {
    
    private func waitForAllGroupsToBeEmpty(_ timeout: Float) {
        if !waitForAllGroupsToBeEmpty(withTimeout: 0.5) {
            XCTFail("Timed out waiting for groups to empty.")
        }
    }
    
    func testThatNoPushChannelEventIsSentBeforeThePushChannelIsOpened() {
        var selfUser: MockUser?
        sut.performRemoteChanges({ session in
            selfUser = session.insertSelfUser(withName: "Old self username")
        })
        
        waitForAllGroupsToBeEmpty(0.5)
        
        XCTAssertEqual(pushChannelReceivedEvents.count, 0)
        
        // WHEN
        sut.performRemoteChanges({_ in
            selfUser?.name = "New"
            
        })
        
        waitForAllGroupsToBeEmpty(0.5)

        // THEN
        XCTAssertEqual(pushChannelReceivedEvents.count, 0)
    }
    
    func testThatPushChannelEventsAreSentWhenThePushChannelIsOpened() {
        var selfUser: MockUser?
        sut.performRemoteChanges({ session in
            selfUser = session.insertSelfUser(withName: "Old self username")
        })
        waitForAllGroupsToBeEmpty(0.5)
        XCTAssertEqual(pushChannelReceivedEvents.count, 0)
    
        // WHEN
        createAndOpenPushChannelAndCreateSelfUser(false)
        sut.performRemoteChanges({_ in
            selfUser?.name = "New"
    
        })
        waitForAllGroupsToBeEmpty(0.5)

        // THEN
        XCTAssertEqual(pushChannelReceivedEvents.count, 1)
    }
    
    func testThatNoPushChannelEventAreSentAfterThePushChannelIsClosed() {
        var selfUser: MockUser?
        sut.performRemoteChanges({ session in
            selfUser = session.insertSelfUser(withName: "Old self username")
        })
        waitForAllGroupsToBeEmpty(0.5)
        XCTAssertEqual(pushChannelReceivedEvents.count, 0)
    
        // WHEN
        createAndOpenPushChannelAndCreateSelfUser(false)
        sut.performRemoteChanges({ session in
            session.simulatePushChannelClosed()
        })
        waitForAllGroupsToBeEmpty(0.5)
        sut.performRemoteChanges({_ in
            selfUser?.name = "New"
    
        })
        waitForAllGroupsToBeEmpty(0.5)
    
        // THEN
        XCTAssertEqual(pushChannelReceivedEvents.count, 0)
    }
    
    func testThatWeReceiveAPushEventWhenChangingSelfUserName() {
        // GIVEN
        let newName = "NEWNEWNEW"
        createAndOpenPushChannel()
    
        var selfUser: MockUser?
        var expectedUserPayload: Dictionary<AnyHashable, Any>?
        var selfUserID: String?
        sut.performRemoteChanges({ [self] session in
            selfUser = sut.selfUser
            selfUserID = selfUser?.identifier
        })
        waitForAllGroupsToBeEmpty(0.5)
        XCTAssertEqual(pushChannelReceivedEvents.count, 0)
    
    
        // WHEN
        sut.performRemoteChanges({_ in
            selfUser?.name = newName
            expectedUserPayload = [
                "id": selfUserID ?? "",
                "name": newName
            ]
        })
        waitForAllGroupsToBeEmpty(0.5)
    
        XCTAssertEqual(pushChannelReceivedEvents.count, 1)
        let nameEvent = (pushChannelReceivedEvents as? [TestPushChannelEvent])?.first
        XCTAssertEqual(nameEvent?.type, .userUpdate)
        XCTAssert((nameEvent?.payload.asDictionary()?["user"]) as? NSDictionary == (expectedUserPayload as! NSDictionary))
    }

    func testThatWeReceiveAPushEventWhenChangingSelfProfile() {
        // GIVEN
        let newValue = "NEWNEWNEW"
        createAndOpenPushChannel()
        
        var selfUser: MockUser?
        var expectedUserPayload: [AnyHashable : AnyHashable]?
        
        sut.performRemoteChanges({ [self] session in
            selfUser = sut.selfUser
        })
        waitForAllGroupsToBeEmpty(0.5)
        XCTAssertEqual(pushChannelReceivedEvents.count, 0)
        
        
        
        // WHEN
        sut.performRemoteChanges({_ in
            selfUser?.email = newValue + "-email"
            selfUser?.phone = newValue + "-phone"
            selfUser?.accentID = 5567
            if let identifier = selfUser?.identifier, let email = selfUser?.email, let phone = selfUser?.phone {
                expectedUserPayload = [
                    "id": identifier,
                    "email": email,
                    "phone": phone,
                    "accent_id": NSNumber(value: selfUser!.accentID)
                ]
            }
        })
        waitForAllGroupsToBeEmpty(0.5)
        
        XCTAssertEqual(pushChannelReceivedEvents.count, 1)
        let nameEvent = (pushChannelReceivedEvents as? [TestPushChannelEvent])?.first
        XCTAssertEqual(nameEvent?.type, .userUpdate)
        XCTAssertEqual(nameEvent?.payload.asDictionary()?["user"] as? [AnyHashable : AnyHashable], expectedUserPayload)
    }
    
    func testThatWeReceiveAPushEventWhenChangingSelfProfilePictureAssetsV3() {
        // GIVEN
        createAndOpenPushChannel()
        
        var selfUser: MockUser?
        var expectedUserPayload: [AnyHashable : AnyHashable]?
        
        sut.performRemoteChanges({ [self] session in
            selfUser = sut.selfUser
        })
        waitForAllGroupsToBeEmpty(0.5)
        XCTAssertEqual(pushChannelReceivedEvents.count, 0)
        
        // WHEN
        sut.performRemoteChanges({_ in
            selfUser?.previewProfileAssetIdentifier = "preview-id"
            selfUser?.completeProfileAssetIdentifier = "complete-id"
            if let identifier = selfUser?.identifier, let previewProfileAssetIdentifier = selfUser?.previewProfileAssetIdentifier, let completeProfileAssetIdentifier = selfUser?.completeProfileAssetIdentifier {
                expectedUserPayload = [
                    "id": identifier,
                    "assets": [
                        [
                            "size": "preview",
                            "type": "image",
                            "key": previewProfileAssetIdentifier
                        ],
                        [
                            "size": "complete",
                            "type": "image",
                            "key": completeProfileAssetIdentifier
                        ]
                    ]
                ]
            }
        })
        waitForAllGroupsToBeEmpty(0.5)
        
        XCTAssertEqual(pushChannelReceivedEvents.count, 1)
        let nameEvent = (pushChannelReceivedEvents as? [TestPushChannelEvent])?.first
        XCTAssertEqual(nameEvent?.type, .userUpdate)
        XCTAssert((nameEvent?.payload.asDictionary()?["user"] as! NSDictionary) == (expectedUserPayload! as NSDictionary))
    }
}

/*func testThatWeReceiveAPushEventWhenChangingAConnection() {
    // GIVEN
    let message = "How're you doin'?"
    createAndOpenPushChannel()
    
    var connection: MockConnection?
    weak var expectedConnectionPayload: ZMTransportData?
    
    sut.performRemoteChanges({ [self] session in
        let selfUser = sut.selfUser
        let otherUser = session?.insertUser(withName: "Mr. Other User")
        connection = session?.insertConnection(withSelfUser: selfUser, to: otherUser)
        connection?.message = message
    })
    WaitForAllGroupsToBeEmpty(0.5)
    pushChannelReceivedEvents.removeAll()
    
    // WHEN
    sut.performRemoteChanges({
        connection?.status = "blocked"
        expectedConnectionPayload = connection?.transportData
    })
    WaitForAllGroupsToBeEmpty(0.5)
    
    XCTAssertEqual(pushChannelReceivedEvents.count, 1)
    let connectEvent = pushChannelReceivedEvents.first as? TestPushChannelEvent
    XCTAssertEqual(connectEvent?.type, ZMUpdateEventTypeUserConnection)
    XCTAssertEqual(connectEvent?.payload.asDictionary["connection"], expectedConnectionPayload)
}*/
