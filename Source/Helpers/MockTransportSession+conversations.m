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
@import CoreData;
@import WireProtos;
@import WireDataModel;

#import "MockTransportSession+internal.h"
#import "MockTransportSession.h"
#import <WireMockTransport/WireMockTransport-Swift.h>
#import "MockTransportSession+assets.h"
#import "MockTransportSession+OTR.h"
#import "MockFlowManager.h"
#import <WireMockTransport/WireMockTransport-Swift.h>



static char* const ZMLogTag ZM_UNUSED = "MockTransport";

static NSString * const JoinedString = @"joined";
static NSString * const IdleString = @"idle";

@implementation MockTransportSession (Conversations)

//TODO: filter requests using array of NSPredicates

// handles /conversations
- (ZMTransportResponse *)processConversationsRequest:(ZMTransportRequest *)request;
{
    if ([request matchesWithPath:@"/conversations" method:ZMMethodGET]) {
        return [self processConversationsGetConversationsIDs:request.queryParameters[@"ids"]];
    }
    else if ([request matchesWithPath:@"/conversations/ids" method:ZMMethodGET])
    {
        return [self processConversationIDsQuery:request.queryParameters];
    }
    else if ([request matchesWithPath:@"/conversations/*" method:ZMMethodGET])
    {
        return [self processConversationsGetConversation:[request RESTComponentAtIndex:1]];
    }
    else if ([request matchesWithPath:@"/conversations" method:ZMMethodPOST])
    {
        return [self processConversationsPostConversationsRequest:request];
    }
    else if ([request matchesWithPath:@"/conversations/*/otr/messages" method:ZMMethodPOST])
    {
        if (request.binaryData != nil) {
            return [self processAddOTRMessageToConversation:[request RESTComponentAtIndex:1]
                                          withProtobuffData:request.binaryData
                                                      query:request.queryParameters];
        }
        else {
            return [self processAddOTRMessageToConversation:[request RESTComponentAtIndex:1]
                                                    payload:[request.payload asDictionary]
                                                      query:request.queryParameters];
        }
    }
    else if ([request matchesWithPath:@"/conversations/*/members" method:ZMMethodPOST])
    {
        return [self processAddMembersToConversation:[request RESTComponentAtIndex:1] payload:[request.payload asDictionary]];
    }
    else if ([request matchesWithPath:@"/conversations/*" method:ZMMethodPUT])
    {
        return [self processPutConversation:[request RESTComponentAtIndex:1] payload:[request.payload asDictionary]];
    }
    else if ([request matchesWithPath:@"/conversations/*/self" method:ZMMethodPUT])
    {
        return [self processPutConversationSelf:[request RESTComponentAtIndex:1] payload:[request.payload asDictionary]];
    }
    else if ([request matchesWithPath:@"/conversations/*/members/*" method:ZMMethodDELETE])
    {
        return [self processDeleteConversation:[request RESTComponentAtIndex:1] member:[request RESTComponentAtIndex:3]];
    }
    else if ([request matchesWithPath:@"/conversations/*/call/state" method:ZMMethodPUT])
    {
        return [self processCallStateChange:[request RESTComponentAtIndex:1] payload:[request.payload asDictionary]];
    }
    else if ([request matchesWithPath:@"/conversations/*/call/state" method:ZMMethodGET])
    {
        return [self processConversationCallState:[request RESTComponentAtIndex:1]];
    }
    else if ([request matchesWithPath:@"/conversations/*/call" method:ZMMethodGET])
    {
        return [self processConversationCallRequest:[request RESTComponentAtIndex:1]];
    }
    else if ([request matchesWithPath:@"/conversations/*/typing" method:ZMMethodPOST])
    {
        return [self processConversationTyping:[request RESTComponentAtIndex:1] payload:[request.payload asDictionary]];
    }
    else if ([request matchesWithPath:@"/conversations/*/assets/*" method:ZMMethodGET])
    {
        return [self processAssetRequest:request];
    }
    else if ([request matchesWithPath:@"/conversations/*/otr/assets" method:ZMMethodPOST])
    {
        return [self processAssetRequest:request];
    }
    else if ([request matchesWithPath:@"/conversations/*/assets" method:ZMMethodPOST])
    {
        return [self processAssetRequest:request];
    }
    else if ([request matchesWithPath:@"/conversations/*/otr/assets/*" method:ZMMethodPOST])
    {
        return [self processAssetRequest:request];
    }
    else if ([request matchesWithPath:@"/conversations/*/otr/assets/*" method:ZMMethodGET])
    {
        return [self processAssetRequest:request];
    }

    return [ZMTransportResponse responseWithPayload:nil HTTPStatus:404 transportSessionError:nil];

}


