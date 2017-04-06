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


@import WireTransport;
@import WireUtilities;
@import WireCryptobox;

#import "MockConversation.h"
#import <WireMockTransport/WireMockTransport-Swift.h>
#import <WireMockTransport/WireMockTransport-Swift.h>
#import "MockEvent.h"
#import "MockEvent.h"
#import "MockAsset.h"
#import <WireMockTransport/WireMockTransport-Swift.h>


static NSString * const JoinedString = @"joined";
static NSString * const IdleString = @"idle";

@interface MockConversation ()

@property (nonatomic, readonly) NSMutableOrderedSet *mutableActiveUsers;
@property (nonatomic, readonly) NSMutableSet *mutableInactiveUsers;
@property (nonatomic, readonly) NSMutableSet *mutableCallParticipants;

@end


@implementation MockConversation

@dynamic archived;
@dynamic clearedEventID;
@dynamic creator;
@dynamic identifier;
@dynamic selfIdentifier;
@dynamic lastEvent;
@dynamic lastEventTime;
@dynamic lastRead;
@dynamic muted;
@dynamic mutedTime;
@dynamic name;
@dynamic status;
@dynamic statusRef;
@dynamic statusTime;
@dynamic type;
@dynamic activeUsers;
@dynamic inactiveUsers;
@dynamic events;
@dynamic callWasDropped;
@dynamic callParticipants;
@dynamic isVideoCall;
@dynamic usersIgnoringCall;
@dynamic otrArchived;
@dynamic otrArchivedRef;
@dynamic otrMuted;
@dynamic otrMutedRef;

+ (instancetype)insertConversationIntoContext:(NSManagedObjectContext *)moc withSelfUser:(MockUser *)selfUser creator:(MockUser *)creator otherUsers:(NSArray *)otherUsers type:(ZMTConversationType)type;
{
    NSAssert(selfUser.identifier, @"The self user needs to have an identifier for this to work.");
    MockConversation *conversation = (id) [NSEntityDescription insertNewObjectForEntityForName:@"Conversation" inManagedObjectContext:moc];
    conversation.selfIdentifier = selfUser.identifier;
    conversation.type = type;
    NSMutableOrderedSet *addedUsers = [NSMutableOrderedSet orderedSetWithArray:otherUsers];
    [addedUsers insertObject:creator atIndex:0];
    [conversation addUsersByUser:creator addedUsers:addedUsers.array];
    conversation.identifier = [NSUUID createUUID].transportString;
    conversation.lastEventTime = [NSDate date];
    conversation.creator = creator;
    [conversation.mutableActiveUsers addObject:creator];
    return conversation;
}

+ (instancetype)insertConversationIntoContext:(NSManagedObjectContext *)moc creator:(MockUser *)creator otherUsers:(NSArray *)otherUsers type:(ZMTConversationType)type;
{
    MockConversation *conversation = (id) [NSEntityDescription insertNewObjectForEntityForName:@"Conversation" inManagedObjectContext:moc];
    conversation.type = type;
    NSMutableOrderedSet *addedUsers = [NSMutableOrderedSet orderedSetWithArray:otherUsers];
    [addedUsers insertObject:creator atIndex:0];
    [conversation addUsersByUser:creator addedUsers:addedUsers.array];
    conversation.identifier = [NSUUID createUUID].transportString;
    conversation.lastEventTime = [NSDate date];
    conversation.creator = creator;
    [conversation.mutableActiveUsers addObject:creator];
    return conversation;
}


+ (instancetype)conversationInMoc:(NSManagedObjectContext *)moc withCreator:(MockUser *)creator otherUsers:(NSArray *)otherUsers type:(ZMTConversationType)type;
{
    NSAssert(creator.identifier, @"The self user needs to have an identifier for this to work.");
    MockConversation *conversation = (id) [NSEntityDescription insertNewObjectForEntityForName:@"Conversation" inManagedObjectContext:moc];
    conversation.selfIdentifier = creator.identifier;
    conversation.type = type;
    NSMutableOrderedSet *addedUsers = [NSMutableOrderedSet orderedSetWithArray:otherUsers];
    [addedUsers insertObject:creator atIndex:0];
    [conversation addUsersByUser:creator addedUsers:addedUsers.array];
    conversation.identifier = [NSUUID createUUID].transportString;
    conversation.lastEventTime = [NSDate date];
    conversation.creator = creator;
    [conversation.mutableActiveUsers addObject:creator];
    return conversation;
}

