//
//  NSMutableArray+QueueAddition.m
//  UnittWebSocketClient
//
//  Created by Josh Morris on 6/16/11.
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
- (id) dequeue 
{
    if ([items count] == 0) 
    {
        return nil;
    }
    id headObject = [items objectAtIndex:0];
    if (headObject != nil) 
    {
        [[headObject retain] autorelease]; // so it isn't dealloc'ed on remove
        [items removeObjectAtIndex:0];
    }
    return headObject;
}

- (void) enqueue:(id) aObject 
{
    [items addObject:aObject];
}

- (id) lastObject
{
    return [items lastObject];
}

#pragma mark Lifecycle
- (id) init 
{
    self = [super init];
    if (self) 
    {
        items = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void) dealloc 
{
    [items release];
    [super dealloc];
}

@end
