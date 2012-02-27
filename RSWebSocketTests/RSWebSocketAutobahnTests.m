//
//  RSWebSocketAutobahnTests.m
//  RSWebSocket
//
//  Created by Richard Sarkis on 2/24/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RSWebSocketAutobahnTests.h"
#import "RSWebSocketTests.h"

BOOL flag = YES;

@implementation RSWebSocketAutobahnTests
@synthesize testSuiteIndex;

- (void) didClose:(NSUInteger) aStatusCode message:(NSString*) aMessage error:(NSError*) aError {
    [super didClose:aStatusCode message:aMessage error:aError];
    
    //[self.ws close:0 message:nil];
    
    if (aStatusCode != 1000 && aStatusCode != 1005)
        STFail(@"Autobahn test case number %ld failed with exit status %ld", testSuiteIndex, aStatusCode);

    flag = NO;
    
    [self waitForSeconds:0.3]; 
    // FIXME: Race condition that I can't trace down (see test case 49 without this timeout).
    // A timeout is expiring, and the connection is closing before reads from our peer are finished, I think.
}

- (void) didReceiveTextMessage: (NSString*) aMessage {
    [super didReceiveTextMessage:aMessage];
    
    switch (test_states) {
        case WSTestStateGetCounts:
            NSLog(@"There are %@ Autobahn test cases", aMessage);
            testCasesCount = [aMessage intValue];
            break;
        case WSTestStateRunAutobahnTestCases:
            if (aMessage){
                response = [aMessage copy];
            }
            [self.ws sendText:self.response];
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


- (id)initWithInvocation:(NSInvocation *)testInvocation 
               testIndex: (NSUInteger) index {
    self = [super initWithInvocation:testInvocation];
    if (self) [self setTestSuiteIndex:index];
    return self;
}

+ (id)defaultTestSuite {
    return [SenTestCase defaultTestSuite];
}

- (void) waitOnClose {
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    
    while (flag && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);
    
    flag = YES;
}

- (void) generalCaseTest {
    test_states = WSTestStateRunAutobahnTestCases;
    
    if (testSuiteIndex == 0) return;
        
    NSLog(@"Calling Autobahn WebSocket test case %ld", testSuiteIndex);
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
    
    return testCasesCount;
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
}



@end

