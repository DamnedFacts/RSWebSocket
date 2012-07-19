//
//  RSWebSocketAutobahnTests.h
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