- (MockEvent *)eventIfNeededByUser:(MockUser *)byUser type:(ZMTUpdateEventType)type data:(id<ZMTransportData>)data
{
    NSArray *eventTypesWithPushOnInsert = @[@(ZMTUpdateEventConversationAssetAdd),
                                            @(ZMTUpdateEventConversationMessageAdd),
                                            @(ZMTUpdateEventConversationClientMessageAdd),
                                            @(ZMTUpdateEventConversationOTRMessageAdd),
                                            @(ZMTUpdateEventConversationOTRAssetAdd),
                                            @(ZMTUpdateEventConversationCreate),
                                            @(ZMTUpdateEventConversationMemberJoin),
                                            @(ZMTUpdateEventConversationConnectRequest),
                                            @(ZMTUpdateEventConversationVoiceChannelDeactivate),
                                            @(ZMTUpdateEventCallState),
                                            @(ZMTUpdateEventConversationKnock),
                                            @(ZMTUpdateEventConversationHotKnock),
                                            @(ZMTUpdateEventConversationMemberUpdate)];
    

    if(self.isInserted && ![eventTypesWithPushOnInsert containsObject:@(type)]) {
        return nil;
    }
    
    MockEvent *event = (id) [NSEntityDescription insertNewObjectForEntityForName:@"Event" inManagedObjectContext:self.managedObjectContext];
    
    if ([[MockEvent persistentEvents] containsObject:@(type)]) {
        event.identifier =  [NSString stringWithFormat:@"%llx.aabb", (unsigned long long) self.filteredEvents.count+1];
    }
    event.time = [NSDate date];
    event.conversation = self;
    event.from = byUser;
    event.type = [MockEvent stringFromType:type];
    event.data = [data asTransportData];
    
    self.lastEventTime = event.time;
    if (event.identifier) {
        self.lastEvent = event.identifier;
        [self.mutableEvents addObject:event];
    }
    
    return event;
}

- (NSMutableOrderedSet *)mutableActiveUsers;
{
    return [self mutableOrderedSetValueForKey:@"activeUsers"];
}

- (NSMutableSet *)mutableInactiveUsers;
{
    return [self mutableSetValueForKey:@"inactiveUsers"];
}

- (NSMutableOrderedSet *)mutableEvents;
{
    return [self mutableOrderedSetValueForKey:@"events"];
}

- (NSMutableOrderedSet *)mutableCallParticipants
{
    return [self mutableOrderedSetValueForKey:@"callParticipants"];
}

- (NSMutableSet *)mutableUsersIgnoringCall
{
    return [self mutableSetValueForKey:@"usersIgnoringCall"];
}


- (NSOrderedSet *)filteredEvents {
    return [self.events filteredOrderedSetUsingPredicate:[NSPredicate predicateWithFormat:@"identifier != NULL"]];
}

- (NSNumber *)transportConversationType;
{
    switch (self.type) {
        case ZMTConversationTypeSelf:
            return @1;
        case ZMTConversationTypeOneOnOne:
            return @2;
        case ZMTConversationTypeGroup:
            return @0;
        case ZMTConversationTypeConnection:
            return @3;
        case ZMTConversationTypeInvalid:
        default:
            Require(NO);
            return nil;
    }
}

