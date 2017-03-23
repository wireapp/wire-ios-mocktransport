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


@import CoreGraphics;
@import MobileCoreServices;
@import ZMCSystem;

static char* const ZMLogTag ZM_UNUSED = "MockTransportTests";

#import "MockEvent.h"

#import "MockTransportSessionTests.h"
#import <libkern/OSAtomic.h>

@interface TestPushChannelEvent()

@property (nonatomic) id<ZMTransportData> payload;
@property (nonatomic) NSUUID *uuid;
@property (nonatomic) BOOL isTransient;
@property (nonatomic) ZMTUpdateEventType type;

@end

@implementation TestPushChannelEvent

- (instancetype)initWithUUID:(NSUUID *)uuid payload:(NSDictionary *)payload transient:(BOOL)transient
{
    self = [super init];
    if(self) {
        self.uuid = uuid;
        self.payload = payload;
        self.isTransient = transient;
        self.type = [MockEvent typeFromString:payload[@"type"]];
        
        if(self.type == ZMTUpdateEventUnknown) {
            ZMLogError(@"Unknown event type in event: %@", payload);
            return nil;
        }
    }
    return self;
}

- (ZMTUpdateEventType)type
{
    return [MockEvent typeFromString:[[self.payload asDictionary] stringForKey:@"type"]];
}

+ (NSArray *)eventsArrayFromPushChannelData:(id<ZMTransportData>)transportData
{
    NSDictionary *dictionary = [transportData asDictionary];
    
    NSUUID *uuid = [[dictionary stringForKey:@"id"] UUID];
    NSArray *payloadArray = [dictionary arrayForKey:@"payload"];
    BOOL transient = [dictionary optionalNumberForKey:@"transient"].boolValue;
    
    if(payloadArray == nil) {
        ZMLogError(@"Push event payload is invalid: %@", dictionary);
        return nil;
    }
    
    if(uuid == nil) {
        ZMLogError(@"Push event id missing");
        return nil;
    }
    
    return [self eventsArrayWithUUID:uuid payloadArray:payloadArray transient:transient];
}

+ (NSArray *)eventsArrayWithUUID:(NSUUID *)uuid payloadArray:(NSArray *)payloadArray transient:(BOOL)transient
{
    if (payloadArray == nil) {
        ZMLogError(@"Push event payload is invalid");
        return @[];
    }
    
    NSMutableArray *events = [NSMutableArray array];
    for(NSDictionary *payload in [payloadArray asDictionaries]) {
        TestPushChannelEvent *event = [[self alloc] initWithUUID:uuid payload:payload transient:transient];
        if (event != nil) {
            [events addObject:event];
        }
    }
    
    return events;
}


@end


@implementation MockTransportSessionTests

-(void)pushChannelDidOpen:(ZMPushChannelConnection * __unused)channel withResponse:(NSHTTPURLResponse *__unused)response;
{
    ++self.pushChannelDidOpenCount;
}

-(void)pushChannelDidClose:(ZMPushChannelConnection *__unused)channel withResponse:(NSHTTPURLResponse *__unused)response;
{
    ++self.pushChannelDidCloseCount;
}

-(void)pushChannel:(ZMPushChannelConnection *__unused)channel didReceiveTransportData:(id<ZMTransportData>)data
{
    [self.pushChannelReceivedEvents addObjectsFromArray:[TestPushChannelEvent eventsArrayFromPushChannelData:data]];
}

- (void)setUp
{
    [super setUp];
    self.pushChannelReceivedEvents = [NSMutableArray array];
    self.cookieStorage = [OCMockObject niceMockForClass:[ZMPersistentCookieStorage class]];
    self.sut = [[MockTransportSession alloc] initWithDispatchGroup:self.dispatchGroup];
    self.sut.cookieStorage = self.cookieStorage;
}

- (void)tearDown
{
    self.sut = nil;
    self.pushChannelDidOpenCount = 0;
    self.pushChannelDidCloseCount = 0;
    [super tearDown];
}

