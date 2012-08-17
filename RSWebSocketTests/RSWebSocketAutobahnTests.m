//
//  RSWebSocketAutobahnTests.m
//  RSWebSocketTests
//
//  Copyright 2012 Richard Emile Sarkis
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

#import "RSWebSocketAutobahnTests.h"
#import "RSWebSocketTests.h"

#import "DebugSupport.h"

BOOL flag = YES;

@implementation RSWebSocketAutobahnTests
@synthesize testSuiteIndex;
- (void) didOpen {
    [super didOpen];
}

- (void) didClose:(NSError *) closingStatusError 
        localCode:(NSUInteger) closingStatusLocalCode  
     localMessage:(NSString *) closingStatusLocalMessage
       remoteCode:(NSUInteger) closingStatusRemoteCode
    remoteMessage:(NSString *) closingStatusRemoteMessage {
    
    [super didClose:(NSError *) closingStatusError 
          localCode:(NSUInteger) closingStatusLocalCode  
       localMessage:(NSString *) closingStatusLocalMessage
         remoteCode:(NSUInteger) closingStatusRemoteCode
      remoteMessage:(NSString *) closingStatusRemoteMessage];

    switch (test_states) {
        case WSTestStateGetCounts:
        {
        }
            break;
        case WSTestStateRunAutobahnTestCases:
        {
            cStatusError = closingStatusError;
            cStatusLocalCode = closingStatusLocalCode;
            cStatusLocalMessage = closingStatusLocalMessage;
            cStatusRemoteCode = closingStatusRemoteCode;
            cStatusRemoteMessage = closingStatusRemoteMessage;
        }
            break;
        case WSTestStateGetAutobahnTestCaseExp:
        {
            STAssertNotNil(testCaseExpResults, @"Failed retrieving Autobahn test case expectations for case %ld", testSuiteIndex);
            NSMutableArray *closeCodes = [testCaseExpResults objectForKey:@"closeCode"];
            NSNumber *localCode = [NSNumber numberWithUnsignedLong:cStatusLocalCode];
            
            [closeCodes addObject:[NSNumber numberWithInt:WebSocketCloseStatusNormalButMissingStatus]]; // This is an ok state.
            
            if ([closeCodes indexOfObject:localCode] != NSNotFound) break;
            STFail(@"Autobahn test case %@ (%@) failed. Expected local close code(s): %@ but issued code %ld", 
                   [testCaseExpResults objectForKey:@"caseId"], 
                   [testCaseExpResults objectForKey:@"caseIndex"],
                   closeCodes,
                   [localCode intValue]);
        }
            break;
        case WSTestStateClosing:
        {
        }
            break;
    }
        
    flag = NO;
}


- (void) didReceiveTextMessage: (NSString*) aMessage {
    [super didReceiveTextMessage:aMessage];
    
    switch (test_states) {
        case WSTestStateGetCounts:
        {
            testSuiteTotal = [aMessage intValue];
            NSAssert(testSuiteTotal > 0,@"Autobahn test cases count is zero, aborting.");
            NSLog(@"There are %ld Autobahn test cases", testSuiteTotal);
        }   
            break;
        case WSTestStateRunAutobahnTestCases:
        {
            if (aMessage){
                response = [aMessage copy];
            }
            [self.ws sendText:self.response];
        }
            break;
        case WSTestStateGetAutobahnTestCaseExp:
        {
            NSLog(@"%@", aMessage);
            NSError *e = nil;
            testCaseExpResults = [NSJSONSerialization 
                                  JSONObjectWithData: [aMessage dataUsingEncoding:NSUTF8StringEncoding] 
                                  options: NSJSONReadingMutableContainers 
                                  error: &e];
            
            if (!testCaseExpResults) {
                NSLog(@"Error parsing JSON: %@", e);
            }
        }
            break;
        case WSTestStateClosing:
        {
        }
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

- (void) generalCaseTest {
    //    if (testSuiteIndex == 252) DebugBreak()
//       if (testSuiteIndex != 205) return;
//           if (testSuiteIndex != 71) return;

//          if (testSuiteIndex < 70 || testSuiteIndex > 77) return;
    //        if (testSuiteIndex != 206) return;
    //    if (testSuiteIndex > 240) return;
    
    test_states = WSTestStateRunAutobahnTestCases;
    if (testSuiteIndex == 0) return;
        
    NSString *testurl = [@"ws://localhost:9001/runCase?case=" stringByAppendingFormat:@"%ld&agent='RSWebSocket'",testSuiteIndex];
    RSWebSocketConnectConfig* config = [RSWebSocketConnectConfig configWithURLString:testurl 
                                                                              origin:nil
                                                                           protocols:nil
                                                                         tlsSettings:nil 
                                                                             headers:nil 
                                                                   verifySecurityKey:YES 
                                                                          extensions:nil ];
    ws = [RSWebSocket webSocketWithConfig:config delegate:self];
    [self.ws open];
    [self waitOnClose];

    NSLog(@"Getting Autobahn WebSocket expected result for test case %ld", testSuiteIndex);
    test_states = WSTestStateGetAutobahnTestCaseExp;
    config = [RSWebSocketConnectConfig configWithURLString:@"ws://localhost:9001/getLastCaseExpectation?agent='RSWebSocket" 
                                                                              origin:nil
                                                                           protocols:nil
                                                                         tlsSettings:nil 
                                                                             headers:nil 
                                                                   verifySecurityKey:YES 
                                                                          extensions:nil ];
    ws = [RSWebSocket webSocketWithConfig:config delegate:self];
    [self.ws open];
    [self waitOnClose];
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
    ws = [RSWebSocket webSocketWithConfig:config delegate:self];
    [self.ws open];
    [self waitOnClose];

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
    ws = [RSWebSocket webSocketWithConfig:config delegate:self];
    [self.ws open];
    [self waitOnClose];
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