- (id<ZMTransportData>)transportData;
{
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
    data[@"creator"] = self.creator ? self.creator.identifier: [NSNull null];
    data[@"name"] = self.name ?: [NSNull null];
    data[@"id"] = self.identifier ?: [NSNull null];
    data[@"type"] = self.transportConversationType;
    data[@"last_event_time"] = self.lastEventTime ? [self.lastEventTime transportString] : [NSNull null];
    data[@"last_event"] = self.lastEvent ?: [NSNull null];

    NSMutableDictionary *members = [NSMutableDictionary dictionary];
    data[@"members"] = members;
    members[@"self"] = [self selfInfoDictionary];
    
    NSMutableArray *others = [NSMutableArray array];
    
    for (MockUser *activeUser in self.activeUsers) {
        if([activeUser.identifier isEqualToString:self.selfIdentifier]) { // self user should not be in others
            continue;
        }
        [others addObject:@{
                           @"status": @0,
                           @"id": activeUser.identifier
                           }];
    }
    
    for (MockUser *inactiveUser in self.inactiveUsers) {
        if([inactiveUser.identifier isEqualToString:self.selfIdentifier]) { // self user should not be in others
            continue;
        }
        [others addObject:@{
                            @"status": @1,
                            @"id": inactiveUser.identifier
                            }];
    }
    
    members[@"others"] = others;
    return data;
}


- (NSDictionary *)selfInfoDictionary
{
    NSMutableDictionary *selfInfo = [NSMutableDictionary dictionary];
    selfInfo[@"status"] = @(self.status);
    selfInfo[@"muted"] = @(self.muted);
    selfInfo[@"muted_time"] = self.mutedTime ? [self.mutedTime transportString] : [NSNull null];
    selfInfo[@"archived"] = self.archived ?: [NSNull null];
    selfInfo[@"id"] = self.selfIdentifier;
    selfInfo[@"last_read"] = self.lastRead ?: [NSNull null];
    selfInfo[@"cleared"] = self.clearedEventID ?: [NSNull null];
    selfInfo[@"otr_muted_ref"] = self.otrMutedRef ?: [NSNull null];
    selfInfo[@"otr_muted"] = @(self.otrMuted);
    selfInfo[@"otr_archived_ref"] = self.otrArchivedRef ?: [NSNull null];
    selfInfo[@"otr_archived"] = @(self.otrArchived);
    
    return selfInfo;
}


+ (NSFetchRequest *)sortedFetchRequest;
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Conversation"];
    NSSortDescriptor *sd = [NSSortDescriptor sortDescriptorWithKey:@"lastEventTime" ascending:YES];
    request.sortDescriptors = @[sd];
    request.predicate = [NSPredicate predicateWithFormat:@"type != %d", (int) ZMTConversationTypeInvalid];
    return request;
}

+ (NSFetchRequest *)sortedFetchRequestWithPredicate:(NSPredicate *)predicate
{
    NSFetchRequest *request = [self sortedFetchRequest];
    request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[request.predicate, predicate]];
    return request;
}

- (MockEvent *)insertClientMessageFromUser:(MockUser *)fromUser data:(NSData *)data
{
    return [self eventIfNeededByUser:fromUser type:ZMTUpdateEventConversationClientMessageAdd data:[data base64EncodedStringWithOptions:0]];
}


- (MockEvent *)insertOTRMessageFromClient:(MockUserClient *)fromClient
                                 toClient:(MockUserClient *)toClient
                                     data:(NSData *)data;
{
    Require(fromClient.identifier != nil);
    Require(toClient.identifier != nil);
    Require(data != nil);
    NSDictionary *eventData = @{
                                @"sender": fromClient.identifier,
                                @"recipient": toClient.identifier,
                                @"text": [data base64EncodedStringWithOptions:0]
                                };
    return [self eventIfNeededByUser:fromClient.user type:ZMTUpdateEventConversationOTRMessageAdd data:eventData];
}

- (MockEvent *)encryptAndInsertDataFromClient:(MockUserClient *)fromClient
                                     toClient:(MockUserClient *)toClient
                                         data:(NSData *)data;
{
    Require(fromClient.identifier != nil);
    Require(toClient.identifier != nil);
    Require(data != nil);
    NSData *encrypted = [MockUserClient encryptedWithData:data from:fromClient to:toClient];
    return [self insertOTRMessageFromClient:fromClient toClient:toClient data:encrypted];
}

