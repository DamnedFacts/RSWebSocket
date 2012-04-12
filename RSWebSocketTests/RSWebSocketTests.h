//
//  RSWebSocketTests.h
//  RSWebSocketTests
//
//  Created by Richard Sarkis on 1/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <SenTestingKit/SenTestingKit.h>
#import "RSWebSocket.h"




@interface RSWebSocketTests : SenTestCase <RSWebSocketDelegate> {
@package
    RSWebSocket* ws;
    NSString* response;
}

@property (nonatomic, readonly) RSWebSocket* ws;
@property (nonatomic, readonly) NSString* response;

+ (void)addTestsForAutobahn:(SenTestSuite *)testSuite;
- (void) waitForSeconds: (NSTimeInterval) aSeconds;
@end




