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
@import WireSystem;

#import "MockEvent.h"
#import "MockConversation.h"
#import <WireMockTransport/WireMockTransport-Swift.h>

static ZMLogLevel_t const ZMLogLevel ZM_UNUSED = ZMLogLevelWarn;

@implementation MockEvent

@dynamic from;
@dynamic identifier;
@dynamic time;
@dynamic type;
@dynamic data;
@dynamic conversation;
@dynamic decryptedOTRData;

+ (NSArray *)eventStringToEnumValueTuples
{
    static NSArray *mapping;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mapping =
        @[
          @[@(ZMTUpdateEventConversationAssetAdd),@"conversation.asset-add"],
          @[@(ZMTUpdateEventConversationConnectRequest),@"conversation.connect-request"],
          @[@(ZMTUpdateEventConversationCreate),@"conversation.create"],
          @[@(ZMTUpdateEventConversationKnock),@"conversation.knock"],
          @[@(ZMTUpdateEventConversationMemberJoin),@"conversation.member-join"],
          @[@(ZMTUpdateEventConversationMemberLeave),@"conversation.member-leave"],
          @[@(ZMTUpdateEventConversationMemberUpdate),@"conversation.member-update"],
          @[@(ZMTUpdateEventConversationMessageAdd),@"conversation.message-add"],
          @[@(ZMTUpdateEventConversationClientMessageAdd),@"conversation.client-message-add"],
          @[@(ZMTUpdateEventConversationOTRMessageAdd),@"conversation.otr-message-add"],
          @[@(ZMTUpdateEventConversationOTRAssetAdd),@"conversation.otr-asset-add"],
          @[@(ZMTUpdateEventConversationRename),@"conversation.rename"],
          @[@(ZMTUpdateEventConversationTyping),@"conversation.typing"],
          @[@(ZMTUpdateEventUserConnection),@"user.connection"],
          @[@(ZMTUpdateEventUserNew),@"user.new"],
          @[@(ZMTUpdateEventUserPushRemove),@"user.push-remove"],
          @[@(ZMTUpdateEventUserUpdate),@"user.update"],
          @[@(ZMTUPdateEventUserClientAdd),@"user.client-add"],
          @[@(ZMTUpdateEventUserClientRemove),@"user.client-remove"],
          @[@(ZMTUpdateEventTeamCreate),@"team.create"],
          @[@(ZMTUpdateEventTeamUpdate),@"team.update"],
          @[@(ZMTUpdateEventTeamDelete),@"team.delete"],
          @[@(ZMTUpdateEventTeamMemberJoin),@"team.member-join"],
          @[@(ZMTUpdateEventTeamMemberLeave),@"team.member-leave"],
          @[@(ZMTUpdateEventTeamConversationCreate),@"team.conversation-create"],
          @[@(ZMTUpdateEventTeamConversationDelete),@"team.conversation-delete"]
          ];
    });
    return mapping;
}

+ (NSString *)stringFromType:(ZMTUpdateEventType)type
{
    for(NSArray *tuple in [MockEvent eventStringToEnumValueTuples]) {
        if([tuple[0] isEqualToNumber:@(type)]) {
            return tuple[1];
        }
    }
    RequireString(false, "Failed to parse ZMTUpdateEventType %lu", (unsigned long)type);
}

+ (ZMTUpdateEventType)typeFromString:(NSString *)string
{
    for(NSArray *tuple in [MockEvent eventStringToEnumValueTuples]) {
        if([tuple[1] isEqualToString:string]) {
            return (ZMTUpdateEventType) ((NSNumber *)tuple[0]).intValue;
        }
    }
    RequireString(false, "Failed to parse ZMTConnectionStatus %s", string.UTF8String);
}

+ (NSArray *)persistentEvents;
{
   return @[@(ZMTUpdateEventConversationRename),
            @(ZMTUpdateEventConversationMemberJoin),
            @(ZMTUpdateEventConversationMemberLeave),
            @(ZMTUpdateEventConversationConnectRequest),
            @(ZMTUpdateEventConversationMessageAdd),
            @(ZMTUpdateEventConversationClientMessageAdd),
            @(ZMTUpdateEventConversationAssetAdd),
            @(ZMTUpdateEventConversationKnock),
            @(ZMTUpdateEventConversationOTRMessageAdd),
            @(ZMTUpdateEventConversationOTRAssetAdd)
            ];
}


- (id<ZMTransportData>)transportData;
{
    return @{@"conversation": self.conversation.identifier ?: [NSNull null],
             @"data": self.data ?: [NSNull null],
             @"from": self.from ? self.from.identifier : [NSNull null],
             @"id": self.identifier ?: [NSNull null],
             @"time": self.time.transportString ?: [NSNull null],
             @"type": self.type ?: [NSNull null],
            };
}

- (ZMTUpdateEventType)eventType
{
    return [[self class] typeFromString:self.type];
}

@end