- (MockEvent *)insertOTRAssetFromClient:(MockUserClient *)fromClient
                               toClient:(MockUserClient *)toClient
                               metaData:(NSData *)metaData
                              imageData:(NSData *)imageData
                                assetId:(NSUUID *)assetId
                               isInline:(BOOL)isInline
{
    Require(fromClient.identifier != nil);
    Require(toClient.identifier != nil);
    Require(assetId != nil);
    Require(metaData != nil);
    NSDictionary *eventData = @{
                                @"sender": fromClient.identifier,
                                @"recipient": toClient.identifier,
                                @"id": assetId.transportString,
                                @"key": [metaData base64EncodedStringWithOptions:0],
                                @"data": imageData != nil && isInline ? [imageData base64EncodedStringWithOptions:0] : [NSNull null]
                                };
    return [self eventIfNeededByUser:fromClient.user type:ZMTUpdateEventConversationOTRAssetAdd data:eventData];
}

- (MockEvent *)remotelyArchiveFromUser:(MockUser *)fromUser includeOTR:(BOOL)shouldIncludeOTR;
{
    self.archived = self.lastEvent;
    if (shouldIncludeOTR) {
        self.otrArchivedRef = self.lastEventTime.transportString;
        self.otrArchived = YES;
    }
    return [self eventIfNeededByUser:fromUser type:ZMTUpdateEventConversationMemberUpdate data:(id<ZMTransportData>)self.selfInfoDictionary];
}

- (MockEvent *)remotelyClearHistoryFromUser:(MockUser *)fromUser includeOTR:(BOOL)shouldIncludeOTR
{
    self.clearedEventID = self.lastEvent;
    self.lastRead = self.lastEvent;
    if (shouldIncludeOTR) {
        self.otrArchivedRef = self.lastEventTime.transportString;
        self.otrArchived = YES;
    }
    return [self eventIfNeededByUser:fromUser type:ZMTUpdateEventConversationMemberUpdate data:(id<ZMTransportData>)self.selfInfoDictionary];
}

- (MockEvent *)remotelyDeleteFromUser:(MockUser *)fromUser includeOTR:(BOOL)shouldIncludeOTR;
{
    self.archived = self.lastEvent;
    return [self remotelyClearHistoryFromUser:fromUser includeOTR:shouldIncludeOTR];
}

- (MockEvent *)insertKnockFromUser:(MockUser *)fromUser nonce:(NSUUID *)nonce;
{
    return [self eventIfNeededByUser:fromUser type:ZMTUpdateEventConversationKnock data:@{@"nonce": nonce.transportString}];
}

- (MockEvent *)insertHotKnockFromUser:(MockUser *)fromUser nonce:(NSUUID *)nonce ref:(NSString *)eventID
{
    NSDictionary *payload;
    if (eventID) {
        payload = @{
                    @"nonce": nonce.transportString,
                    @"ref": eventID
                    };
    }
    else {
        payload = @{
                    @"nonce": nonce.transportString
                    };
    }
    
    return [self eventIfNeededByUser:fromUser type:ZMTUpdateEventConversationHotKnock data:payload];
}

- (void)insertImageEventsFromUser:(MockUser *)fromUser;
{
    NSUUID *correlationID = [NSUUID createUUID];
    NSUUID *nonce = [NSUUID createUUID];
    
    [self insertPreviewImageEventFromUser:fromUser correlationID:correlationID none:nonce];
    [self insertMediumImageEventFromUser:fromUser correlationID:correlationID none:nonce];
}

- (MockEvent *)insertTypingEventFromUser:(MockUser *)fromUser isTyping:(BOOL)isTyping
{
    NSDictionary *data = @{@"status": isTyping ? @"started" : @"stopped"};
    
    return [self eventIfNeededByUser:fromUser type:ZMTUpdateEventConversationTyping data:data];
}


