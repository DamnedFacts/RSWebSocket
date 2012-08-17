//
//  NSMutableArray+QueueAddition.m
//  RSWebSocket
//
//  Copyright 2012 Richard Emile Sarkis. All rights reserved.
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

#import "MutableQueue.h"


@implementation MutableQueue

#pragma mark Queue
- (id) dequeue  {
    if ([items count] == 0) return nil;
    
    id headObject = [items objectAtIndex:0];
    if (headObject != nil) {
         // so it isn't dealloc'ed on remove
        [items removeObjectAtIndex:0];
    }
    return headObject;
}

- (void) enqueue:(id) aObject {
    [items addObject:aObject];
}

- (id) lastObject {
    return [items lastObject];
}

- (id) firstObject {
    return [items objectAtIndex:0];
}

#pragma mark Lifecycle
- (id) init  {
    self = [super init];
    if (self) {
        items = [[NSMutableArray alloc] init];
    }
    return self;
}


- (NSUInteger) count {
    return [items count];
}
@end