- (void)testThatACreatedUserHasValidatedEmail
{
    [self.sut performRemoteChanges:^(id<MockTransportSessionObjectCreation> session) {
        // WHEN
        MockUser *user = [session insertUserWithName:@"Mario"];
        
        // THEN
        XCTAssertTrue(user.isEmailValidated);
    }];
    WaitForAllGroupsToBeEmpty(0.5);
}

@end



@implementation MockTransportSessionTests (Utility)

-(void)createAndOpenPushChannel
{
    [self createAndOpenPushChannelAndCreateSelfUser:YES];
}


- (void)createAndOpenPushChannelAndCreateSelfUser:(BOOL)shouldCreateSelfUser
{
    __block NSDictionary *payload;
    [self.sut performRemoteChanges:^(id<MockTransportSessionObjectCreation> session) {
        MockUser *selfUser;
        if (shouldCreateSelfUser) {
            selfUser = [session insertSelfUserWithName:@"Me Myself"];
        }
        else {
            selfUser = self.sut.selfUser;
        }
        
        RequireString(selfUser != nil, "We need a selfUser for this");
        
        selfUser.email = @"me@example.com";
        selfUser.password = @"123456";
        
        payload = @{@"email" : selfUser.email, @"password" : selfUser.password};
    }];
    WaitForAllGroupsToBeEmpty(0.5);
    
    [self responseForPayload:payload path:@"/login" method:ZMMethodPOST]; // this will simulate the user logging in
    [self.sut.mockedTransportSession configurePushChannelWithConsumer:self groupQueue:self.fakeSyncContext];
    [self.sut.mockedTransportSession.pushChannel setKeepOpen:YES];
    [self.sut performRemoteChanges:^(id<MockTransportSessionObjectCreation> session) {
        [session simulatePushChannelOpened];
    }];
    WaitForAllGroupsToBeEmpty(0.5);
}

- (TestPushChannelEvent *)popEvent
{
    TestPushChannelEvent *event = self.pushChannelReceivedEvents.firstObject;
    [self.pushChannelReceivedEvents removeObjectAtIndex:0];
    return event;
}

- (TestPushChannelEvent *)popEventMatchingWithBlock:(BOOL(^)(TestPushChannelEvent *event))block;
{
    NSUInteger idx = [self.pushChannelReceivedEvents indexOfObjectPassingTest:^BOOL(TestPushChannelEvent *event, NSUInteger idx2, BOOL *stop) {
        NOT_USED(stop);
        NOT_USED(idx2);
        return block(event);
    }];
    if (idx == NSNotFound) {
        return nil;
    }
    TestPushChannelEvent *result = [self.pushChannelReceivedEvents objectAtIndex:idx];
    [self.pushChannelReceivedEvents removeObjectAtIndex:idx];
    return result;
}

- (void)checkThatStringArray:(NSArray *)firstArray hasSameElemetsAs:(NSArray *)secondArray
{
    NSArray *sortedFirst = [firstArray sortedArrayUsingComparator:^NSComparisonResult(NSString* s1, NSString* s2) {
        return [s1 compare:s2];
    }];
    NSArray *sortedSecond = [secondArray sortedArrayUsingComparator:^NSComparisonResult(NSString* s1, NSString* s2) {
        return [s1 compare:s2];
    }];
    XCTAssertEqualObjects(sortedFirst, sortedSecond);
}