- (void)insertPreviewImageEventFromUser:(MockUser *)fromUser correlationID:(NSUUID *)correlationID none:(NSUUID *)nonce
{
    NSData *previewImageData = [NSData dataWithContentsOfURL:[[NSBundle bundleForClass:self.class] URLForResource:@"tiny"withExtension:@"jpg"]];
    Require(previewImageData);
    Require(correlationID);
    Require(nonce);
    
    NSDictionary *previewInfo = @{
                                  @"correlation_id": correlationID.transportString,
                                  @"height": @29,
                                  @"width": @38,
                                  @"name": [NSNull null],
                                  @"nonce": nonce.transportString,
                                  @"original_height": @768,
                                  @"original_width": @1024,
                                  @"public": @NO,
                                  @"tag": @"preview",
                                  @"inline": @YES
                                  };
    
    
    [self insertAssetUploadEventForUser:fromUser data:previewImageData disposition:previewInfo dataTypeAsMIME:@"image/jpeg" assetID:[NSUUID createUUID].transportString];
}

- (void)insertMediumImageEventFromUser:(MockUser *)fromUser correlationID:(NSUUID *)correlationID none:(NSUUID *)nonce
{
    NSData *mediumImageData = [NSData dataWithContentsOfURL:[[NSBundle bundleForClass:self.class] URLForResource:@"medium"withExtension:@"jpg"]];
    Require(mediumImageData);
    Require(correlationID);
    Require(nonce);
    
    NSDictionary *mediumInfo = @{
                                 @"correlation_id": correlationID.transportString,
                                 @"height": @432,
                                 @"width": @543,
                                 @"name": [NSNull null],
                                 @"nonce": nonce.transportString,
                                 @"original_height": @768,
                                 @"original_width": @1024,
                                 @"public": @NO,
                                 @"tag": @"medium",
                                 };
    NSString *assetID = [NSUUID createUUID].transportString;
    
    MockAsset *asset = [MockAsset insertIntoManagedObjectContext:self.managedObjectContext];
    asset.identifier = assetID;
    asset.conversation = self.identifier;
    asset.data = mediumImageData;
    
    [self insertAssetUploadEventForUser:fromUser data:mediumImageData disposition:mediumInfo dataTypeAsMIME:@"image/jpeg" assetID:asset.identifier];
}

- (MockEvent *)addUsersByUser:(MockUser *)byUser addedUsers:(NSArray *)addedUsers;
{
    if (addedUsers.count < 1) {
        return nil;
    }
    for(MockUser *user in addedUsers) {
        [self.mutableActiveUsers addObject:user];
        [self.mutableInactiveUsers removeObject:user];
    }
    NSDictionary *data = @{
                       @"user_ids" : [addedUsers mapWithBlock:^NSString *(MockUser *obj) {
                           return [obj identifier];
                       }],
                       };
    return [self eventIfNeededByUser:byUser type:ZMTUpdateEventConversationMemberJoin data:data];
}

- (MockEvent *)connectRequestByUser:(MockUser *)byUser toUser:(MockUser *)user message:(NSString *)message
{
    NSDictionary *data = @{
                           @"email" : [NSNull null],
                           @"message" : message,
                           @"name" : user.name,
                           @"recipiend" : user.identifier
                           };
    return [self eventIfNeededByUser:byUser type:ZMTUpdateEventConversationConnectRequest data:data];
}

- (MockEvent *)removeUsersByUser:(MockUser *)byUser removedUser:(MockUser *)removedUser;
{
    [self.mutableInactiveUsers addObject:removedUser];
    [self.mutableActiveUsers removeObject:removedUser];
    [self.mutableCallParticipants removeObject:removedUser];
    
    NSDictionary *data = @{@"user_ids" : @[removedUser.identifier] };
    return [self eventIfNeededByUser:byUser type:ZMTUpdateEventConversationMemberLeave data:data];
}

-(MockEvent *)changeNameByUser:(MockUser *)user name:(NSString *)name
{
    [self setValue:name forKey:@"name"];
    return [self eventIfNeededByUser:user type:ZMTUpdateEventConversationRename data:@{@"name" : name}];

}

