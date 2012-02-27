//
//  RSWebSocketAutobahnTests.h
//  RSWebSocket
//
//  Created by Richard Sarkis on 2/24/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RSWebSocketTests.h"

typedef enum  {
    WSTestStateGetCounts = 0,
    WSTestStateRunAutobahnTestCases = 1,
    WSTestStateClosing = 2,
} RSWebSocketTestState;

@interface RSWebSocketAutobahnTests : RSWebSocketTests {    
    NSUInteger testSuiteIndex; // Store the specific case this will run.
    NSUInteger testCasesCount; // Stores our total number of test cases in Autobahn
    RSWebSocketTestState test_states;
}

@property (nonatomic)           NSUInteger testSuiteIndex;

- (NSUInteger) getCaseCount;
- (id)initWithInvocation:(NSInvocation *)testInvocation testIndex: (NSUInteger) index;
@end