// POST /conversations/<id>/otr/messages
- (ZMTransportResponse *)processAddOTRMessageToConversation:(NSString *)conversationId payload:(NSDictionary *)payload query:(NSDictionary *)query;
{
    NSAssert(self.selfUser != nil, @"No self user in mock transport session");
    
    MockConversation *conversation = [self fetchConversationWithIdentifier:conversationId];
    NSAssert(conversation, @"No conv found");

    NSDictionary *recipients = payload[@"recipients"];
    MockUserClient *senderClient = [self otrMessageSender:payload];
    if (senderClient == nil) {
        return [ZMTransportResponse responseWithPayload:nil HTTPStatus:404 transportSessionError:nil];
    }

    NSString *onlyForUser = query[@"report_missing"];
    NSDictionary *missedClients = [self missedClients:recipients conversation:conversation sender:senderClient onlyForUserId:onlyForUser];
    NSDictionary *redundantClients = [self redundantClients:recipients conversation:conversation];
    
    NSDictionary *responsePayload = @{@"missing": missedClients, @"redundant": redundantClients, @"time": [NSDate date].transportString};
    
    NSInteger statusCode = 412;
    if (missedClients.count == 0) {
        statusCode = 201;
        [self insertOTRMessageEventsToConversation:conversation requestPayload:payload createEventBlock:^MockEvent *(MockUserClient *recipient, NSData *messageData) {
            return [conversation insertOTRMessageFromClient:senderClient toClient:recipient data:messageData];
        }];
    }
    
    return [ZMTransportResponse responseWithPayload:responsePayload HTTPStatus:statusCode transportSessionError:nil];
}

- (ZMTransportResponse *)processAddOTRMessageToConversation:(NSString *)conversationID
                                          withProtobuffData:(NSData *)binaryData
                                                      query:(NSDictionary *)query;
{
    NSAssert(self.selfUser != nil, @"No self user in mock transport session");
    
    MockConversation *conversation = [self fetchConversationWithIdentifier:conversationID];
    if (conversation == nil) {
        return [ZMTransportResponse responseWithPayload:nil HTTPStatus:404 transportSessionError:nil];
    }
    
    ZMNewOtrMessage *otrMetaData = (ZMNewOtrMessage *)[[[ZMNewOtrMessage builder] mergeFromData:binaryData] build];
    if (otrMetaData == nil) {
        return [ZMTransportResponse responseWithPayload:nil HTTPStatus:404 transportSessionError:nil];
    }
    
    MockUserClient *senderClient = [self otrMessageSenderFromClientId:otrMetaData.sender];
    if (senderClient == nil) {
        return [ZMTransportResponse responseWithPayload:nil HTTPStatus:404 transportSessionError:nil];
    }
    
    NSString *onlyForUser = query[@"report_missing"];
    NSDictionary *missedClients = [self missedClientsFromRecipients:otrMetaData.recipients conversation:conversation sender:senderClient onlyForUserId:onlyForUser];
    NSDictionary *redundantClients = [self redundantClientsFromRecipients:otrMetaData.recipients conversation:conversation];
    
    NSDictionary *payload = @{@"missing": missedClients, @"redundant": redundantClients, @"time": [NSDate date].transportString};
    
    NSInteger statusCode = 412;
    if (missedClients.count == 0) {
        statusCode = 201;
        [self insertOTRMessageEventsToConversation:conversation
                                 requestRecipients:otrMetaData.recipients
                                      senderClient:senderClient
                                  createEventBlock:^MockEvent *(MockUserClient *recipient, NSData *messageData, NSData *decryptedData) {
                                      MockEvent* event = [conversation insertOTRMessageFromClient:senderClient toClient:recipient data:messageData];
                                      event.decryptedOTRData = decryptedData;
                                      return event;
        }];
    }
    
    return [ZMTransportResponse responseWithPayload:payload HTTPStatus:statusCode transportSessionError:nil];
}