- (MockEvent *)callEndedEventFromUser:(MockUser *)user selfUser:(MockUser *)selfUser
{
    self.isVideoCall = NO;
    BOOL isOtherUser = [self.mutableActiveUsers containsObject:user];
    BOOL selfWasJoined = [self.callParticipants containsObject:selfUser];

    [self.mutableUsersIgnoringCall removeAllObjects];
    [self.mutableCallParticipants removeAllObjects];
    
    BOOL missed = isOtherUser && !selfWasJoined;
    
    NSDictionary *data = @{
                           @"reason" : missed ? @"missed" : @"completed"
                           };
    return [self eventIfNeededByUser:user type:ZMTUpdateEventConversationVoiceChannelDeactivate data:data];
}

- (void)addUserToCall:(MockUser *)user
{
    [self.mutableCallParticipants addObject:user];
    if (self.callParticipants.count == 1) {
        (void)[self eventIfNeededByUser:user type:ZMTUpdateEventConversationVoiceChannelActivate data:nil];
    }
}

- (void)ignoreCallByUser:(MockUser *)user
{
    user.ignoredCallConversation = self;
}

- (void)addUserToVideoCall:(MockUser *)user;
{
    if (self.callParticipants.count == 0) {
        user.isSendingVideo = YES;
    }
    self.isVideoCall = YES;
    [self addUserToCall:user];
}

- (void)removeUserFromCall:(MockUser *)user
{
    NSDictionary *data = [self userLeavedCallEventData];
    [self.mutableCallParticipants removeObject:user];
    if (self.callParticipants.count == 1) {
        [self.mutableCallParticipants removeAllObjects];
        [self.mutableUsersIgnoringCall removeAllObjects];
        [self eventIfNeededByUser:user type:ZMTUpdateEventConversationVoiceChannelDeactivate data:data];
    }
    if (self.callParticipants.count <= 1) {
        self.isVideoCall = NO;
    }
}

- (NSDictionary *)userLeavedCallEventData
{
    NSDictionary *data = @{};
    
    if (self.type == ZMTConversationTypeOneOnOne) {
        data = @{@"reason": (self.callParticipants.count == 1) ? @"missed" : @"completed"};
    }
    else if (self.type == ZMTConversationTypeGroup) {
        if (self.callParticipants.count == 2)  {
            data = @{@"reason": @"completed"};
        }
        //TODO: Sabine group calls missed state
    }
    return data;
}


- (void)dropCall;
{
    self.callWasDropped = YES;
    NSDictionary *data = @{
                           @"reason" : @"lost"
                           };
    [self eventIfNeededByUser:self.mutableActiveUsers.firstObject type:ZMTUpdateEventConversationVoiceChannelDeactivate data:data];
}

- (MockEvent *)insertAssetUploadEventForUser:(MockUser *)user data:(NSData *)data disposition:(NSDictionary *)disposition dataTypeAsMIME:(NSString *)dataTypeAsMIME assetID:(NSString *)assetID
{
    BOOL const inlineData = [disposition[@"inline"] boolValue];
    NSDictionary *payload = @{
                           @"content_length" : @(data.length),
                           @"content_type" : dataTypeAsMIME,
                           @"data" : inlineData ? [data base64EncodedStringWithOptions:0] : [NSNull null],
                           @"id" : assetID,
                           @"info" : @{
                                   @"correlation_id" : disposition[@"correlation_id"],
                                   @"height" : disposition[@"height"],
                                   @"name" : [NSNull null],
                                   @"nonce" : disposition[@"nonce"],
                                   @"original_height" : disposition[@"original_height"],
                                   @"original_width" : disposition[@"original_width"],
                                   @"public" : disposition[@"public"],
                                   @"tag" : disposition[@"tag"],
                                   @"width" : disposition[@"width"]
                                   }
                           };
    
    return [self eventIfNeededByUser:user type:ZMTUpdateEventConversationAssetAdd data:payload];
}

@end