- (ZMTransportResponse *)responseForImageData:(NSData *)imageData contentDisposition:(NSDictionary *)contentDisposition path:(NSString *)path;
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Got an image response"];
    
    __block ZMTransportResponse *response;
    ZMTransportRequestGenerator postGenerator = ^ZMTransportRequest*(void) {
        ZMTransportRequest *request;
        if ([path containsString:@"conversations"]) {
            request = [ZMTransportRequest multipartRequestWithPath:path imageData:imageData metaData:contentDisposition];
        }
        else {
            request = [ZMTransportRequest postRequestWithPath:path imageData:imageData contentDisposition:contentDisposition];
        }
        
        [request addCompletionHandler:[ZMCompletionHandler handlerOnGroupQueue:self.fakeSyncContext block:^(ZMTransportResponse *r) {
            response = r;
            [expectation fulfill];
        }]];
        return request;
    };
    
    ZMTransportEnqueueResult *postResult = [self.sut.mockedTransportSession attemptToEnqueueSyncRequestWithGenerator:postGenerator];
    XCTAssertTrue(postResult.didHaveLessRequestThanMax);
    XCTAssertTrue(postResult.didGenerateNonNullRequest);
    XCTAssertTrue([self waitForCustomExpectationsWithTimeout:0.5]);
    return response;
}

- (ZMTransportResponse *)responseForFileData:(NSData *)fileData path:(NSString *)path metadata:(NSData *)metadata contentType:(NSString *)contentType;
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Got a file upload response"];
    __block ZMTransportResponse *response;
    
    ZMTransportRequestGenerator generator = ^ZMTransportRequest *{
        if (![path containsString:@"conversations"]) {
            return nil;
        }
        
        NSError *error;
        NSFileManager *fm = NSFileManager.defaultManager;
        NSURL *directory = [fm URLForDirectory:NSCachesDirectory
                                      inDomain:NSUserDomainMask
                             appropriateForURL:nil
                                        create:YES
                                         error:&error];
        XCTAssertNil(error);
        NSDictionary *headers = @{@"Content-MD5": [fileData.zmMD5Digest base64EncodedStringWithOptions:0]};
        NSArray <ZMMultipartBodyItem *> *items =
        @[
          [[ZMMultipartBodyItem alloc] initWithData:metadata contentType:@"application/x-protobuf" headers:nil],
          [[ZMMultipartBodyItem alloc] initWithData:fileData contentType:@"application/octet-stream" headers:headers]
          ];
        
        NSURL *fileURL = [directory URLByAppendingPathComponent:NSUUID.createUUID.transportString].filePathURL;
        NSData *multipartData = [NSData multipartDataWithItems:items boundary:@"frontier"];
        XCTAssertTrue([multipartData writeToFile:fileURL.path atomically:YES]);
        ZMTransportRequest *request = [ZMTransportRequest uploadRequestWithFileURL:fileURL path:path contentType:contentType];
        [request addCompletionHandler:[ZMCompletionHandler handlerOnGroupQueue:self.fakeSyncContext block:^(ZMTransportResponse *r) {
            response = r;
            [expectation fulfill];
        }]];
        
        return request;
    };
    
    ZMTransportEnqueueResult *postResult = [self.sut.mockedTransportSession attemptToEnqueueSyncRequestWithGenerator:generator];
    XCTAssertTrue(postResult.didHaveLessRequestThanMax);
    XCTAssertTrue(postResult.didGenerateNonNullRequest);
    XCTAssertTrue([self waitForCustomExpectationsWithTimeout:0.5]);
    return response;
}

- (ZMTransportResponse *)responseForImageData:(NSData *)imageData metaData:(NSData *)metaData imageMediaType:(NSString *)imageMediaType path:(NSString *)path;
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Got an image response"];
    
    __block ZMTransportResponse *response;
    ZMTransportRequestGenerator postGenerator = ^ZMTransportRequest*(void) {
        ZMTransportRequest *request = [ZMTransportRequest multipartRequestWithPath:path imageData:imageData metaData:metaData metaDataContentType:@"application/x-protobuf" mediaContentType:imageMediaType];
        
        [request addCompletionHandler:[ZMCompletionHandler handlerOnGroupQueue:self.fakeSyncContext block:^(ZMTransportResponse *r) {
            response = r;
            [expectation fulfill];
        }]];
        return request;
    };
    
    ZMTransportEnqueueResult *postResult = [self.sut.mockedTransportSession attemptToEnqueueSyncRequestWithGenerator:postGenerator];
    XCTAssertTrue(postResult.didHaveLessRequestThanMax);
    XCTAssertTrue(postResult.didGenerateNonNullRequest);
    XCTAssertTrue([self waitForCustomExpectationsWithTimeout:0.5]);
    return response;
}

