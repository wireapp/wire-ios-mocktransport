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

class MockTransportSessionTeamTests : MockTransportSessionTests {
    
    func testThatItInsertsTeam() {
        let name1 = "foo"
        let name2 = "bar"

        var team1: MockTeam!
        var team2: MockTeam!

        sut.performRemoteChanges { session in
            team1 = session.insertTeam(withName: name1)
            team2 = session.insertTeam(withName: name2)
        }
        XCTAssert(waitForAllGroupsToBeEmpty(withTimeout: 0.5))
        XCTAssertEqual(team1.name, name1)
        XCTAssertNotNil(team1.identifier)
        XCTAssertEqual(team2.name, name2)
        XCTAssertNotNil(team2.identifier)
        XCTAssertNotEqual(team1.identifier, team2.identifier)
    }

}
