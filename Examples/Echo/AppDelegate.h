//
//  AppDelegate.h
//  Echo
//
//  Created by Richard Sarkis on 4/12/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "RSWebSocket.h"

@interface AppDelegate : NSObject <NSApplicationDelegate,RSWebSocketDelegate> {
    RSWebSocket* ws;
    NSString* response;
}

#pragma mark Interface Builder Outlets
@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTextView *textViewResults;
@property (assign) IBOutlet NSButton *connectButton;
@property (assign) IBOutlet NSButton *fileButton;
@property (assign) IBOutlet NSTextField *messageField;

#pragma mark Interface Builder Outlets

@property (nonatomic, readonly) RSWebSocket* ws;
@property (nonatomic, readonly) NSString* response;
@end
