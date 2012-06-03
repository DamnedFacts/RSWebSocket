//
//  octest.h
//  RSWebSocket
//
//  Created by Richard Sarkis on 4/12/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//
/*
 *  otest.c
 *  CocoaSQL
 *
 *  Created by Igor Sutton on 4/9/10.
 *  Copyright 2010 CocoaSQL.org. All rights reserved.
 *
 */

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface octest : NSObject
-(id)init;
@end

@interface SenTestTool : NSObject {
}

+ (void) run;
+ (SenTestTool *) sharedInstance;
@end