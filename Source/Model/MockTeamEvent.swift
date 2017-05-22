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
    
    public let payload: ZMTransportData
    public let conversation: MockConversation
    public let timestamp = NSDate()
    public let kind: Kind
    
    public init(kind: Kind, payload: ZMTransportData, conversation: MockConversation) {
        self.kind = kind
        self.payload = payload
        self.conversation = conversation
    }
    
    @objc public var transportData: ZMTransportData {
        return [
            "id" : conversation.identifier,
            "payload" : [ payload ],
            "time" : "",
            "type" : kind.rawValue,
            ] as ZMTransportData
    }
    
    public override var description: String {
        return payload.description
    }
    
    public override var debugDescription: String {
        return "<\(type(of: self))> payload = \(payload)"
    }
}
