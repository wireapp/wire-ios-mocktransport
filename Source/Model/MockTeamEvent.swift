//
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
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

@objc public class MockTeamEvent: NSObject {
    
    public enum Kind: String {
        case create = "team.create"
        case delete = "team.delete"
        case update = "team.update"
    }
    
    public let data: [String : String]
    public let teamIdentifier: String
    public let kind: Kind
    
    public static func Inserted(team: MockTeam) -> MockTeamEvent {
        return MockTeamEvent(kind: .create, team: team, data: [:])
    }
    
    public static func Updated(team: MockTeam) -> MockTeamEvent {
        var data = [String : String]()
        if let name = team.name {
            data["name"] = name
        }
        if let assetId = team.pictureAssetId {
            data["icon"] = assetId
        }
        if let assetKey = team.pictureAssetKey {
            data["icon_key"] = assetKey
        }
        
        return MockTeamEvent(kind: .update, team: team, data: data)
    }
    
    public static func Deleted(team: MockTeam) -> MockTeamEvent {
        return MockTeamEvent(kind: .delete, team: team, data: [:])
    }
    
    public init(kind: Kind, team: MockTeam, data: [String : String]) {
        self.kind = kind
        self.teamIdentifier = team.identifier
        self.data = data
    }
    
    @objc public var payload: ZMTransportData {
        return [
            "team" : teamIdentifier,
            "time" : "",
            "type" : kind.rawValue,
            "data" : data
            ] as ZMTransportData
    }
    
    public override var debugDescription: String {
        return "<\(type(of: self))> = \(kind.rawValue) team \(teamIdentifier)"
    }
}
