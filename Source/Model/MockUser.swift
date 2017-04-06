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

@objc public class MockUser: NSManagedObject {
    
    public static let mutualFriendsKey = "mutual_friends"
    public static let totalMutualFriendsKey = "total_mutual_friends"

    @NSManaged public var email: String?
    @NSManaged public var password: String?
    @NSManaged public var phone: String?
    @NSManaged public var handle: String?
    @NSManaged public var accentID: Int16
    @NSManaged public var name: String?
    @NSManaged public var identifier: String
    @NSManaged public var pictures: NSOrderedSet
    @NSManaged public var completeProfileAssetIdentifier: String?
    @NSManaged public var previewProfileAssetIdentifier: String?
    
    @NSManaged public var isEmailValidated: Bool
    @NSManaged public var isSendingVideo: Bool
    @NSManaged public var ignoredCallConversation: MockConversation?
    
    @NSManaged public var connectionsFrom: NSOrderedSet
    @NSManaged public var connectionsTo: NSOrderedSet
    @NSManaged public var activeCallConversations: NSOrderedSet
    
    @NSManaged public var clients: NSMutableSet
    
    @NSManaged public var invitations: NSOrderedSet
    
    
    override public func awakeFromInsert() {
        if accentID == 0 {
            accentID = 2
        }
    }
}

extension MockUser {
    @objc public static var sortedFetchRequest: NSFetchRequest<MockUser> {
        let request = NSFetchRequest<MockUser>(entityName: "User")
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(MockUser.identifier), ascending: true)]
        return request
    }
    
    @objc public static func sortedFetchRequest(withPredicate predicate: NSPredicate) -> NSFetchRequest<MockUser> {
        let request = sortedFetchRequest
        request.predicate = predicate
        return request
    }
}

// MARK: - Images
extension MockUser {
    @objc public var mediumImageIdentifier: String? {
        return mediumImage?.identifier
    }
    
    @objc public var smallProfileImageIdentifier: String? {
        return smallProfileImage?.identifier
    }
    
    @objc public var smallProfileImage: MockPicture? {
        return picture(withTag: "smallProfile")
    }
    
    @objc public var mediumImage: MockPicture? {
        return picture(withTag: "medium")
    }
    
    fileprivate func picture(withTag tag: String) -> MockPicture? {
        for picture in pictures {
            if let mockPicture = picture as? MockPicture, mockPicture.info["tag"] as? String == tag {
                return mockPicture
            }
        }
        return nil
    }

    @objc public func removeLegacyPictures() {
        [smallProfileImage, mediumImage].flatMap { $0 }.forEach(managedObjectContext!.delete)
    }
    
}


// MARK: - Transport data
extension MockUser {
    
    @objc public var selfUserTransportData: ZMTransportData {
        return selfUserData as ZMTransportData
    }
    
    var selfUserData: [String : Any?] {
        var regularData = data
        if let email = email {
            regularData["email"] = email
        }
        if let phone = phone {
            regularData["phone"] = phone
        }
        return regularData
    }

    @objc public var transportData: ZMTransportData {
        return data as ZMTransportData
    }
    
    var data: [String : Any?] {
        precondition(self.accentID != 0, "Accent ID is not set")
        let pictureData = pictures.map(with: #selector(getter: transportData)) ?? []
        return [
            "accent_id" : accentID,
            "name" : name,
            "id" : identifier,
            "handle" : handle,
            "picture" : pictureData.array,
            "assets" : assetData
        ]
    }
    
    var assetData: [[String : Any]]? {
        guard let previewId = previewProfileAssetIdentifier, let completeId = completeProfileAssetIdentifier else { return nil }
        return [
            ["size" : "preview", "type" : "image", "key" : previewId],
            ["size" : "complete", "type" : "image", "key" : completeId],
        ]
    }
    
    public var changePushPayload: [String : Any]? {
        var payload = [String : Any]()
        let regularProperties = Set(arrayLiteral: #keyPath(MockUser.name), #keyPath(MockUser.email), #keyPath(MockUser.phone))
        let assetIds = Set(arrayLiteral: #keyPath(MockUser.previewProfileAssetIdentifier), #keyPath(MockUser.completeProfileAssetIdentifier))
        for (changedKey, value) in changedValues() {
            if regularProperties.contains(changedKey) {
                payload[changedKey] = value
            } else if (changedKey == "accentID") {
                payload["accent_id"] = value
            } else if (assetIds.contains(changedKey)) {
                payload["assets"] = assetData ?? []
            }
        }
        if payload.isEmpty {
            return nil
        } else {
            payload["id"] = identifier
            return payload
        }
    }
    
}