- (ZMTransportResponse *)responseForPayload:(id<ZMTransportData>)payload path:(NSString *)path method:(ZMTransportRequestMethod)method
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Got a response"];
    
    ZMTransportSession *mockedTransportSession = self.sut.mockedTransportSession;
    
    __block ZMTransportResponse *response;
    
    ZMCompletionHandler *handler = [ZMCompletionHandler handlerOnGroupQueue:self.fakeSyncContext block:^(ZMTransportResponse *backgroundResponse) {
        response = backgroundResponse;
        [expectation fulfill];
    }];
    
    ZMTransportRequestGenerator generator = [self createGeneratorForPayload:payload path:path method:method handler:handler];
    
    ZMTransportEnqueueResult* result = [mockedTransportSession attemptToEnqueueSyncRequestWithGenerator:generator];
    
    XCTAssertTrue(result.didHaveLessRequestThanMax);
    XCTAssertTrue(result.didGenerateNonNullRequest);
    XCTAssertTrue([self waitForCustomExpectationsWithTimeout:0.5]);
    return response;
}

- (ZMTransportResponse *)responseForProtobufData:(NSData *)data path:(NSString *)path method:(ZMTransportRequestMethod)method
{
    XCTestExpectation *expectation = [self expectationWithDescription:@"Got a response"];
    
    ZMTransportSession *mockedTransportSession = self.sut.mockedTransportSession;
    
    __block ZMTransportResponse *response;
    
    ZMCompletionHandler *handler = [ZMCompletionHandler handlerOnGroupQueue:self.fakeSyncContext block:^(ZMTransportResponse *backgroundResponse) {
        response = backgroundResponse;
        [expectation fulfill];
    }];
    
    ZMTransportRequestGenerator generator = [self createGeneratorForProtobufData:data path:path method:method handler:handler];
    
    ZMTransportEnqueueResult* result = [mockedTransportSession attemptToEnqueueSyncRequestWithGenerator:generator];
    
    XCTAssertTrue(result.didHaveLessRequestThanMax);
    XCTAssertTrue(result.didGenerateNonNullRequest);
    XCTAssertTrue([self waitForCustomExpectationsWithTimeout:0.5]);
    return response;
}

- (ZMTransportRequestGenerator)createGeneratorForPayload:(id<ZMTransportData>)payload path:(NSString *)path method:(ZMTransportRequestMethod)method handler:(ZMCompletionHandler *)handler
{
    switch (method) {
        case ZMMethodGET:
        case ZMMethodDELETE:
        case ZMMethodHEAD:
            payload = nil;
            break;
        default:
            break;
    }
    
    ZMTransportRequestGenerator generator = ^ZMTransportRequest*(void) {
        ZMTransportRequest *request = [ZMTransportRequest requestWithPath:path method:method payload:payload];
        [request addCompletionHandler:handler];
        return request;
    };
    return generator;
}

- (ZMTransportRequestGenerator)createGeneratorForProtobufData:(NSData *)data path:(NSString *)path method:(ZMTransportRequestMethod)method handler:(ZMCompletionHandler *)handler
{
    ZMTransportRequestGenerator generator = ^ZMTransportRequest*(void) {
        ZMTransportRequest *request = [[ZMTransportRequest alloc] initWithPath:path method:method binaryData:data type:@"application/x-protobuf" contentDisposition:nil];
        [request addCompletionHandler:handler];
        return request;
    };
    return generator;
}

