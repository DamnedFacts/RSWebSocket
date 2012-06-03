//
//  AppDelegate.m
//  AutobahnTests
//
//  Created by Richard Sarkis on 4/12/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"
#import "octest.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize textViewResults;

- (void)dealloc {
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
}


-(void)awakeFromNib {
    pipe = [NSPipe pipe] ;
    pipeReadHandle = [pipe fileHandleForReading];
    dup2([[pipe fileHandleForWriting] fileDescriptor], STDERR_FILENO) ;

    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(getData:) 
                                                 name:NSFileHandleReadCompletionNotification 
                                               object:pipeReadHandle];
    
    [pipeReadHandle readInBackgroundAndNotify];

    [SenTestTool performSelectorInBackground:@selector(run) withObject:nil];
} 

- (void) getData: (NSNotification *) aNotification {
    [pipeReadHandle readInBackgroundAndNotify];
    
    NSString *str = [[NSString alloc] initWithData: [[aNotification userInfo] objectForKey: NSFileHandleNotificationDataItem] 
                                           encoding: NSASCIIStringEncoding] ;
    
    if ([str length]) [textViewResults insertText:str];
} 


@end
