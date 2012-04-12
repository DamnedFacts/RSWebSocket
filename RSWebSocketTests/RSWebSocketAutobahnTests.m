//
//  RSWebSocketAutobahnTests.m
//  RSWebSocket
//
//  Created by Richard Sarkis on 2/24/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RSWebSocketAutobahnTests.h"
#import "RSWebSocketTests.h"

#import "DebugSupport.h"

BOOL flag = YES;

@implementation RSWebSocketAutobahnTests
@synthesize testSuiteIndex;
- (void) didOpen {
    [super didOpen];
}

- (void) didClose:(ClosingStatusCodes)closingStatus { 
    [super didClose:closingStatus];

    switch (test_states) {
        case WSTestStateGetCounts:
            break;
        case WSTestStateRunAutobahnTestCases:
            testCaseRetResults = closingStatus;
            break;
        case WSTestStateGetAutobahnTestCaseExp:
            STAssertNotNil(testCaseExpResults, @"Failed retrieving Autobahn test case expectations for case %ld", testSuiteIndex);
            NSMutableArray *closeCodes = [testCaseExpResults objectForKey:@"closeCode"];
            NSNumber *localCode = [NSNumber numberWithInt:testCaseRetResults.localCode];
            
            [closeCodes addObject:[NSNumber numberWithInt:WebSocketCloseStatusNormalButMissingStatus]]; // This is an ok state.

//            NSNumber *remoteCode = [NSNumber numberWithInt:testCaseRetResults.remoteCode];
//            NSNumber *closedDirection = [testCaseExpResults objectForKey:@"closedByMe"];
            
            // "closedByMe" is from the WebSocket server's perspective.
//            if ([closedDirection boolValue]) { // Closed on remote side
//                if ([closeCodes indexOfObject:remoteCode] != NSNotFound) break;
//                STFail(@"Autobahn test case %@ (%@) failed remotely. Expect close code(s): %@ but received code %ld", 
//                       [testCaseExpResults objectForKey:@"caseId"], 
//                       [testCaseExpResults objectForKey:@"caseIndex"],
//                       closeCodes,
//                       [remoteCode intValue]);
//            } else {
                if ([closeCodes indexOfObject:localCode] != NSNotFound) break;
                STFail(@"Autobahn test case %@ (%@) failed. Expected local close code(s): %@ but issued code %ld", 
                        [testCaseExpResults objectForKey:@"caseId"], 
                        [testCaseExpResults objectForKey:@"caseIndex"],
                        closeCodes,
                        [localCode intValue]);
//            }
            break;
        case WSTestStateClosing:
                break;
    }
        
    flag = NO;
}


- (void) didReceiveTextMessage: (NSString*) aMessage {
    [super didReceiveTextMessage:aMessage];
    
    switch (test_states) {
        case WSTestStateGetCounts:
            testSuiteTotal = [aMessage intValue];
            NSAssert(testSuiteTotal > 0,@"Autobahn test cases count is zero, aborting.");
            NSLog(@"There are %ld Autobahn test cases", testSuiteTotal);
            break;
        case WSTestStateRunAutobahnTestCases:
            if (aMessage){
                response = [aMessage copy];
            }
            [self.ws sendText:self.response];
            break;
        case WSTestStateGetAutobahnTestCaseExp:
            NSLog(@"%@", aMessage);
            NSError *e = nil;
            testCaseExpResults = [[NSJSONSerialization 
                                  JSONObjectWithData: [aMessage dataUsingEncoding:NSUTF8StringEncoding] 
                                  options: NSJSONReadingMutableContainers 
                                  error: &e] retain];
            
            if (!testCaseExpResults) {
                NSLog(@"Error parsing JSON: %@", e);
            }
//            } else {
//                for (id item in testCaseExpResults) {
//                    NSLog(@"Item: %@ of class %@", [testCaseExpResults objectForKey:item], 
//                          [[testCaseExpResults objectForKey:item] class]);
//                }
//            }
            break;
        case WSTestStateClosing:
            break;
    }
}

- (void) didReceiveBinaryMessage: (NSData*) aMessage {
    [super didReceiveBinaryMessage:aMessage];
    [self.ws sendBinary: aMessage];
}

