//
//  RSWebSocketTests.m
//  RSWebSocketTests
//
//  Created by Richard Sarkis on 1/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RSWebSocketTests.h"

//@implementation RSWebSocketTests
//
//- (void)setUp
//{
//    [super setUp];
//    
//    // Set-up code here.
//}
//
//- (void)tearDown
//{
//    // Tear-down code here.
//    
//    [super tearDown];
//}
//
//- (void)testExample
//{
//    STFail(@"Unit tests are not implemented yet in RSWebSocketTests");
//}
//
//@end


//
//  UnittWebSocketClient10Tests.m
//  UnittWebSocketClient
//
//  Created by Josh Morris on 6/19/11.
//  Copyright 2011 UnitT Software. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not
//  use this file except in compliance with the License. You may obtain a copy of
//  the License at
// 
//  http://www.apache.org/licenses/LICENSE-2.0
// 
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
//  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
//  License for the specific language governing permissions and limitations under
//  the License.
//

#import "RSWebSocketTests.h"
#import "RSWebSocketFragment.h"


@implementation RSWebSocketTests

@synthesize ws;
@synthesize response;

#pragma mark WebSocketDelegate
- (void) didOpen {
    NSLog(@"Did open connection");
}

- (void) didClose:(NSUInteger) aStatusCode message:(NSString*) aMessage error:(NSError*) aError {
    [self.ws close:0 message:nil];
    NSLog(@"Status Code: %lu", aStatusCode);
    NSLog(@"Close Message: %@", aMessage);
    NSLog(@"Error: errorDesc=%@, failureReason=%@", [aError localizedDescription], [aError localizedFailureReason]);
}

- (void) didReceiveError: (NSError*) aError {
    NSLog(@"Error: errorDesc=%@, failureReason=%@", [aError localizedDescription], [aError localizedFailureReason]);
}

- (void) didReceiveTextMessage: (NSString*) aMessage {
    //NSLog(@"Did receive text message:%@",aMessage);
    NSLog(@"Did receive text message");

    if (aMessage){
        response = [aMessage copy];
    }
    [self.ws sendText:self.response];
}

- (void) didReceiveBinaryMessage: (NSData*) aMessage {
    //NSLog(@"Did receive binary message:%@", aMessage);
    [self.ws sendBinary: aMessage];
}


#pragma mark Test
- (void)setUp {
    [super setUp];
}

- (void)tearDown {        
    RSWebSocketConnectConfig* config = [RSWebSocketConnectConfig configWithURLString:@"ws://localhost:9001/updateReports?agent='RSWebSocket'" 
                                                                          origin:nil 
                                                                       protocols:nil
                                                                     tlsSettings:nil 
                                                                         headers:nil 
                                                               verifySecurityKey:YES 
                                                                      extensions:nil ];
    ws = [[RSWebSocket webSocketWithConfig:config delegate:self] retain];
    [self.ws open];
    [self waitForSeconds:3.0];
    // Connection is closed automatically by peer.
    //[self.ws close:0 message:nil];
    [ws release];
    [response release];
    [super tearDown];
}

- (void) waitForSeconds: (NSTimeInterval) aSeconds
{
    NSDate *secondsFromNow = [NSDate dateWithTimeIntervalSinceNow:aSeconds];
    [[NSRunLoop currentRunLoop] runUntilDate:secondsFromNow];
}

- (void)dealloc {
    [response release];
    [ws release];
    [super dealloc];
}

- (void) testCases {
    int i;
    NSString *testurl;
    for (i = 1; i<=50; i++) {
        NSLog(@"Calling Autobahn WebSocket test case %d", i);
        
        testurl = [@"ws://localhost:9001/runCase?case=" stringByAppendingFormat:@"%d&agent='RSWebSocket'",i];
        
        RSWebSocketConnectConfig* config = [RSWebSocketConnectConfig configWithURLString:testurl 
                                                                              origin:nil
                                                                           protocols:nil
                                                                         tlsSettings:nil 
                                                                             headers:nil 
                                                                   verifySecurityKey:YES 
                                                                          extensions:nil ];
        ws = [[RSWebSocket webSocketWithConfig:config delegate:self] retain];
        [self.ws open];
        // FIXME: We should have some sort of event loop?
        [self waitForSeconds:2.0];
    }
}

@end
