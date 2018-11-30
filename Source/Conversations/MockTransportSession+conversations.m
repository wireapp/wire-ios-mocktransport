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

#import "MockTransportSession+conversations.h"
#import <WireMockTransport/WireMockTransport-Swift.h>
#import "MockTransportSession+assets.h"
#import "MockTransportSession+OTR.h"



static char* const ZMLogTag ZM_UNUSED = "MockTransport";

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
    else if ([request matchesWithPath:@"/conversations/*/typing" method:ZMMethodPOST])
    {
        return [self processConversationTyping:[request RESTComponentAtIndex:1] payload:[request.payload asDictionary]];
    }
    else if ([request matchesWithPath:@"/conversations/*/assets/*" method:ZMMethodGET])
    {
        return [self processAssetRequest:request];
    }
    else if ([request matchesWithPath:@"/conversations/*/otr/assets/*" method:ZMMethodGET])
    {
        return [self processAssetRequest:request];
    }
    else if ([request matchesWithPath:@"/conversations/*/bots" method:ZMMethodPOST]) {
        return [self processServiceRequest:request];
    }
    else if ([request matchesWithPath:@"/conversations/*/bots/*" method:ZMMethodDELETE]) {
        return [self processDeleteBotRequest:request];
    }
    else if ([request matchesWithPath:@"/conversations/*/access" method:ZMMethodPUT]) {
        return [self processAccessModeUpdateForConversation:[request RESTComponentAtIndex:1] payload:[request.payload asDictionary]];
    }
    else if ([request matchesWithPath:@"/conversations/*/code" method:ZMMethodGET]) {
        return [self processFetchLinkForConversation:[request RESTComponentAtIndex:1] payload:[request.payload asDictionary]];
    }
    else if ([request matchesWithPath:@"/conversations/*/code" method:ZMMethodPOST]) {
        return [self processCreateLinkForConversation:[request RESTComponentAtIndex:1] payload:[request.payload asDictionary]];
    }
    else if ([request matchesWithPath:@"/conversations/*/code" method:ZMMethodDELETE]) {
        return [self processDeleteLinkForConversation:[request RESTComponentAtIndex:1] payload:[request.payload asDictionary]];
    }
    else if ([request matchesWithPath:@"/conversations/*/receipt-mode" method:ZMMethodPUT]) {
        return [self processReceiptModeUpdateForConversation:[request RESTComponentAtIndex:1] payload:[request.payload asDictionary]];
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
    if (newName == nil) {
        return [ZMTransportResponse responseWithPayload:@{@"error":@"no name in payload"} HTTPStatus:400 transportSessionError:nil];
    }
    
    NSNumber *receiptMode = [payload optionalNumberForKey:@"receipt_mode"];
    
    if (receiptMode != nil) {
        [conversation changeReceiptModeByUser:self.selfUser receiptMode:receiptMode.intValue];
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

- (BOOL)updateConversation:(MockConversation *)conversation isOTRMutedStatusFromPutSelfConversationPayload:(NSDictionary *)payload
{
    NSNumber *mutedStatus = [payload optionalNumberForKey:@"otr_muted_status"];
    conversation.otrMutedStatus = mutedStatus;
    return mutedStatus != nil;
}

- (ZMTransportResponse *)processPutConversationSelf:(NSString *)conversationId payload:(NSDictionary *)payload;
{
    MockConversation *conversation = [self conversationByIdentifier:conversationId];
    if (conversation == nil) {
        return [ZMTransportResponse responseWithPayload:nil HTTPStatus:404 transportSessionError:nil];
    }
    
    BOOL hadOTRMuted = [self updateConversation:conversation isOTRMutedFromPutSelfConversationPayload:payload];
    BOOL hadOTRArchived = [self updateConversation:conversation isOTRArchivedFromPutSelfConversationPayload:payload];
    BOOL hadOTRMutedStatus = [self updateConversation:conversation isOTRMutedStatusFromPutSelfConversationPayload:payload];

    if( !hadOTRArchived && !hadOTRMuted && !hadOTRMutedStatus) {
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
    NSArray *participantIDs = request.payload.asDictionary[@"users"];
    NSString *name = request.payload.asDictionary[@"name"];
    
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

@end