- (ZMTransportResponse *)processPutConversation:(NSString *)conversationId payload:(NSDictionary *)payload;
{
    MockConversation *conversation = [self conversationByIdentifier:conversationId];
    if (conversation == nil) {
        return [ZMTransportResponse responseWithPayload:nil HTTPStatus:404 transportSessionError:nil];
    }
    
    NSString *newName = [payload optionalStringForKey:@"name"];
    
    if(newName == nil) {
        return [ZMTransportResponse responseWithPayload:@{@"error":@"no name in payload"} HTTPStatus:400 transportSessionError:nil];
    }
    
    MockEvent *event = [conversation changeNameByUser:self.selfUser name:newName];
    return [ZMTransportResponse responseWithPayload:event.transportData HTTPStatus:200 transportSessionError:nil];
}


// returns YES if the payload contains "muted" information
- (BOOL)updateConversation:(MockConversation *)conversation isOTRMutedFromPutSelfConversationPayload:(NSDictionary *)payload
{
    NSString *mutedRef = [payload optionalStringForKey:@"otr_muted_ref"];
    if (mutedRef != nil) {
        NSNumber *muted = [payload optionalNumberForKey:@"otr_muted"];
        conversation.otrMuted = ([muted isEqual:@1]);
        conversation.otrMutedRef = mutedRef;
    }
    
    return mutedRef != nil;
}

// returns YES if the payload contains "muted" information
- (BOOL)updateConversation:(MockConversation *)conversation isOTRArchivedFromPutSelfConversationPayload:(NSDictionary *)payload
{
    NSString *archivedRef = [payload optionalStringForKey:@"otr_archived_ref"];
    if (archivedRef != nil) {
        NSNumber *archived = [payload optionalNumberForKey:@"otr_archived"];
        conversation.otrArchived = ([archived isEqual:@1]);
        conversation.otrArchivedRef = archivedRef;
    }
    
    return archivedRef != nil;
}

- (ZMTransportResponse *)processPutConversationSelf:(NSString *)conversationId payload:(NSDictionary *)payload;
{
    MockConversation *conversation = [self conversationByIdentifier:conversationId];
    if (conversation == nil) {
        return [ZMTransportResponse responseWithPayload:nil HTTPStatus:404 transportSessionError:nil];
    }
    
    BOOL hadOTRMuted = [self updateConversation:conversation isOTRMutedFromPutSelfConversationPayload:payload];
    BOOL hadOTRArchived = [self updateConversation:conversation isOTRArchivedFromPutSelfConversationPayload:payload];

    if( !hadOTRArchived && !hadOTRMuted) {
        return [ZMTransportResponse responseWithPayload:@{@"error":@"no useful payload"} HTTPStatus:400 transportSessionError:nil];
    }
    
    return [ZMTransportResponse responseWithPayload:nil HTTPStatus:200 transportSessionError:nil];
}

- (ZMTransportResponse *)processConversationsGetConversationsIDs:(NSString *)ids;
{
    NSFetchRequest *request = [MockConversation sortedFetchRequest];
    NSArray *conversations = [self.managedObjectContext executeFetchRequestOrAssert:request];
    NSMutableArray *data = [NSMutableArray array];
    
    if (ids != nil) {
        
        NSSet *requestedIDs = [NSSet setWithArray:[ids componentsSeparatedByString:@","]];
        
        for (MockConversation *conversation in conversations) {
            if([requestedIDs containsObject:conversation.identifier]) {
                [data addObject:conversation.transportData];
            }
        }
    }
    else {
        for (MockConversation *conversation in conversations) {
            [data addObject:conversation.transportData];
        }
    }
    
    return [ZMTransportResponse responseWithPayload:@{@"conversations":data} HTTPStatus:200 transportSessionError:nil];

}

