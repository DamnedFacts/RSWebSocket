//
//  RSWebSocketTests.m
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
    
- (void) didClose: (NSError *) closingStatusError 
        localCode: (NSUInteger) closingStatusLocalCode  
     localMessage: (NSString *) closingStatusLocalMessage
       remoteCode: (NSUInteger) closingStatusRemoteCode
    remoteMessage: (NSString *) closingStatusRemoteMessage {
    
    NSLog(@"Closing Status: (%lu%@:%lu%@) %@", 
          closingStatusLocalCode, (closingStatusLocalMessage == nil)?@"":[NSString stringWithFormat:@"/%@",closingStatusLocalMessage], 
          closingStatusRemoteCode, (closingStatusRemoteMessage == nil)?@"":[NSString stringWithFormat:@"/%@",closingStatusRemoteMessage], 
          [closingStatusError localizedDescription]);
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
    
    
    return testSuite;
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
        SEL test_case_n_sel = NSSelectorFromString([NSString stringWithFormat:@"testCase%d", i]);
        class_addMethod([unitTest class], test_case_n_sel, test_case_n_imp, "v@:"); // FIXME: Check BOOL return value.
        
        // Create an invocation object for this test case
        NSMethodSignature *testSignature = [RSWebSocketAutobahnTests instanceMethodSignatureForSelector:test_case_n_sel];
        NSInvocation *testInvocation = [NSInvocation invocationWithMethodSignature:testSignature];
        [testInvocation setSelector:test_case_n_sel];
        [testInvocation setTarget:unitTest];

        
        SenTestCase *test = [[[RSWebSocketAutobahnTests alloc] init] initWithInvocation:testInvocation testIndex:i];
        [testSuite addTest:test];
    }
    
    // Add static Autobahn test cases
    for (NSInvocation *testInvocation in testInvocations) {
        SenTestCase *test = [[[RSWebSocketAutobahnTests alloc] init] initWithInvocation:testInvocation];
        [testSuite addTest:test];
    }
}


- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}
@end
