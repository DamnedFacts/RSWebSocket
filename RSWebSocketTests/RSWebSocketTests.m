//
//  RSWebSocketTests.m
//  RSWebSocketTests
//
//  Created by Richard Sarkis on 1/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RSWebSocketTests.h"
#import <objc/objc-class.h>
#import "RSWebSocketFragment.h"

@implementation RSWebSocketAutobahnTests
@synthesize testSuiteIndex;

- (void) didClose:(NSUInteger) aStatusCode message:(NSString*) aMessage error:(NSError*) aError {
    [super didClose:aStatusCode message:aMessage error:aError];

    if (aStatusCode != 1000 && aStatusCode != 1005)
        STFail(@"Autobahn test case number %ld failed with exit status %ld", testSuiteIndex, aStatusCode);
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

- (void)setUp {
    return;
}

- (void)tearDown {
    return;
}

- (id)initWithInvocation:(NSInvocation *)testInvocation 
               testIndex: (NSUInteger) index {
    
    self = [super initWithInvocation:testInvocation];
    
    if (self) {
        [self setTestSuiteIndex:index];
    }
    
    return self;
}

+ (id)defaultTestSuite {
    return [SenTestCase defaultTestSuite];
}

- (void) generalCaseTest {
    test_states = WSTestStateRunAutobahnTestCases;
    
    if (testSuiteIndex <= 0) return;
    
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
    [self waitForSeconds:2];
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
    config.closeTimeout = 15.0;
    ws = [[RSWebSocket webSocketWithConfig:config delegate:self] retain];
    [ws open];
    [self waitForSeconds:0.5];    
    
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
    [self waitForSeconds:2.0];
    [self.ws close:0 message:nil];
}
@end




@implementation RSWebSocketTests
@synthesize ws;
@synthesize response;

#pragma mark WebSocketDelegate Methods
- (void) didOpen {
    NSLog(@"Did open connection");
}

- (void) didClose:(NSUInteger) aStatusCode message:(NSString*) aMessage error:(NSError*) aError {
    [self.ws close:0 message:nil];
    NSLog(@"Status Code: %lu    Close Message: %@   Error: errorDesc=%@, failureReason=%@", 
          aStatusCode, aMessage, [aError localizedDescription], [aError localizedFailureReason]);    
}

- (void) didReceiveError: (NSError*) aError {
    NSLog(@"Error: errorDesc=%@, failureReason=%@", [aError localizedDescription], [aError localizedFailureReason]);
}

- (void) didReceiveTextMessage: (NSString*) aMessage {
    NSLog(@"Did receive text message");
}

- (void) didReceiveBinaryMessage: (NSData*) aMessage {
    NSLog(@"Did receive binary message");
        [self.ws sendBinary: aMessage];
}


#pragma mark WebSocket Tests
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

#pragma mark Unit Test Required
// We override the SenTest framework's object method to insert our custom tests.
- (id)initWithInvocation:(NSInvocation *)testInvocation {
    return [super initWithInvocation:testInvocation];;
}

// We override the SenTest framework's class method to insert our custom tests.
+ (id)defaultTestSuite {    
    SenTestSuite *testSuite = [[SenTestSuite alloc] initWithName:NSStringFromClass(self)];
    
    /***************************/
    /* Add autobahn test cases */
    /***************************/
    // Grab a list of our static test methods, first before adding our dynamic ones.
    NSArray *testInvocations = [RSWebSocketAutobahnTests testInvocations];

    // Add dynamic Autobahn tests.
    RSWebSocketAutobahnTests *testUnitObj = [[RSWebSocketAutobahnTests alloc] retain];
    NSUInteger num_tests = [testUnitObj getCaseCount];
    [testUnitObj release];
    
    for (int i = 1; i<=num_tests; i++) {
        [self addTestsForAutobahn:i toTestSuite:testSuite];
    }

    // Add static Autobahn test cases
    for (NSInvocation *testInvocation in testInvocations) {
        SenTestCase *test = [[RSWebSocketAutobahnTests alloc] initWithInvocation:testInvocation];
        [testSuite addTest:test];
        [test release];
    }
    
    /***************************/
    /* Add internal test cases */
    /***************************/
    // This array of NSInvocation objects contains a single object that points to our single test method.
    //    NSArray *testInvocations = [self testInvocations];
    
    //    for (NSInvocation *testInvocation in testInvocations) {
    //    }
    
    
    return [testSuite autorelease];
}

+ (void)addTestsForAutobahn:(NSUInteger)indexValue 
                     toTestSuite:(SenTestSuite *)testSuite {
    

    RSWebSocketAutobahnTests *testUnitObj = [[RSWebSocketAutobahnTests alloc] retain];
        
    // Obj-C Runtime swizzling. We're taking the method "generalCaseTest" and renaming it and
    // parameterizing it with the index number of the Autobahn test case we want it to run.
    SEL test_case_n_sel = NSSelectorFromString([NSString stringWithFormat:@"testCase%ld", indexValue]);
    IMP test_case_n_imp = [testUnitObj methodForSelector:@selector(generalCaseTest)];
    class_addMethod([testUnitObj class], test_case_n_sel, test_case_n_imp, "v@:"); // FIXME: Check BOOL return value.
    
    NSMethodSignature *testSignature = [RSWebSocketAutobahnTests instanceMethodSignatureForSelector:test_case_n_sel];
    NSInvocation *testInvocation = [NSInvocation invocationWithMethodSignature:testSignature];
    [testInvocation setSelector:test_case_n_sel];
    [testInvocation setTarget:testUnitObj];
    
    SenTestCase *test = [testUnitObj initWithInvocation:testInvocation testIndex:indexValue];
    [testSuite addTest:test];
    [test release];
}


- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [ws release];
    [response release];
    [super tearDown];
}
@end
