//
//  AppDelegate.h
//  Echo
//
//  Copyright 2012 Richard Emile Sarkis. All rights reserved.
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

#pragma mark Internal variables
@property (nonatomic, readonly) RSWebSocket* ws;
@property (nonatomic, readonly) NSString* response;
@end
