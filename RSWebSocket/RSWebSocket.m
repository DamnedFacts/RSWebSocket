//
//  RSWebSocket.m
//  RSWebSocket
//
//  Created by Richard Sarkis on 1/29/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RSWebSocket.h"

//@implementation RSWebSocket
//
//- (id)init
//{
//    self = [super init];
//    if (self) {
//        // Initialization code here.
//    }
//    
//    return self;
//}
//
//@end

//
//  WebSocket.m
//  UnittWebSocketClient
//
//  Created by Josh Morris on 9/26/11.
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

#import "RSWebSocket.h"
#import "RSWebSocketFragment.h"
#import "HandshakeHeader.h"


enum 
{
    WebSocketWaitingStateMessage = 0, //Starting on waiting for a new message
    WebSocketWaitingStateHeader = 1, //Waiting for the remaining header bytes
    WebSocketWaitingStatePayload = 2, //Waiting for the remaining payload bytes
    WebSocketWaitingStateFragment = 3 //Waiting for the next fragment
};
typedef NSUInteger WebSocketWaitingState;


@interface RSWebSocket(Private)
- (void) dispatchFailure:(NSError*) aError;
- (void) dispatchClosed:(NSUInteger) aStatusCode message:(NSString*) aMessage error:(NSError*) aError;
- (void) dispatchOpened;
- (void) dispatchTextMessageReceived:(NSString*) aMessage;
- (void) dispatchBinaryMessageReceived:(NSData*) aMessage;
- (void) continueReadingMessageStream;
- (NSString*) buildOrigin;
- (NSString*) buildPort;
- (NSString*) getRequest: (NSString*) aRequestPath;
- (NSData*) getSHA1:(NSData*) aPlainText;
- (void) generateSecKeys;
- (BOOL) isUpgradeResponse: (NSString*) aResponse;
- (NSMutableArray*) getServerExtensions:(NSMutableArray*) aServerHeaders;
- (void) sendClose:(NSUInteger) aStatusCode message:(NSString*) aMessage;
- (void) sendMessage:(NSData*) aMessage messageWithOpCode:(MessageOpCode) aOpCode;
- (void) sendMessage:(RSWebSocketFragment*) aFragment;
- (void) handleMessageData:(NSData*) aData;
- (void) handleCompleteFragment:(RSWebSocketFragment*) aFragment;
- (void) handleCompleteFragments;
- (void) handleClose:(RSWebSocketFragment*) aFragment;
- (void) handlePing:(NSData*) aMessage;
- (void) closeSocket;
- (void) scheduleForceCloseCheck:(NSTimeInterval) aInterval;
- (void) checkClose:(NSTimer*) aTimer;
- (NSString*) buildStringFromHeaders:(NSMutableArray*) aHeaders resource:(NSString*) aResource;
- (NSMutableArray*) buildHeadersFromString:(NSString*) aHeaders;
- (HandshakeHeader*) headerForKey:(NSString*) aKey inHeaders:(NSMutableArray*) aHeaders;
@end


@implementation RSWebSocket

NSString* const WebSocketException = @"WebSocketException";
NSString* const WebSocketErrorDomain = @"WebSocketErrorDomain";

enum {
    TagHandshake = 0,
    TagMessage = 1
};

WebSocketWaitingState waitingState;

@synthesize config;
@synthesize delegate;
@synthesize readystate;

#pragma mark Public Interface
- (void) open
{
    UInt16 port = self.config.isSecure ? 443 : 80;
    if (self.config.url.port)
    {
        port = [self.config.url.port intValue];
    }
    NSError* error = nil;
    BOOL successful = false;
    @try 
    {
        successful = [socket connectToHost:self.config.url.host onPort:port error:&error];
        if (self.config.version == WebSocketVersion07)
        {
            closeStatusCode = WebSocketCloseStatusNormal;
        }
        else
        {
            closeStatusCode = 0;
        }
        closeMessage = nil;
    }
    @catch (NSException *exception) 
    {
        error = [NSError errorWithDomain:WebSocketErrorDomain code:0 userInfo:exception.userInfo]; 
    }
    @finally 
    {
        if (!successful)
        {
            [self dispatchClosed:WebSocketCloseStatusProtocolError message:nil error:error];
        }
    }
}

- (void) close
{
    [self close:WebSocketCloseStatusNormal message:nil];
}

