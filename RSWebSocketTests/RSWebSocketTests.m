//
//  RSWebSocketTests.m
//  RSWebSocketTests
//
//  Created by Richard Sarkis on 1/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <objc/objc-class.h>
#import "RSWebSocketTests.h"
#import "RSWebSocketAutobahnTests.h"

@implementation RSWebSocketTests
@synthesize ws;
@synthesize response;

#pragma mark WebSocketDelegate Methods
- (void) didOpen {
//    NSLog(@"Did open connection");
}

- (void) didClose:(ClosingStatusCodes)cstatus {
    
    NSLog(@"Closing Status: (%lu%@:%lu%@) %@", 
          cstatus.localCode, (cstatus.localMessage == nil)?@"":[NSString stringWithFormat:@"/%@",cstatus.localMessage], 
          cstatus.remoteCode, (cstatus.remoteMessage == nil)?@"":[NSString stringWithFormat:@"/%@",cstatus.remoteMessage], 
          [cstatus.error localizedDescription]);
}

- (void) didReceiveError: (NSError*) aError {
    NSLog(@"Error: errorDesc=%@, failureReason=%@", [aError localizedDescription], [aError localizedFailureReason]);
}

- (void) didReceiveTextMessage: (NSString*) aMessage {
//    NSLog(@"Did receive text message");
}

- (void) didReceiveBinaryMessage: (NSData*) aMessage {
//    NSLog(@"Did receive binary message");
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
    return [super initWithInvocation:testInvocation];
}

// We override the SenTest framework's class method to insert our custom tests.
+ (id)defaultTestSuite {    
    SenTestSuite *testSuite = [[SenTestSuite alloc] initWithName:NSStringFromClass(self)];
    
    /***************************/
    /* Add autobahn test cases */
    /***************************/
    // Grab a list of our static test methods *first*, before adding our dynamic ones.
    [self addTestsForAutobahn:testSuite];

    /***************************/
    /* Add internal test cases */
    /***************************/
    // This array of NSInvocation objects contains a single object that points to our single test method.
    //    NSArray *testInvocations = [self testInvocations];
    
    //    for (NSInvocation *testInvocation in testInvocations) {
    //    }
    
    
    return [testSuite autorelease];
}

+ (void)addTestsForAutobahn:(SenTestSuite *)testSuite {
    NSArray *testInvocations = [RSWebSocketAutobahnTests testInvocations];
    
    // Now add the dynamic Autobahn tests, before the static ones.
    RSWebSocketAutobahnTests *unitTest= [[RSWebSocketAutobahnTests alloc] init];    
    NSUInteger totalTests = [unitTest getCaseCount];
    IMP test_case_n_imp = [unitTest methodForSelector:@selector(generalCaseTest)];

    for (int i = 1; i<=totalTests; i++) {
        // Obj-C Runtime swizzling. We're taking the method "generalCaseTest" and renaming it and
        // parameterizing it with the index number of the Autobahn test case we want it to run.
        SEL test_case_n_sel = NSSelectorFromString([NSString stringWithFormat:@"testCase%ld", i]);
        class_addMethod([unitTest class], test_case_n_sel, test_case_n_imp, "v@:"); // FIXME: Check BOOL return value.
        
        // Create an invocation object for this test case
        NSMethodSignature *testSignature = [RSWebSocketAutobahnTests instanceMethodSignatureForSelector:test_case_n_sel];
        NSInvocation *testInvocation = [NSInvocation invocationWithMethodSignature:testSignature];
        [testInvocation setSelector:test_case_n_sel];
        [testInvocation setTarget:unitTest];

        
        SenTestCase *test = [[[RSWebSocketAutobahnTests alloc] init] initWithInvocation:testInvocation testIndex:i];
        [testSuite addTest:test];
        [test release];
    }
    [unitTest release];
    
    // Add static Autobahn test cases
    for (NSInvocation *testInvocation in testInvocations) {
        SenTestCase *test = [[[RSWebSocketAutobahnTests alloc] init] initWithInvocation:testInvocation];
        [testSuite addTest:test];
        [test release];
    }
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