- (void)checkThatTransportData:(id <ZMTransportData>)data matchesUser:(MockUser *)user isConnected:(BOOL)isConnected failureRecorder:(ZMTFailureRecorder *)fr;
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:(id) data];
    FHAssertTrue(fr, [dict isKindOfClass:[NSDictionary class]]);
    NSArray *keys = @[@"accent_id", @"id", @"name", @"picture", @"handle"];
    if(isConnected) {
        keys = [keys arrayByAddingObjectsFromArray:@[@"email", @"phone"]];
    }
    
    AssertDictionaryHasKeys(dict, keys);
    
    [user.managedObjectContext performBlockAndWait:^{
        
        if(isConnected) {
            FHAssertEqualObjects(fr, dict[@"email"], user.email);
            FHAssertEqual(fr, dict[@"phone"], user.phone);
        }
        
        FHAssertEqualObjects(fr, dict[@"name"], user.name);
        FHAssertEqualObjects(fr, dict[@"id"], user.identifier);
        FHAssertEqualObjects(fr, dict[@"accent_id"], @(user.accentID));
        FHAssertEqualObjects(fr, dict[@"handle"], user.handle);
    
        NSArray *pictures = dict[@"picture"];
        FHAssertEqual(fr, pictures.count, user.pictures.count);
        [pictures enumerateObjectsUsingBlock:^(NSDictionary *pictureData, NSUInteger idx, BOOL *stop) {
            NOT_USED(stop);
            MockPicture *picture = user.pictures[idx];
            [self checkThatTransportDictionary:pictureData matchesPicture:picture];
        }];
    }];
}

- (void)checkThatTransportDictionary:(NSDictionary *)dict matchesPicture:(MockPicture *)picture;
{
    [picture.managedObjectContext performBlockAndWait:^{
        XCTAssertEqualObjects(dict[@"content_length"], @(picture.contentLength));
        XCTAssertEqualObjects(dict[@"content_type"], picture.contentType);
        XCTAssertEqualObjects(dict[@"id"], picture.identifier);
        XCTAssertEqualObjects(dict[@"data"], @"");
        XCTAssertEqualObjects(dict[@"info"], picture.info);
    }];
}

- (void)checkThatTransportData:(id <ZMTransportData>)data matchesConnection:(MockConnection *)connection;
{
    [connection.managedObjectContext performBlockAndWait:^{
        NSDictionary *dict = (id) data;
        XCTAssertTrue([dict isKindOfClass:[NSDictionary class]]);
        NSArray *keys = @[@"conversation", @"from", @"to", @"last_update", @"message", @"status"];
        AssertDictionaryHasKeys(dict, keys);
        
        XCTAssertEqualObjects(dict[@"status"], @"accepted");
        XCTAssertEqualObjects(dict[@"conversation"], connection.conversation ?: [NSNull null]);
        XCTAssertEqualObjects(dict[@"to"], connection.to.identifier);
        XCTAssertEqualObjects(dict[@"from"], connection.from.identifier);
        XCTAssertEqualObjects(dict[@"last_update"], [connection.lastUpdate transportString]);
        XCTAssertEqualObjects(dict[@"message"], connection.message ?: [NSNull null]);
    }];
}

