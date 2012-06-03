//
//  AppDelegate.h
//  AutobahnTests
//
//  Created by Richard Sarkis on 4/12/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    NSPipe *pipe;
    NSFileHandle *pipeReadHandle;
}
@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTextView *textViewResults;
@end
