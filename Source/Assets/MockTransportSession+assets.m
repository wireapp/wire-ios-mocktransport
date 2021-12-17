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
@import WireTesting;
@import WireProtos;
#import "MockTransportSession+assets.h"
#import "MockTransportSession+OTR.h"
#import "MockAsset.h"
#import <WireMockTransport/WireMockTransport-Swift.h>



@implementation MockTransportSession (Assets)

#pragma mark - Asset v2 downloading

- (ZMTransportResponse *)processAssetRequest:(ZMTransportRequest *)request;
{
    if([request matchesWithPath:@"/conversations/*/assets/*" method:ZMMethodGET]) {
        return [self processAssetGetRequestInConversation:[request RESTComponentAtIndex:1] asset:[request RESTComponentAtIndex:3]];
    }
    else if([request matchesWithPath:@"/assets/*" method:ZMMethodGET]) {
        return [self processAssetGetRequestInConversation:request.queryParameters[@"conv_id"] asset:[request RESTComponentAtIndex:1]];
    }
    else if ([request matchesWithPath:@"/conversations/*/otr/assets/*" method:ZMMethodGET]) {
        return [self processAssetGetRequestInConversation:[request RESTComponentAtIndex:1] asset:[request RESTComponentAtIndex:4]];
    }
    return [ZMTransportResponse responseWithPayload:nil HTTPStatus:404 transportSessionError:nil];
}

- (ZMTransportResponse *)sampleImageResponse {
    NSData *data =  [NSData dataWithContentsOfURL:[[NSBundle bundleForClass:self.class] URLForResource:@"medium"withExtension:@"jpg"]];
    return [[ZMTransportResponse alloc ] initWithImageData:data HTTPStatus:200 transportSessionError:nil headers:nil];
}

- (ZMTransportResponse *)processAssetGetRequestInConversation:(NSString *)conversationID asset:(NSString *)identifier
{
    MockAsset *asset = [MockAsset assetInContext:self.managedObjectContext forID:identifier];
    if([asset.conversation isEqualToString:conversationID]) {
        return [[ZMTransportResponse alloc ] initWithImageData:asset.data HTTPStatus:200 transportSessionError:nil headers:nil];
    }
    else {
        return [ZMTransportResponse responseWithPayload:@{@"error":@"mismatching conversation"} HTTPStatus:404 transportSessionError:nil];
    }
        
    return [ZMTransportResponse responseWithPayload:@{@"error":@"not found"} HTTPStatus:404 transportSessionError:nil];
}

#pragma mark - Asset v3

- (ZMTransportResponse *)processAssetV3Request:(ZMTransportRequest *)request
{
    if ([request matchesWithPath:@"/assets/v3/*" method:ZMMethodPOST]) {
        return [self processAssetV3PostWithMultipartData:[request multipartBodyItemsFromRequestOrFile] domain: [request RESTComponentAtIndex:2]];
    } else if ([request matchesWithPath:@"/assets/v3" method:ZMMethodPOST]) {
        return [self processAssetV3PostWithMultipartData:[request multipartBodyItemsFromRequestOrFile]];
    } else if ([request matchesWithPath:@"/assets/v3/*" method:ZMMethodGET]) {
        return [self processAssetV3GetWithKey:[request RESTComponentAtIndex:2]];
    } else if ([request matchesWithPath:@"/assets/v3/*" method:ZMMethodDELETE]) {
        return [self processAssetV3DeleteWithKey:[request RESTComponentAtIndex:2]];
    }
    return nil;
}

- (ZMTransportResponse *)processAssetV3PostWithMultipartData:(NSArray *)multipart;
{
    return [self processAssetV3PostWithMultipartData:multipart domain:nil];
}

- (ZMTransportResponse *)processAssetV3GetWithKey:(NSString *)key;
{
    MockAsset *asset = [MockAsset assetInContext:self.managedObjectContext forID:key];
    if (asset != nil) {
        
        return [[ZMTransportResponse alloc] initWithImageData:asset.data HTTPStatus:200 transportSessionError:nil headers:nil];
    }
    return [ZMTransportResponse responseWithPayload:nil HTTPStatus:404 transportSessionError:nil];
}

#pragma mark - Asset v4

- (ZMTransportResponse *)processAssetV4Request:(ZMTransportRequest *)request
{
    if ([request matchesWithPath:@"/assets/v4/*/*" method:ZMMethodGET]) {
        return [self processAssetV4GetWithDomain:[request RESTComponentAtIndex:2] key:[request RESTComponentAtIndex:3]];
    } else if ([request matchesWithPath:@"/assets/v4/*/*" method:ZMMethodDELETE]) {
        return [self processAssetV4DeleteWithDomain:[request RESTComponentAtIndex:2] key:[request RESTComponentAtIndex:3]];
    }
    return nil;
}

@end