- (void)setUp {
    [super setUp];
    return;
}

- (void)tearDown {
    [super tearDown];
    return;
}



- (void) waitOnClose {
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    while (flag && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);    
    flag = YES;
}

//-(NSString *) description {
//    return [NSString stringWithFormat:@"Autobahn WebSocket test case %ld", testSuiteIndex];
//}

- (void) generalCaseTest {
//    if (testSuiteIndex == 252) DebugBreak()
//    if (testSuiteIndex != 62) return;
//      if (testSuiteIndex < 45 || testSuiteIndex > 64) return;
//        if (testSuiteIndex != 206) return;
//    if (testSuiteIndex > 240) return;

    test_states = WSTestStateRunAutobahnTestCases;
    if (testSuiteIndex == 0) return;
        
    NSString *testurl = [@"ws://localhost:9001/runCase?case=" stringByAppendingFormat:@"%d&agent='RSWebSocket'",testSuiteIndex];
    RSWebSocketConnectConfig* config = [RSWebSocketConnectConfig configWithURLString:testurl 
                                                                              origin:nil
                                                                           protocols:nil
                                                                         tlsSettings:nil 
                                                                             headers:nil 
                                                                   verifySecurityKey:YES 
                                                                          extensions:nil ];
    ws = [[RSWebSocket webSocketWithConfig:config delegate:self] retain];
    [self.ws open];
    [self waitOnClose];
//    [ws release];


    // FIXME: Race condition that I can't trace down (see test case 49 without this timeout).
    // A timeout is expiring, and the connection is closing before reads from our peer are finished, I think.

    
    NSLog(@"Getting Autobahn WebSocket expected result for test case %ld", testSuiteIndex);
    test_states = WSTestStateGetAutobahnTestCaseExp;
    config = [RSWebSocketConnectConfig configWithURLString:@"ws://localhost:9001/getLastCaseExpectation?agent='RSWebSocket" 
                                                                              origin:nil
                                                                           protocols:nil
                                                                         tlsSettings:nil 
                                                                             headers:nil 
                                                                   verifySecurityKey:YES 
                                                                          extensions:nil ];
    ws = [[RSWebSocket webSocketWithConfig:config delegate:self] retain];
    [self.ws open];
    [self waitOnClose];
//    [ws release];
}

- (NSUInteger) getCaseCount {
    test_states = WSTestStateGetCounts;
    RSWebSocketConnectConfig* config = [RSWebSocketConnectConfig configWithURLString:@"ws://localhost:9001/getCaseCount" 
                                                                              origin:nil
                                                                           protocols:nil
                                                                         tlsSettings:nil 
                                                                             headers:nil 
                                                                   verifySecurityKey:YES 
                                                                          extensions:nil ];
    ws = [[RSWebSocket webSocketWithConfig:config delegate:self] retain];
    [ws open];
    [self waitOnClose];
//    [ws release];

    return testSuiteTotal;
}

- (void) testUpdateReport {
    
    // We're adding this after we've added our Autobahn test units. The assumption is the order of execution
    // is based on order of when the unit tests were added to the suite. So, this should run after all the
    // Autobahn test cases have run.
    NSLog(@"Updating reports");
    RSWebSocketConnectConfig* config = [RSWebSocketConnectConfig configWithURLString:@"ws://localhost:9001/updateReports?agent='RSWebSocket'" 
                                                                              origin:nil 
                                                                           protocols:nil
                                                                         tlsSettings:nil 
                                                                             headers:nil 
                                                                   verifySecurityKey:YES 
                                                                          extensions:nil ];
    ws = [[RSWebSocket webSocketWithConfig:config delegate:self] retain];
    [self.ws open];
    [self waitOnClose];
//    [ws release];
}

#pragma mark Initialization methods
- (id)initWithInvocation:(NSInvocation *)testInvocation testIndex: (NSUInteger) index {
    self = [super initWithInvocation:testInvocation];
    if (self) [self setTestSuiteIndex:index];
    return self;
}

+ (id)defaultTestSuite {
    return [SenTestCase defaultTestSuite];
}
@end

