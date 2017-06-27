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
import WireDataModel

extension ZMTransportResponse {
    static let teamNotFound = ZMTransportResponse(payload: ["label" : "no-team"] as ZMTransportData, httpStatus: 404, transportSessionError: nil)
    static let notTeamMember = ZMTransportResponse(payload: ["label" : "no-team-member"] as ZMTransportData, httpStatus: 403, transportSessionError: nil)
    static let operationDenied = ZMTransportResponse(payload: ["label" : "operation-denied"] as ZMTransportData, httpStatus: 403, transportSessionError: nil)
}

extension MockTransportSession {
    @objc(processTeamsRequest:)
    public func processTeamsRequest(_ request: ZMTransportRequest) -> ZMTransportResponse {
        var response: ZMTransportResponse?
        
        switch request {
        case "/teams/*":
            response = fetchTeam(with: request.RESTComponents(index: 1))
        case "/teams/*/members":
            response = fetchMembersForTeam(with: request.RESTComponents(index: 1))
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
        let predicate = MockTeam.predicateWithIdentifier(identifier: identifier)
        guard let team: MockTeam = MockTeam.fetch(in: managedObjectContext, withPredicate: predicate),
              team == selfUser.membership?.team
        else { return .teamNotFound }
        if let permissionError = ensurePermission([], in: team) {
            return permissionError
        }
        return ZMTransportResponse(payload: team.payload, httpStatus: 200, transportSessionError: nil)
    }
    
    private func fetchMembersForTeam(with identifier: String?) -> ZMTransportResponse? {
        guard let identifier = identifier else { return nil }
        let predicate = MockTeam.predicateWithIdentifier(identifier: identifier)
        guard let team: MockTeam = MockTeam.fetch(in: managedObjectContext, withPredicate: predicate) else { return .teamNotFound }
        if let permissionError = ensurePermission(.getMemberPermissions, in: team) {
            return permissionError
        }
        
        let payload: [String : Any] = [
            "members" : team.members.map { $0.payload }
        ]

        return ZMTransportResponse(payload: payload as ZMTransportData, httpStatus: 200, transportSessionError: nil)
    }
    
    private func ensurePermission(_ permissions: Permissions, in team: MockTeam) -> ZMTransportResponse? {
        guard let membership = selfUser.membership, membership.team == team
        else { return .notTeamMember }
        
        guard membership.permissions.contains(permissions) else {
            return .operationDenied
        }
        // All good, no error returned
        return nil
    }
    
}