- (void) close:(NSUInteger) aStatusCode message:(NSString*) aMessage
{
    readystate = WebSocketReadyStateClosing;
    //any rev before 10 does not perform a UTF8 check
    if (self.config.version < WebSocketVersion10)
    {
        [self sendClose:aStatusCode message:aMessage];        
    }
    else
    {
        if (aMessage && [aMessage canBeConvertedToEncoding:NSUTF8StringEncoding])
        {
            [self sendClose:aStatusCode message:aMessage];
        }
        else
        {
            [self sendClose:aStatusCode message:nil];
        }
    }
    isClosing = YES;
}

- (void) scheduleForceCloseCheck
{
    [NSTimer scheduledTimerWithTimeInterval:self.config.closeTimeout
                                     target:self
                                   selector:@selector(checkClose:)
                                   userInfo:nil
                                    repeats:NO];
}

- (void) checkClose:(NSTimer*) aTimer
{
    if (self.readystate == WebSocketReadyStateClosing)
    {
        [self closeSocket];
    }
}

- (void) sendClose:(NSUInteger) aStatusCode message:(NSString*) aMessage
{
    //create payload
    NSMutableData* payload = nil;
    if (aStatusCode > 0)
    {
        closeStatusCode = aStatusCode;
        payload = [NSMutableData data];
        unsigned char current = (unsigned char)(aStatusCode/0x100);
        [payload appendBytes:&current length:1];
        current = (unsigned char)(aStatusCode%0x100);
        [payload appendBytes:&current length:1];
        if (aMessage)
        {
            closeMessage = aMessage;
            [payload appendData:[aMessage dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    
    //send close message
    [self sendMessage:[RSWebSocketFragment fragmentWithOpCode:MessageOpCodeClose isFinal:YES payload:payload]];
    
    //schedule the force close
    if (self.config.closeTimeout >= 0)
    {
        [self scheduleForceCloseCheck];
    }
}

- (void) sendText:(NSString*) aMessage {
    // Causes a hang in xcode unit tester.
    //NSLog(@"(DEBUG) sendText: %@",aMessage);
    
    //no reason to grab data if we won't send it anyways
    if (!isClosing) {       
        //only send non-nil data
        if (aMessage) {
            if ([aMessage canBeConvertedToEncoding:NSUTF8StringEncoding]) {
                [self sendMessage:[aMessage dataUsingEncoding:NSUTF8StringEncoding] messageWithOpCode:MessageOpCodeText];       
            }
            else if (self.config.version >= WebSocketVersion10) {
                [self close:WebSocketCloseStatusInvalidUtf8 message:nil];
            }
        } else {
            [self sendMessage:[@"" dataUsingEncoding:NSUTF8StringEncoding] messageWithOpCode:MessageOpCodeText];       
        }
    }
}

- (void) sendBinary:(NSData*) aMessage
{
    [self sendMessage:aMessage messageWithOpCode:MessageOpCodeBinary];
}

- (void) sendPing:(NSData*) aMessage
{
    [self sendMessage:aMessage messageWithOpCode:MessageOpCodePing];
}

- (void) sendMessage:(NSData*) aMessage messageWithOpCode:(MessageOpCode) aOpCode {
    if (!isClosing) {
        NSUInteger messageLength = [aMessage length];
        if (messageLength <= self.config.maxPayloadSize) {
            // Our data payload (extension + application data) is <= maxPayloadSize.
            RSWebSocketFragment* fragment = [RSWebSocketFragment fragmentWithOpCode:aOpCode isFinal:YES payload:aMessage];
            [self sendMessage:fragment];
        } else {
            NSMutableArray* fragments = [NSMutableArray array];
            unsigned long fragmentCount = messageLength / self.config.maxPayloadSize;
            if (messageLength % self.config.maxPayloadSize) {
                fragmentCount++;
            }
            
            //build fragments
            for (int i = 0; i < fragmentCount; i++) {
                RSWebSocketFragment* fragment = nil;
                unsigned long fragmentLength = self.config.maxPayloadSize;
                if (i == 0) {
                    fragment = [RSWebSocketFragment fragmentWithOpCode:aOpCode isFinal:NO payload:[aMessage subdataWithRange:NSMakeRange(i * self.config.maxPayloadSize, fragmentLength)]];
                } else if (i == fragmentCount - 1) {
                    fragmentLength = messageLength % self.config.maxPayloadSize;
                    if (fragmentLength == 0) {
                        fragmentLength = self.config.maxPayloadSize;
                    }
                    fragment = [RSWebSocketFragment fragmentWithOpCode:MessageOpCodeContinuation isFinal:YES payload:[aMessage subdataWithRange:NSMakeRange(i * self.config.maxPayloadSize, fragmentLength)]];
                } else {
                    fragment = [RSWebSocketFragment fragmentWithOpCode:MessageOpCodeContinuation isFinal:NO payload:[aMessage subdataWithRange:NSMakeRange(i * self.config.maxPayloadSize, fragmentLength)]];
                }
                [fragments addObject:fragment];
            }
            
            //send fragments
            for (RSWebSocketFragment* fragment in fragments) {
                [self sendMessage:fragment];
            }
        }  
    }
}

- (void) sendMessage:(RSWebSocketFragment*) aFragment
{
    if (!isClosing || aFragment.opCode == MessageOpCodeClose) {
        [socket writeData:aFragment.fragment withTimeout:self.config.timeout tag:TagMessage];
    }
}


#pragma mark Internal Web Socket Logic
- (void) continueReadingMessageStream 
{
    [socket readDataWithTimeout:self.config.timeout tag:TagMessage];
}

- (void) closeSocket
{
    readystate = WebSocketReadyStateClosing;
    [socket disconnectAfterWriting];
}

- (void) handleCompleteFragment:(RSWebSocketFragment*) aFragment {
    //if we are not in continuation and its final, dequeue
//    if (aFragment.isFinal && aFragment.opCode != MessageOpCodeContinuation) {
//        // Final frame in our received fragments
//        [pendingFragments dequeue];
//    }
    
    //continue to process
    switch (aFragment.opCode)  {
        case MessageOpCodeContinuation:
            if (aFragment.isFinal) [self handleCompleteFragments];
            else [self close:WebSocketCloseStatusProtocolError message:nil];
            break;
        case MessageOpCodeText:
            if (aFragment.isFinal) {
                if (aFragment.payloadData.length) {
                    NSString* textMsg = [[[NSString alloc] initWithData:aFragment.payloadData encoding:NSUTF8StringEncoding] autorelease];
                    if (textMsg) {
                        [self dispatchTextMessageReceived:textMsg];
                    } else {
                        [self close:WebSocketCloseStatusInvalidUtf8 message:nil];
                    }
                } else {
                    NSString* textMsg = [[[NSString alloc] initWithUTF8String:""] autorelease];
                    [self dispatchTextMessageReceived:textMsg];
                }
            }
            break;
        case MessageOpCodeBinary:
            if (aFragment.isFinal) [self dispatchBinaryMessageReceived:aFragment.payloadData];
            break;
        case MessageOpCodeClose:
            [self handleClose:aFragment];
            break;
        case MessageOpCodePing:
            [self handlePing:aFragment.payloadData];
            break;
        case MessageOpCodePong:
            // handle Pong frame in some way?
            // A response to an unsolicited Pong frame is not expected.
            // A Pong frame sent in response to a Ping frame must have identical
            // "Application data" as found in the message body of the Ping frame
            // being replied to.
            break;
    }
}

- (void) handleCompleteFragments {
    RSWebSocketFragment* fragment = [pendingFragments dequeue];
    
    if (fragment != nil) {
        //init
        NSMutableData* messageData = [NSMutableData data];
        MessageOpCode messageOpCode = fragment.opCode;
        
        //loop through, constructing single message
        while (fragment != nil) {
            /*    
             first fragment:  would have an opcode of 0x1 and a FIN bit clear
             second fragment: would have an opcode of 0x0 and a FIN bit clear
             third fragment:  would have an opcode of 0x0 and a FIN bit
             FIXME: This does not allow for any multiplexing.
                    It simply filters out unfragmented frames.
             */
            if ((messageOpCode != MessageOpCodeContinuation && !fragment.isFinal) ||
                (fragment.opCode == MessageOpCodeContinuation))
                [messageData appendData:fragment.payloadData];
            fragment = [pendingFragments dequeue];
        }
        
        //handle final message contents        
        switch (messageOpCode) {
            case MessageOpCodeContinuation:
                // First fragment cannot have a continuation opcode.
                [self close:WebSocketCloseStatusProtocolError message:nil];
                break;
            case MessageOpCodeText:
                if (messageData.length) {
                    NSString* textMsg = [[[NSString alloc] initWithData:messageData encoding:NSUTF8StringEncoding] autorelease];
                    if (textMsg) {
                        [self dispatchTextMessageReceived:textMsg];
                    } else if (self.config.version >= WebSocketVersion10) {
                        [self close:WebSocketCloseStatusInvalidUtf8 message:nil];
                    }
                }
                break;
            case MessageOpCodeBinary:
                [self dispatchBinaryMessageReceived:messageData];
                break;
        }
    }
}

- (void) handleClose:(RSWebSocketFragment*) aFragment
{
    //close status & message
    BOOL invalidUTF8 = NO;
    if (aFragment.payloadData)
    {
        NSUInteger length = aFragment.payloadData.length;
        if (length >= 2)
        {
            //get status code
            unsigned char buffer[2];
            [aFragment.payloadData getBytes:&buffer length:2];
            closeStatusCode = buffer[0] << 8 | buffer[1];
            
            //get message
            if (length > 2)
            {
                closeMessage = [[NSString alloc] initWithData:[aFragment.payloadData subdataWithRange:NSMakeRange(2, length - 2)] encoding:NSUTF8StringEncoding];
                if (!closeMessage)
                {
                    invalidUTF8 = YES;
                }
            }
        }
    }
    
    //handle close
    if (isClosing)
    {
        [self closeSocket];
    }
    else
    {
        isClosing = YES;
        if (!invalidUTF8 || self.config.version < WebSocketVersion10)
        {
            [self close:0 message:nil];
        }
        else
        {
            [self close:WebSocketCloseStatusInvalidUtf8 message:nil];
        }
    }
}

- (void) handlePing:(NSData*) aMessage {
    // FIXME: Debug
//    NSLog(@"Handling Ping...");
    if (!isClosing) {
        [self sendMessage:aMessage messageWithOpCode:MessageOpCodePong];
    
        if ([delegate respondsToSelector:@selector(didSendPong:)]) {
            [delegate didSendPong:aMessage];
        }
    }
}

- (void) handleMessageData:(NSData*) aData {
    /* 
     There is a queued fragment that hasn't received complete data yet (it isn't valid); append to it
     
     If the received data (aData) is greater fragment size we are constructing, only copy the bytes we require
     The remaining bytes are passed back for futher frame construction.
     Otherwise, if aData doesn't have all the bytes we require, consume all that we received in hopes of more later!
    
     If we don't have a a queued fragment to work with, so we need to make a create a new fragment.
     If the size of aData exceeds the bytes we require, only consume up to that amount we need.
     Otherwise, add the whole thing to our new fragment.
    */

    NSUInteger consumed = 0;

    // Grab last fragment; use if not complete
    RSWebSocketFragment* fragment = [pendingFragments lastObject];
    
    if (fragment && !fragment.isFrameComplete) {
        consumed = fragment.messageLength - fragment.fragment.length; 
        if ([aData length] < consumed) consumed = [aData length];
        [fragment.fragment appendData: [aData subdataWithRange:NSMakeRange(0, consumed)]];
    } else {
        fragment = [RSWebSocketFragment fragmentWithData:aData];
        consumed = fragment.messageLength;
        if ([aData length] < consumed) consumed = [aData length];
        fragment = [RSWebSocketFragment fragmentWithData: [aData subdataWithRange:NSMakeRange(0, consumed)]];
        [pendingFragments enqueue:fragment];
    }
    
    // Otherwise our fragment is potentially valid.
    // FIXME: Debug mode
//    NSLog(@"messageLength: %ld aDataLength:%ld fragment.length:%ld consumed:%ld", fragment.messageLength, [aData length], fragment.fragment.length,consumed);
    //    [fragment.fragment writeToFile:@"/tmp/bytes.txt" atomically:TRUE];

    //parse the data, if possible
    if (fragment.canBeParsed) {
        [fragment parseContent];
        if (fragment.isValid) {
            [self handleCompleteFragment:fragment];
            if (isClosing) return; // Failure condition, return immediately.
        } else {
            [self close:WebSocketCloseStatusProtocolError message:nil];
            return; // Failure condition, return immediately.
        }
    }
    
    // If we have extra data, pass it on to a recursive call to handleMessageData.
    if ([aData length] > consumed) {
        [self handleMessageData:[aData subdataWithRange:NSMakeRange(consumed, [aData length] - consumed)]];
    } 
}

- (NSData*) getSHA1:(NSData*) aPlainText 
{
    CC_SHA1_CTX ctx;
    uint8_t * hashBytes = NULL;
    NSData * hash = nil;
    
    // Malloc a buffer to hold hash.
    hashBytes = malloc( CC_SHA1_DIGEST_LENGTH * sizeof(uint8_t) );
    memset((void *)hashBytes, 0x0, CC_SHA1_DIGEST_LENGTH);
    
    // Initialize the context.
    CC_SHA1_Init(&ctx);
    // Perform the hash.
    CC_SHA1_Update(&ctx, (void *)[aPlainText bytes], (CC_LONG)[aPlainText length]);
    // Finalize the output.
    CC_SHA1_Final(hashBytes, &ctx);
    
    // Build up the SHA1 blob.
    hash = [NSData dataWithBytes:(const void *)hashBytes length:(NSUInteger)CC_SHA1_DIGEST_LENGTH];
    
    if (hashBytes) free(hashBytes);
    
    return hash;
}

- (NSString*) getRequest: (NSString*) aRequestPath
{
    //create headers if they are missing
    NSMutableArray* headers = self.config.headers;
    if (headers == nil)
    {
        headers = [NSMutableArray array];
        self.config.headers = headers;
    }
    
    //handle security keys
    [self generateSecKeys];
    [headers addObject:[HandshakeHeader headerWithValue:wsSecKey forKey:@"Sec-WebSocket-Key"]];
    
    //handle host
    [headers addObject:[HandshakeHeader headerWithValue:self.config.host forKey:@"Host"]];
    
    //handle origin
    [headers addObject:[HandshakeHeader headerWithValue:self.config.origin forKey:@"Sec-WebSocket-Origin"]];
    
    //handle version
    [headers addObject:[HandshakeHeader headerWithValue:[NSString stringWithFormat:@"%i",self.config.version] forKey:@"Sec-WebSocket-Version"]];
    
    //handle protocol
    if (self.config.protocols && self.config.protocols.count > 0)
    {
        //build protocol fragment
        NSMutableString* protocolFragment = [NSMutableString string];
        for (NSString* item in self.config.protocols)
        {
            if ([protocolFragment length] > 0) 
            {
                [protocolFragment appendString:@", "];
            }
            [protocolFragment appendString:item];
        }
        
        //include protocols, if any
        if ([protocolFragment length] > 0)
        {
            [headers addObject:[HandshakeHeader headerWithValue:protocolFragment forKey:@"Sec-WebSocket-Protocol"]];
        }
    }
    
    //handle extensions
    if (self.config.extensions && self.config.extensions.count > 0)
    {
        //build extensions fragment
        NSMutableString* extensionFragment = [NSMutableString string];
        for (NSString* item in self.config.extensions)
        {
            if ([extensionFragment length] > 0) 
            {
                [extensionFragment appendString:@", "];
            }
            [extensionFragment appendString:item];
        }
        
        //return request with extensions
        if ([extensionFragment length] > 0)
        {
            [headers addObject:[HandshakeHeader headerWithValue:extensionFragment forKey:@"Sec-WebSocket-Extensions"]];
        }
    }
    
    return [self buildStringFromHeaders:headers resource:aRequestPath];
}

- (NSString*) buildStringFromHeaders:(NSMutableArray*) aHeaders resource:(NSString*) aResource
{
    //init
    NSMutableString* result = [NSMutableString stringWithFormat:@"GET %@ HTTP/1.1\r\nUpgrade: WebSocket\r\nConnection: Upgrade\r\n", aResource];
    
    //add headers
    if (aHeaders)
    {
        for (HandshakeHeader* header in aHeaders) 
        {
            if (header)
            {
                [result appendFormat:@"%@: %@\r\n", header.key, header.value];
            }
        }
    }
    
    //add terminator
    [result appendFormat:@"\r\n"];
    
    return result;
}

- (NSMutableArray*) buildHeadersFromString:(NSString*) aHeaders
{
    NSMutableArray* results = [NSMutableArray array];
    NSArray *listItems = [aHeaders componentsSeparatedByString:@"\r\n"];
    for (NSString* item in listItems) 
    {
        NSRange range = [item rangeOfString:@":" options:NSLiteralSearch];
        if (range.location != NSNotFound)
        {
            NSString* key = [item substringWithRange:NSMakeRange(0, range.location)];
            key = [key stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
            NSString* value = [item substringFromIndex:range.length + range.location];
            value = [value stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
            [results addObject:[HandshakeHeader headerWithValue:value forKey:key]];
        }
    }
    return results;
}

- (void) generateSecKeys
{
    NSString* initialString = [NSString stringWithFormat:@"%f", [NSDate timeIntervalSinceReferenceDate]];
    NSData *data = [initialString dataUsingEncoding:NSUTF8StringEncoding];
	NSString* key = [data base64EncodedString];
    wsSecKey = [key copy];
    key = [NSString stringWithFormat:@"%@%@", wsSecKey, @"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"];
    data = [self getSHA1:[key dataUsingEncoding:NSUTF8StringEncoding]];
    key = [data base64EncodedString];
    wsSecKeyHandshake = [key copy];
}

- (HandshakeHeader*) headerForKey:(NSString*) aKey inHeaders:(NSMutableArray*) aHeaders
{
    for (HandshakeHeader* header in aHeaders)
    {
        if (header)
        {
            if ([header keyMatchesCaseInsensitiveString:aKey])
            {
                return header;
            }
        }
    }
    
    return nil;
}

- (BOOL) isUpgradeResponse: (NSString*) aResponse
{
    //a HTTP 101 response is the only valid one
    if ([aResponse hasPrefix:@"HTTP/1.1 101"])
    {        
        //build headers
        self.config.serverHeaders = [self buildHeadersFromString:aResponse];
        
        //check security key, if requested
        if (self.config.verifySecurityKey)
        {
            HandshakeHeader* header = [self headerForKey:@"Sec-WebSocket-Accept" inHeaders:self.config.serverHeaders];
            if (![wsSecKeyHandshake isEqualToString:header.value])
            {
                return false;
            }
        }
        
        //verify we have a "Upgrade: websocket" header
        HandshakeHeader* header = [self headerForKey:@"Upgrade" inHeaders:self.config.serverHeaders];
        if ([@"websocket" caseInsensitiveCompare:header.value] != NSOrderedSame)
        {
            return false;
        }
        
        //verify we have a "Connection: Upgrade" header
        header = [self headerForKey:@"Connection" inHeaders:self.config.serverHeaders];
        if ([@"Upgrade" caseInsensitiveCompare:header.value] != NSOrderedSame)
        {
            return false;
        }
        
        return true;
    }
    
    return false;
}

- (NSMutableArray*) getServerExtensions:(NSMutableArray*) aServerHeaders
{
    NSMutableArray* results = [NSMutableArray array];
    
    //loop through values trimming and adding to extensions 
    HandshakeHeader* header = [self headerForKey:@"Sec-WebSocket-Extensions" inHeaders:self.config.serverHeaders];
    if (header)
    {
        NSString* extensionValues = header.value;
        NSArray *listItems = [extensionValues componentsSeparatedByString:@","];
        for (NSString* item in listItems) 
        {
            if (item)
            {
                NSString* value = [item stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
                if (value && value.length)
                {
                    [results addObject:value];
                }
            }
        }
    }
    
    return results;
}


#pragma mark Web Socket Delegate
- (void) dispatchFailure:(NSError*) aError 
{
    if(delegate) 
    {
        [delegate didReceiveError:aError];
    }
}

- (void) dispatchClosed:(NSUInteger) aStatusCode message:(NSString*) aMessage error:(NSError*) aError
{
    if (delegate)
    {
        [delegate didClose:aStatusCode message:aMessage error:aError];
    }
}

- (void) dispatchOpened 
{
    if (delegate) 
    {
        [delegate didOpen];
    }
}

- (void) dispatchTextMessageReceived:(NSString*) aMessage 
{
    if (delegate)
    {
        [delegate didReceiveTextMessage:aMessage];
    }
}

- (void) dispatchBinaryMessageReceived:(NSData*) aMessage 
{
    if (delegate)
    {
        [delegate didReceiveBinaryMessage:aMessage];
    }
}


#pragma mark AsyncSocket Delegate
- (void) onSocketDidDisconnect:(AsyncSocket*) aSock 
{
    readystate = WebSocketReadyStateClosed;
    if (self.config.version > WebSocketVersion07)
    {
        if (closeStatusCode == 0)
        {
            if (closingError != nil)
            {
                closeStatusCode = WebSocketCloseStatusAbnormalButMissingStatus;
            }
            else
            {
                closeStatusCode = WebSocketCloseStatusNormalButMissingStatus;
            }
        }
    }
    [self dispatchClosed:closeStatusCode message:closeMessage error:closingError];
}

- (void) onSocket:(AsyncSocket *) aSocket willDisconnectWithError:(NSError *) aError
{
    switch (self.readystate) 
    {
        case WebSocketReadyStateOpen:
        case WebSocketReadyStateConnecting:
            readystate = WebSocketReadyStateClosing;
            [self dispatchFailure:aError];
        case WebSocketReadyStateClosing:
            closingError = [aError retain]; 
    }
}

- (void) onSocket:(AsyncSocket*) aSocket didConnectToHost:(NSString*) aHost port:(UInt16) aPort 
{
    //start TLS if this is a secure websocket
    if (self.config.isSecure)
    {
        // Configure SSL/TLS settings
        NSDictionary *settings = self.config.tlsSettings;
        
        //seed with defaults if missing
        if (!settings)
        {
            settings = [NSMutableDictionary dictionaryWithCapacity:3];
        }
        
        [socket startTLS:settings];
    }
    
    //continue with handshake
    NSString *requestPath = self.config.url.path;
    if (self.config.url.query) 
    {
        requestPath = [requestPath stringByAppendingFormat:@"?%@", self.config.url.query];
    }
    NSString* getRequest = [self getRequest: requestPath];
    [aSocket writeData:[getRequest dataUsingEncoding:NSASCIIStringEncoding] withTimeout:self.config.timeout tag:TagHandshake];
}

- (void) onSocket:(AsyncSocket*) aSocket didWriteDataWithTag:(long) aTag 
{
    if (aTag == TagHandshake) 
    {
        [aSocket readDataToData:[@"\r\n\r\n" dataUsingEncoding:NSASCIIStringEncoding] withTimeout:self.config.timeout tag:TagHandshake];
    }
}

- (void) onSocket: (AsyncSocket*) aSocket didReadData:(NSData*) aData withTag:(long) aTag {
    if (aTag == TagHandshake) {
        NSString* response = [[[NSString alloc] initWithData:aData encoding:NSASCIIStringEncoding] autorelease];
        if ([self isUpgradeResponse: response]) {
            //grab protocol from server
            HandshakeHeader* header = [self headerForKey:@"Sec-WebSocket-Protocol" inHeaders:self.config.serverHeaders];
            if (header){
                self.config.serverProtocol = header.value;
            }
            
            //grab extensions from the server
            NSMutableArray* extensions = [self getServerExtensions:self.config.serverHeaders];
            if (extensions){
                self.config.serverExtensions = extensions;
            }
            
            //handle state & delegates
            readystate = WebSocketReadyStateOpen;
            [self dispatchOpened];
            [self continueReadingMessageStream];
        } else {
            [self dispatchFailure:[NSError errorWithDomain:WebSocketErrorDomain code:0 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Bad handshake", NSLocalizedDescriptionKey, response, NSLocalizedFailureReasonErrorKey, nil]]];
        }
    } else if (aTag == TagMessage) {        
        //handle data
        [self handleMessageData:aData];

        //keep reading
        [self continueReadingMessageStream];
    }
}


#pragma mark Lifecycle
+ (id) webSocketWithConfig:(RSWebSocketConnectConfig*) aConfig delegate:(id<RSWebSocketDelegate>) aDelegate
{
    return [[[[self class] alloc] initWithConfig:aConfig delegate:aDelegate] autorelease];
}

- (id) initWithConfig:(RSWebSocketConnectConfig*) aConfig delegate:(id<RSWebSocketDelegate>) aDelegate
{
    self = [super init];
    if (self) 
    {
        //apply properties
        self.delegate = aDelegate;
        self.config = aConfig;
        socket = [[AsyncSocket alloc] initWithDelegate:self];
        pendingFragments = [[MutableQueue alloc] init];
        isClosing = NO;
    }
    return self;
}

-(void) dealloc 
{
    socket.delegate = nil;
    [socket disconnect];
    [socket release];
    [delegate release];
    [closingError release];
    [pendingFragments release];
    [closeMessage release];
    [wsSecKey release];
    [wsSecKeyHandshake release];
    [config release];
    [super dealloc];
}

@end

