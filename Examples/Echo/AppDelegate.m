//
//  AppDelegate.m
//  Echo
//
//  Created by Richard Sarkis on 4/12/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
BOOL flag = YES;

@implementation AppDelegate
@synthesize ws;
@synthesize response;
@synthesize window = _window;
@synthesize connectButton;
@synthesize textViewResults;
@synthesize messageField;
@synthesize fileButton;

- (void)dealloc {
    [response release];
    [ws release];
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self.connectButton setTitle:@"Connect"];
    [self.messageField setEditable:NO];
    [self.textViewResults setEditable:NO];
    [self.fileButton setEnabled:NO];
}

#pragma mark Interface Builder Action Methods
- (IBAction) controlWSConnectionState: (id)sender {
    if (!ws) {
        // Insert code here to initialize your application
        RSWebSocketConnectConfig* config = [RSWebSocketConnectConfig configWithURLString:@"ws://localhost:9000/echo?mode='basic'" 
                                                                              origin:@"ws://localhost" 
                                                                           protocols:nil
                                                                         tlsSettings:nil 
                                                                             headers:nil 
                                                                   verifySecurityKey:YES 
                                                                          extensions:nil ];
        ws = [[RSWebSocket webSocketWithConfig:config delegate:self] retain];
        [self.ws open];    
    } else if (ws && ![ws isConnectionOpen]) {
        [self.ws open];    
    } else if (ws && [ws isConnectionOpen]) {
        [self.ws close];
    }
}

- (IBAction)echoMessage:(id)sender {
    NSString *sendStr = [(NSTextField *) sender stringValue];
    if ([sendStr length] > 0) {
        NSLog(@"%@", sendStr);
        [self.ws sendText:sendStr];
        [(NSTextField * ) sender setStringValue:@""];
    }
}

- (IBAction)echoFile:(id)sender {
    NSArray *fileTypes = [NSArray arrayWithObjects:@"jpg", nil];
    
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    
    [oPanel setAllowedFileTypes:fileTypes];
    
    int result = [oPanel runModal];
    
    if (result == NSOKButton) {
        NSArray *fileToOpen = [oPanel URLs];
        NSURL *fileURL = [fileToOpen objectAtIndex:0];        
        [self.ws sendText:[fileURL path]];
        
        //NSString* imageName=[[NSBundle mainBundle] pathForResource:[fileURL path] ofType:@"JPG"];
        NSImage*  tempImage=[[NSImage alloc] initWithContentsOfFile:[fileURL path]];
        NSData *tempData = [tempImage TIFFRepresentation];
        NSLog(@"Sending %ld bytes of binary data", [tempData length]);
        [self.ws sendBinary:tempData];
    }
}

#pragma mark WebSocketDelegate Methods
- (void) didOpen {
    NSLog(@"Connection Open to Echo Server");
    [self.connectButton setTitle:@"Disconnect"];
    [self.messageField setEditable:YES];
    [self.fileButton setEnabled:YES];
}

- (void) didClose:(ClosingStatusCodes)cstatus {
    [self.connectButton setTitle:@"Connect"];
    [self.messageField setEditable:NO];
    [self.fileButton setEnabled:NO];

    NSLog(@"Connection Closed to Echo Server");
    NSLog(@"Closing Status: (%lu%@:%lu%@) %@", 
          cstatus.localCode, (cstatus.localMessage == nil)?@"":[NSString stringWithFormat:@"/%@",cstatus.localMessage], 
          cstatus.remoteCode, (cstatus.remoteMessage == nil)?@"":[NSString stringWithFormat:@"/%@",cstatus.remoteMessage], 
          [cstatus.error localizedDescription]);
}

- (void) didReceiveError: (NSError*) aError {
    NSLog(@"Error: errorDesc=%@, failureReason=%@", [aError localizedDescription], [aError localizedFailureReason]);
}

- (void) didReceiveTextMessage: (NSString*) aMessage {
    //    NSLog(@"Did receive text message");
    [self appendToResult:aMessage];
    [self appendToResult:@"\n"];
}

- (void) didReceiveBinaryMessage: (NSData*) aMessage {
    //    NSLog(@"Did receive binary message");
    NSLog(@"Received %ld bytes of binary data", [aMessage length]);
//    NSBitmapImageRep* imageRep=[[[NSBitmapImageRep alloc] initWithData:aMessage] autorelease];
    NSImage*  tempImage=[[NSImage alloc] initWithData:aMessage];
    
    NSTextAttachmentCell *attachmentCell = [[NSTextAttachmentCell alloc] initImageCell:tempImage];
    NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
    [attachment setAttachmentCell: attachmentCell];
    NSAttributedString *attributedString = [NSAttributedString attributedStringWithAttachment: attachment];
    [[textViewResults textStorage] appendAttributedString:attributedString];
}


#pragma mark WebSocket Tests
- (void) waitOnClose {
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    while (flag && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]);    
    flag = YES;
}

- (void) waitForSeconds: (NSTimeInterval) aSeconds {
    NSDate *secondsFromNow = [NSDate dateWithTimeIntervalSinceNow:aSeconds];
    [[NSRunLoop currentRunLoop] runUntilDate:secondsFromNow];
}

#pragma mark Helper Methods
-(void) appendToResult: (NSString *)str {
    // assume textView is a pointer to the actual text view
    NSRange endRange = NSMakeRange([[textViewResults string] length], 0);
    
    // assume string already contains the data to add to this text view
    [textViewResults replaceCharactersInRange:endRange withString:str];
    [textViewResults scrollRangeToVisible:endRange];
    [textViewResults setNeedsDisplay:YES];
}
@end