- (ZMTransportResponse *)processConversationsGetConversation:(NSString *)conversationId;
{
    MockConversation *conversation = [self conversationByIdentifier:conversationId];
    if (conversation == nil) {
        return [ZMTransportResponse responseWithPayload:nil HTTPStatus:404 transportSessionError:nil];
    }
    
    return [ZMTransportResponse responseWithPayload:conversation.transportData HTTPStatus:200 transportSessionError:nil];
}

- (ZMTransportResponse *)processConversationsPostConversationsRequest:(ZMTransportRequest *)request;
{
    NSArray *participantIDs = request.payload[@"users"];
    NSString *name = request.payload[@"name"];
    
    NSMutableArray *otherUsers = [NSMutableArray array];
    
    for (NSString *id in participantIDs) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", id];
        NSFetchRequest *fetchRequest = [MockUser sortedFetchRequestWithPredicate:predicate];
        
        NSArray *results = [self.managedObjectContext executeFetchRequestOrAssert:fetchRequest];
        
        if (results.count == 1) {
            MockUser *user = results[0];
            [otherUsers addObject:user];
        }
    }
    
    MockConversation *conversation = [self insertGroupConversationWithSelfUser:self.selfUser otherUsers:otherUsers];
    if(name != nil) {
        [conversation changeNameByUser:self.selfUser name:name];
    }
    return [ZMTransportResponse responseWithPayload:[conversation transportData] HTTPStatus:200 transportSessionError:nil];
}


- (ZMTransportResponse *)processDeleteConversation:(NSString *)conversationId member:(NSString *)memberId;
{
    MockConversation *conversation = [self fetchConversationWithIdentifier:conversationId];
    if (conversation == nil) {
        return [ZMTransportResponse responseWithPayload:nil HTTPStatus:404 transportSessionError:nil];
    }
    
    MockUser *user = [self fetchUserWithIdentifier:memberId];
    MockEvent *event = [conversation removeUsersByUser:self.selfUser removedUser:user];
    
    return [ZMTransportResponse responseWithPayload:event.transportData HTTPStatus:200 transportSessionError:nil];
}


- (ZMTransportResponse *)processAddMembersToConversation:(NSString *)conversationId payload:(NSDictionary *)payload;
{
    MockConversation *conversation = [self fetchConversationWithIdentifier:conversationId];
    
    NSArray *addedUserIDs = payload[@"users"];
    NSMutableArray *addedUsers = [NSMutableArray array];
    MockUser *selfUser = self.selfUser;
    NSAssert(selfUser != nil, @"Self not found");
    
    for (NSString *userID in addedUserIDs) {
        MockUser *user = [self fetchUserWithIdentifier:userID];
        if(user == nil) {
            return [ZMTransportResponse responseWithPayload:@{
                                                              @"code" : @403,
                                                              @"message": @"Unknown user",
                                                              @"label": @""
                                                              } HTTPStatus:403 transportSessionError:nil];
        }
        
        MockConnection *connection = [self fetchConnectionFrom:selfUser to:user];
        if (connection == nil) {
            return [ZMTransportResponse responseWithPayload:@{
                                                              @"code" : @403,
                                                              @"message": @"Requestor is not connected to users invited",
                                                              @"label": @""
                                                              } HTTPStatus:403 transportSessionError:nil];
        }
        [addedUsers addObject:user];
    }
    
    
    MockEvent *event = [conversation addUsersByUser:self.selfUser addedUsers:addedUsers];
    return [ZMTransportResponse responseWithPayload:event.transportData HTTPStatus:200 transportSessionError:nil];
}

- (MockConversation *)conversationByIdentifier:(NSString *)identifier
{
    NSFetchRequest *request = [MockConversation sortedFetchRequestWithPredicate:[NSPredicate predicateWithFormat:@"identifier == %@", identifier]];
    
    NSArray *conversations = [self.managedObjectContext executeFetchRequestOrAssert:request];
    RequireString(conversations.count <= 1, "Too many conversations with one identifier");
    
    return conversations.count > 0 ? conversations[0] : nil;
}

