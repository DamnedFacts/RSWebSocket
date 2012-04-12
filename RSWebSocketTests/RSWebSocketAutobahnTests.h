//
//  RSWebSocketAutobahnTests.h
//  RSWebSocket
//
//  Created by Richard Sarkis on 2/24/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RSWebSocketTests.h"

typedef enum  {
    WSTestStateGetCounts = 0,
    WSTestStateRunAutobahnTestCases = 1,
    WSTestStateGetAutobahnTestCaseExp = 2,
    WSTestStateClosing = 3,
} RSWebSocketTestState;

@interface RSWebSocketAutobahnTests : RSWebSocketTests {    
    NSUInteger              testSuiteIndex; // Store the specific case this will run.
    NSUInteger              testSuiteTotal; // Stores our total number of test cases in Autobahn
    RSWebSocketTestState    test_states;
    
    NSDictionary *          testCaseExpResults;
    ClosingStatusCodes      testCaseRetResults;
}

@property (nonatomic)           NSUInteger testSuiteIndex;

- (NSUInteger) getCaseCount;
- (id)initWithInvocation:(NSInvocation *)testInvocation testIndex: (NSUInteger) index;
@end
