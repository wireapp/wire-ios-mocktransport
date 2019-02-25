////
// Wire
// Copyright (C) 2019 Wire Swiss GmbH
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

class MockTransportSessionUsersTests_Swift: MockTransportSessionTests {
    func testThatItReturnsRichInfo_404_whenUserDoesNotExist() {
        //given
        let userId = "1234"
        
        // when
        let response = self.response(forPayload: nil, path: "/users/\(userId)/rich_info", method: .methodGET)
        
        // then
        XCTAssertEqual(response?.httpStatus, 404)
    }
    
    func testThatItReturnsRichInfo_EmptyWhenUserDoesNotHaveAny() {
        //given
        let userId = "123456"
        sut.performRemoteChanges {
            let user = $0.insertUser(withName: "some")
            user.identifier = userId
        }
        
        // when
        guard let response = self.response(forPayload: nil, path: "/users/\(userId)/rich_info", method: .methodGET) else { XCTFail(); return }
        
        // then
        XCTAssertEqual(response.httpStatus, 200)
        XCTAssertEqual(response.payload as? NSDictionary, ["fields" : [] ])
    }
    
    func testThatItReturnsRichInfo_WhenUserHasIt() {
        //given
        let userId = "123456"
        let richProfile: NSArray = [
                [
                    "type": "Department",
                    "value": "Sales & Marketing"
                ],
                [
                    "type": "Favorite color",
                    "value": "Blue"
                ]
            ]
        sut.performRemoteChanges {
            let user = $0.insertUser(withName: "some")
            user.identifier = userId
            user.richProfile = richProfile
        }
        
        // when
        guard let response = self.response(forPayload: nil, path: "/users/\(userId)/rich_info", method: .methodGET) else { XCTFail(); return }
        
        // then
        XCTAssertEqual(response.httpStatus, 200)
        XCTAssertEqual(response.payload as? NSDictionary, ["fields" : richProfile ])

    }
    
}
