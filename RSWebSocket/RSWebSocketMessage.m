//
//  WebSocketMessage.m
//  RSWebSocket
//
//  Copyright 2012 Richard Emile Sarkis
//  Copyright 2011 UnitT Software
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

#import "RSWebSocketMessage.h"


@implementation RSWebSocketMessage

- (void) pushFragment:(RSWebSocketFragment*) aFragment
{
    [fragments addObject:aFragment];
}

- (NSData*) parse
{
    //parse fragments
    NSMutableData* data = [NSMutableData data];
    for (RSWebSocketFragment* fragment in fragments) 
    {
        [data appendData:fragment.payloadData];
    }
    return data;
}

- (void) clear
{
    [fragments removeAllObjects];
}


#pragma mark Lifecycle
+ (id) messageWithFragment:(RSWebSocketFragment*) aFragment
{
    id result = [[[self class] alloc] initWithFragment:aFragment];
    
    return [result autorelease];
}

- (id) initWithFragment:(RSWebSocketFragment*) aFragment
{
    self = [super init];
    if (self)
    {
        fragments = [[NSMutableArray alloc] init];
        [self pushFragment:aFragment];
    }
    return self;
}

- (id) init
{
    self = [super init];
    if (self)
    {
        fragments = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void) dealloc
{
    [fragments release];
    
    [super dealloc];
}

@end