- (ZMTransportResponse *)processCallStateChange:(NSString *)conversationId payload:(NSDictionary *)payload
{
    NSDictionary *selfState = payload[@"self"];
    NSString *incomingState = selfState[@"state"];
    
    MockConversation *conversation = [self conversationByIdentifier:conversationId];
    
    BOOL isJoining = [incomingState isEqualToString:JoinedString];
    BOOL isSendingVideo = [selfState[@"videod"] boolValue];
    if (isSendingVideo && isJoining) {
        conversation.isVideoCall = YES;
        self.selfUser.isSendingVideo = YES;
    } else {
        self.selfUser.isSendingVideo = NO;
    }
    BOOL isIgnoringCall = [selfState[@"ignored"] boolValue];
    if (isIgnoringCall) {
        self.selfUser.ignoredCallConversation = conversation;
    } else {
        self.selfUser.ignoredCallConversation = nil;
    }

    NSInteger statusCode;
    NSDictionary *payLoad;
    if(conversation == nil) {
        statusCode = 404;
    }
    else if(conversation.type != ZMTConversationTypeOneOnOne && conversation.type != ZMTConversationTypeGroup) {
        statusCode = 400;
    }
    else if ([incomingState isEqualToString:JoinedString] || [incomingState isEqualToString:IdleString]) {
        statusCode = 200;

        BOOL selfWasJoined = [conversation.callParticipants containsObject:self.selfUser];
        BOOL generateSuccessPayload = YES;
        
        if(!isJoining) {
            if (conversation.type == ZMTConversationTypeOneOnOne ) {
                if (selfWasJoined) {
                    [conversation callEndedEventFromUser:self.selfUser selfUser:self.selfUser];
                    [self.mockFlowManager resetVideoCalling];
                    conversation.isVideoCall = NO;
                }
            }
            else {
                [conversation removeUserFromCall:self.selfUser];
                if (conversation.callParticipants.count == 1) {
                    conversation.isVideoCall = NO;
                    [self.mockFlowManager resetVideoCalling];
                }
            }
        }

        if(isJoining) {
            if (conversation.type == ZMTConversationTypeGroup && conversation.callParticipants.count >= self.maxCallParticipants) {
                statusCode = 409;
                payLoad = @{@"label": @"voice-channel-full", @"max_joined": @(self.maxCallParticipants)};
                generateSuccessPayload = NO;
            }
            else if (conversation.type == ZMTConversationTypeGroup && conversation.activeUsers.count >= self.maxMembersForGroupCall) {
                statusCode = 409;
                payLoad = @{@"label": @"conv-too-big", @"max_members": @(self.maxMembersForGroupCall)};
                generateSuccessPayload = NO;
            }
            else {
                [conversation addUserToCall:self.selfUser];
            }
        }
        if (generateSuccessPayload) {
            payLoad = [self combinedCallStateForConversation:conversation];
        }
    }
    else {
        statusCode = 400;
    }
    
    
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payLoad HTTPStatus:statusCode transportSessionError:nil];
    return response;
}

- (ZMTransportResponse *)processConversationCallState:(NSString *)conversationId
{
    MockConversation *conversation = [self conversationByIdentifier:conversationId];
    
    NSInteger statusCode;
    NSDictionary *payload;
    if (conversation == nil) {
        statusCode = 404;
    }
    else if(conversation.type != ZMTConversationTypeOneOnOne && conversation.type != ZMTConversationTypeGroup) {
        statusCode = 400;
    }
    else {
        statusCode = 200;
        payload = [self combinedCallStateForConversation:conversation];
    }
    
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPStatus:statusCode transportSessionError:nil];
    return response;
}

- (ZMTransportResponse *)processConversationCallRequest:(NSString *)conversationId
{
    MockConversation *conversation = [self conversationByIdentifier:conversationId];
    
    NSInteger statusCode;
    NSDictionary *payload;
    if (conversation == nil) {
        statusCode = 404;
    }
    else if(conversation.type != ZMTConversationTypeOneOnOne && conversation.type != ZMTConversationTypeGroup) {
        statusCode = 400;
    }
    else if(conversation.type == ZMTConversationTypeGroup && conversation.activeUsers.count >= self.maxMembersForGroupCall) {
        statusCode = 409;
        payload = @{@"label": @"conv-too-big", @"max_members": @(self.maxMembersForGroupCall)};
    }
    else if(conversation.type == ZMTConversationTypeGroup && conversation.callParticipants.count >= self.maxCallParticipants) {
        statusCode = 409;
        payload = @{@"label": @"voice-channel-full", @"max_joined": @(self.maxCallParticipants)};
    }
    else {
        statusCode = 200;
        payload = [self combinedCallStateForConversation:conversation];
    }
    
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPStatus:statusCode transportSessionError:nil];
    return response;
}

