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

extension MockTransportSession {
    @objc(processTeamsRequest:)
    public func processTeamsRequest(_ request: ZMTransportRequest) -> ZMTransportResponse {
        var response: ZMTransportResponse?
        
        switch request {
        case "/teams/*":
            response = fetchTeam(with: request.RESTComponents(index: 1))
        default:
            break
        }

        if let response = response {
            return response
        } else {
            return ZMTransportResponse(payload: nil, httpStatus: 404, transportSessionError: nil)
        }
    }
    
    private func fetchTeam(with identifier: String?) -> ZMTransportResponse? {
        guard let identifier = identifier else { return nil }
        guard let team = MockTeam.fetch(in: managedObjectContext, identifier: identifier) else { return nil }
        return ZMTransportResponse(payload: team.payload, httpStatus: 200, transportSessionError: nil)
    }
}
