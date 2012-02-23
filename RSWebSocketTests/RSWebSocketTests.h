//
//  RSWebSocketTests.h
//  RSWebSocketTests
//
//  Created by Richard Sarkis on 1/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

//
//  UnittWebSocketClient10Tests.h
//  UnittWebSocketClient
//
//  Created by Josh Morris on 6/19/11.
//  Copyright 2011 UnitT Software. All rights reserved.
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

#import <SenTestingKit/SenTestingKit.h>
#import "RSWebSocket.h"

typedef enum  {
    WSTestStateGetCounts = 0,
    WSTestStateRunAutobahnTestCases = 1,
    WSTestStateClosing = 2,
} RSWebSocketTestState;




@interface RSWebSocketTests : SenTestCase <RSWebSocketDelegate> {
@package
    RSWebSocket* ws;
    NSString* response;
    RSWebSocketTestState test_states;
}

@property (nonatomic, readonly) RSWebSocket* ws;
@property (nonatomic, readonly) NSString* response;

+ (void)addTestsForAutobahn:(NSUInteger)indexValue 
                      toTestSuite:(SenTestSuite *)testSuite;
- (void) waitForSeconds: (NSTimeInterval) aSeconds;
@end




@interface RSWebSocketAutobahnTests : RSWebSocketTests {    
    NSUInteger testSuiteIndex;
    NSUInteger testCasesCount;
}

@property (nonatomic)           NSUInteger testSuiteIndex;

- (NSUInteger) getCaseCount;
@end