- (NSDictionary *)combinedCallStateForConversation:(MockConversation *)conversation
{
    return @{
             @"participants": [self participantsPayloadForConversation:conversation],
             @"self": [self callStateForUser:self.selfUser conversation:conversation],
             };
}

// POST /conversations/<id>/typing
- (ZMTransportResponse *)processConversationTyping:(NSString *)conversationId payload:(NSDictionary *)payload
{
    MockConversation *conversation = [self conversationByIdentifier:conversationId];
    if (conversation == nil) {
        return [ZMTransportResponse responseWithPayload:nil HTTPStatus:404 transportSessionError:nil];
    }
    
    BOOL isTyping = [[payload optionalStringForKey:@"status"] isEqualToString:@"started"];
    MockEvent *event = [conversation insertTypingEventFromUser:self.selfUser isTyping:isTyping];
    NSDictionary *responsePayload = [event transportData].asDictionary;
    
    return [ZMTransportResponse responseWithPayload:responsePayload HTTPStatus:201 transportSessionError:nil];
}

// GET /conversations/ids
- (ZMTransportResponse *)processConversationIDsQuery:(NSDictionary *)query
{
    NSString *sizeString = [query optionalStringForKey:@"size"];
    NSUUID *start = [query optionalUuidForKey:@"start"];
    
    NSFetchRequest *request = [MockConversation sortedFetchRequest];
    NSArray *conversations = [self.managedObjectContext executeFetchRequestOrAssert:request];

    NSArray *conversationIDs = [conversations mapWithBlock:^id(MockConversation *obj) {
        return obj.identifier;
    }];
    
    if(start != nil) {
        NSUInteger index = [conversationIDs indexOfObject:start.transportString];
        if(index != NSNotFound) {
            conversationIDs = [conversationIDs subarrayWithRange:NSMakeRange(index+1, conversationIDs.count - index-1)];
        }
    }

    BOOL hasMore = NO;
    if(sizeString != nil) {
        NSUInteger remainingConversations = conversationIDs.count;
        NSUInteger pageSize = (NSUInteger) sizeString.integerValue;
        hasMore = (remainingConversations > pageSize);
        NSUInteger numOfConversations = MIN(remainingConversations, pageSize);
        conversationIDs = [conversationIDs subarrayWithRange:NSMakeRange(0u, numOfConversations)];
    }
    
    NSDictionary *payload = @{
                              @"has_more": @(hasMore),
                              @"conversations": conversationIDs
                              };
    
    ZMTransportResponse *response = [ZMTransportResponse responseWithPayload:payload HTTPStatus:200 transportSessionError:nil];
    return response;
}

- (NSDictionary *)participantsPayloadForConversation:(MockConversation *)conversation
{
    NSMutableDictionary *participantsPayload = [NSMutableDictionary dictionary];
    for(MockUser *user in conversation.activeUsers)
    {
        participantsPayload[user.identifier] = [self callStateForUser:user conversation:conversation];
    }
    
    RequireString(self.selfUser != nil, "No self-user in conversation");
//    RequireString(conversation.callParticipants.count > 0, "No other user in conversation");
    
    return participantsPayload;
}

- (NSDictionary *)callStateForUser:(MockUser*)user conversation:(MockConversation *)conversation
{
    BOOL isJoined = [conversation.callParticipants containsObject:user];
    
    NSString *stateString = isJoined ? JoinedString : IdleString;
    BOOL isSendingVideo = conversation.isVideoCall && user.isSendingVideo;
    NSMutableDictionary *state = [NSMutableDictionary dictionary];
    state[@"state"] = stateString;
    state[@"videod"] = isSendingVideo ? @YES : @NO;
    if (user.ignoredCallConversation != nil) {
        state[@"ignored"] = @YES;
    }
    
    return state;
}

@end