- (void)checkThatTransportData:(id <ZMTransportData>)data matchesConversation:(MockConversation *)conversation;
{
    [conversation.managedObjectContext performBlockAndWait:^{
        NSDictionary *dict = (id) data;
        XCTAssertTrue([dict isKindOfClass:[NSDictionary class]]);
        NSArray *keys = @[@"creator", @"id", @"last_event", @"last_event_time", @"members", @"name", @"type"];
        AssertDictionaryHasKeys(dict, keys);
        
        XCTAssertEqualObjects(dict[@"creator"], conversation.creator ? conversation.creator.identifier: [NSNull null]);
        
        NSDictionary *members = dict[@"members"];
        XCTAssertTrue([members isKindOfClass:[NSDictionary class]]);
        keys = @[@"others", @"self"];
        AssertDictionaryHasKeys(members, keys);
        
        NSDictionary *selfMember = members[@"self"];
        XCTAssertTrue([selfMember isKindOfClass:[NSDictionary class]]);
        keys = @[@"archived", @"id", @"muted", @"muted_time", @"status", @"last_read", @"cleared", @"otr_muted", @"otr_muted_ref", @"otr_archived", @"otr_archived_ref"];
        AssertDictionaryHasKeys(selfMember, keys);
        
        XCTAssertEqualObjects(selfMember[@"status"], @(conversation.status));
        XCTAssertEqualObjects(selfMember[@"status_time"], [conversation.statusTime transportString]);
        XCTAssertEqualObjects(selfMember[@"status_ref"], conversation.statusRef);
        XCTAssertEqualObjects(selfMember[@"last_read"], [NSNull null]);
        XCTAssertEqualObjects(selfMember[@"muted_time"], conversation.mutedTime ? [conversation.mutedTime transportString] : [NSNull null]);
        XCTAssertEqualObjects(selfMember[@"muted"], @(conversation.muted));
        XCTAssertEqualObjects(selfMember[@"otr_muted"], @(conversation.otrMuted));
        XCTAssertEqualObjects(selfMember[@"otr_muted_ref"], conversation.otrMutedRef ?: [NSNull null]);
        XCTAssertEqualObjects(selfMember[@"otr_archived"], @(conversation.otrArchived));
        XCTAssertEqualObjects(selfMember[@"otr_archived_ref"], conversation.otrArchivedRef ?: [NSNull null]);
        
        XCTAssertEqualObjects(selfMember[@"archived"], [NSNull null]);
        XCTAssertEqualObjects(selfMember[@"id"], conversation.selfIdentifier);
        XCTAssertEqualObjects(selfMember[@"cleared"], conversation.clearedEventID ? conversation.clearedEventID : [NSNull null]);

        NSMutableSet *activeOtherIDs = [NSMutableSet set];
        for (MockUser *user in conversation.activeUsers) {
            [activeOtherIDs addObject:user.identifier];
        }
        
        NSMutableSet *inactiveOtherIDs = [NSMutableSet set];
        for (MockUser *user in conversation.activeUsers) {
            [inactiveOtherIDs addObject:user.identifier];
        }
        
        NSArray *others = members[@"others"];
        
        XCTAssertTrue([others isKindOfClass:[NSArray class]]);
        XCTAssertEqual(conversation.activeUsers.count + conversation.inactiveUsers.count, 1 + others.count);
        for (NSDictionary *otherDict in others) {
            XCTAssertTrue([otherDict isKindOfClass:[NSDictionary class]]);
            keys = @[@"id", @"status"];
            AssertDictionaryHasKeys(otherDict, keys);
            
            NSNumber *status = otherDict[@"status"];
            NSString *uuidString = otherDict[@"id"];
            if([status intValue] == 0) {
                XCTAssertTrue([activeOtherIDs containsObject:uuidString], @"id %@ not found", uuidString);
            }
            else if([status intValue] == 1) {
                XCTAssertTrue([inactiveOtherIDs containsObject:uuidString], @"id %@ not found", uuidString);
            }
            
        }
        
        XCTAssertEqualObjects(dict[@"name"], conversation.name ?: [NSNull null]);
        XCTAssertEqualObjects(dict[@"id"], conversation.identifier ?: [NSNull null]);
        XCTAssertNotNil(dict[@"type"]);
        ZMTConversationType t = (ZMTConversationType) ((NSNumber *)dict[@"type"]).intValue;
        XCTAssertEqual(t, conversation.type);
        XCTAssertEqualObjects(dict[@"last_event_time"], [conversation.lastEventTime transportString]);
        XCTAssertEqualObjects(dict[@"last_event"], conversation.lastEvent ?: [NSNull null]);
    }];
}

@end



