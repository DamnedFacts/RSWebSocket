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
    NSLog(@"Did open connection");
}

- (void) didClose:(NSUInteger) aStatusCode message:(NSString*) aMessage error:(NSError*) aError {
    NSLog(@"Status Code: %lu    Close Message: %@   Error: errorDesc=%@, failureReason=%@", 
          aStatusCode, aMessage, [aError localizedDescription], [aError localizedFailureReason]);
    
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
    return [super initWithInvocation:testInvocation];;
}

// We override the SenTest framework's class method to insert our custom tests.
+ (id)defaultTestSuite {    
    SenTestSuite *testSuite = [[SenTestSuite alloc] initWithName:NSStringFromClass(self)];
    
    /***************************/
    /* Add autobahn test cases */
    /***************************/
    // Grab a list of our static test methods *first*, before adding our dynamic ones.
    NSArray *testInvocations = [RSWebSocketAutobahnTests testInvocations];

    // Now add the dynamic Autobahn tests, before the static ones.
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
