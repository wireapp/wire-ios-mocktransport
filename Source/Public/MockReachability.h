//
//  MockReachability.h
//  WireMockTransport-ios
//
//  Created by Nicola Giancecchi on 13.02.18.
//  Copyright © 2018 Zeta Project. All rights reserved.
//

#import <Foundation/Foundation.h>
@import WireTransport;

@interface MockReachability : NSObject<ReachabilityProvider, ReachabilityTearDown>  

@end


