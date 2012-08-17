//
//  RSWebSocket.m
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


#import "RSWebSocket.h"
#import "RSWebSocketFragment.h"
#import "HandshakeHeader.h"
#import "UTF8Decoder.h"

@interface RSWebSocket(Private)
- (void) dispatchFailure:(NSError*) aError;
- (void) dispatchClosed;
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
- (NSData *) handleFrameData:(NSData*) aData;
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

@synthesize config;
@synthesize delegate;
@synthesize readystate;

#pragma mark Public Interface
- (BOOL) isConnectionOpen {
    return [socket isConnected];
}

- (void) open {
    UInt16 port = self.config.isSecure ? 443 : 80;
    if (self.config.url.port) port = [self.config.url.port intValue];
    BOOL successful = false;
    closingStatusError = nil;
    closingStatusLocalCode = 0;
    closingStatusLocalMessage = nil;
    closingStatusRemoteCode = 0;
    closingStatusRemoteMessage = nil;
    NSError *tempCloseStatus;
    
    @try {
        successful = [socket connectToHost:self.config.url.host onPort:port error:&tempCloseStatus];
        closingStatusError = tempCloseStatus;
    } @catch (NSException *exception) {
        closingStatusError = [NSError errorWithDomain:WebSocketErrorDomain code:0 userInfo:exception.userInfo]; 
    } @finally {
        if (!successful) {
            closingStatusLocalCode = WebSocketCloseStatusProtocolError;
            [self dispatchClosed];
        }
    }
}

- (void) close {
    [self close:WebSocketCloseStatusNormal message:nil];
}

- (void) close:(NSUInteger) aStatusCode message:(NSString*) aMessage {
    readystate = WebSocketReadyStateClosing;
    if (aMessage && [aMessage canBeConvertedToEncoding:NSUTF8StringEncoding]) {
        [self sendClose:aStatusCode message:aMessage];
    } else {
        [self sendClose:aStatusCode message:nil];
    }
    isClosing = YES;
    utf8validate_forcereset();
}

- (void) scheduleForceCloseCheck {
    [NSTimer scheduledTimerWithTimeInterval:self.config.closeTimeout
                                     target:self
                                   selector:@selector(checkClose:)
                                   userInfo:nil
                                    repeats:NO];
}

- (void) checkClose:(NSTimer*) aTimer {[self closeSocket];}

- (void) sendClose:(NSUInteger) aStatusCode message:(NSString*) aMessage {
    NSMutableData* payload = nil;
    payload = [NSMutableData data];
    unsigned char current;
    
    if (aStatusCode >= 1000) { // Status codes 0-999 are not used.
        closingStatusLocalCode = aStatusCode;
        
        current = (unsigned char)(aStatusCode/0x100);
        [payload appendBytes:&current length:1];
        
        current = (unsigned char)(aStatusCode%0x100);
        [payload appendBytes:&current length:1];

        if (aMessage) {
            closingStatusLocalMessage = aMessage;
            [payload appendData:[aMessage dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    
    //send close message
    [self sendMessage:[RSWebSocketFragment fragmentWithOpCode:MessageOpCodeClose isFinal:YES payload:payload mask:YES]];
    
    //schedule the force close
    if (self.config.closeTimeout >= 0) {
        [self scheduleForceCloseCheck];
    }
}

- (void) sendText:(NSString*) aMessage {    
    //no reason to grab data if we won't send it anyways
    if (!isClosing) {       
        //only send non-nil data
        if (aMessage) {
            if ([aMessage canBeConvertedToEncoding:NSUTF8StringEncoding]) {
                [self sendMessage:[aMessage dataUsingEncoding:NSUTF8StringEncoding] messageWithOpCode:MessageOpCodeText];       
            } else {
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
            RSWebSocketFragment* fragment = [RSWebSocketFragment fragmentWithOpCode:aOpCode isFinal:YES payload:aMessage mask:YES];
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
                    fragment = [RSWebSocketFragment fragmentWithOpCode:aOpCode isFinal:NO payload:[aMessage subdataWithRange:NSMakeRange(i * self.config.maxPayloadSize, fragmentLength)] mask:YES];
                } else if (i == fragmentCount - 1) {
                    fragmentLength = messageLength % self.config.maxPayloadSize;
                    if (fragmentLength == 0) {
                        fragmentLength = self.config.maxPayloadSize;
                    }
                    fragment = [RSWebSocketFragment fragmentWithOpCode:MessageOpCodeContinuation isFinal:YES payload:[aMessage subdataWithRange:NSMakeRange(i * self.config.maxPayloadSize, fragmentLength)] mask:YES];
                } else {
                    fragment = [RSWebSocketFragment fragmentWithOpCode:MessageOpCodeContinuation isFinal:NO payload:[aMessage subdataWithRange:NSMakeRange(i * self.config.maxPayloadSize, fragmentLength)] mask:YES];
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

- (void) sendMessage:(RSWebSocketFragment*) aFragment {
//    NSLog(@"Before sending pausing");
    
    if (!isClosing || aFragment.opCode == MessageOpCodeClose) {
        [socket writeData:aFragment.fragment withTimeout:self.config.timeout tag:TagMessage];
    }
}


#pragma mark Internal Web Socket Logic
- (void) continueReadingMessageStream {
    [socket readDataWithTimeout:self.config.timeout tag:TagMessage];
}

- (void) closeSocket {
    readystate = WebSocketReadyStateClosing;
    [socket disconnectAfterWriting];
}

- (void) handleCompleteFragment:(RSWebSocketFragment*) aFragment {    
    //continue to process
    switch (aFragment.opCode)  {
        case MessageOpCodeContinuation:
        {
            if (contstate == WebSocketContinuationInProgress && aFragment.isFinal) {
                // Final state opcode zero, final bit set
                // Change of state before handling fragment is necessary
                contstate = WebSocketContinuationNone;
                [self handleCompleteFragments];
            } else if (contstate == WebSocketContinuationNone) {
                [self close:WebSocketCloseStatusProtocolError
                    message:@"Bad frame continuation, closing"];
            }

            // Else we are in continuation state with fin still clear.
        }
            break;
        case MessageOpCodeText:
        {
            if (contstate == WebSocketContinuationNone && aFragment.isFinal) {
                if (aFragment.payloadData.length) {
                    NSString* textMsg = [[NSString alloc] initWithData:aFragment.payloadData encoding:NSUTF8StringEncoding];

                    if (textMsg) {
                        [self dispatchTextMessageReceived:textMsg];
                    } else {
                        [self close:WebSocketCloseStatusInvalidUtf8 message:nil];
                    }
                } else {
                    NSString* textMsg = [[NSString alloc] initWithUTF8String:""];
                    [self dispatchTextMessageReceived:textMsg];
                }
            } else if (contstate == WebSocketContinuationNone && !aFragment.isFinal) {
                contstate = WebSocketContinuationInProgress;
            } else {
                [self close:WebSocketCloseStatusProtocolError 
                    message:@"All data frames after the initial data frame must have opcode 0"];
            }                
        }
            break;
        case MessageOpCodeBinary:
        {
            if (contstate == WebSocketContinuationNone && aFragment.isFinal) {
                [self dispatchBinaryMessageReceived:aFragment.payloadData];
            } else if (contstate == WebSocketContinuationNone && !aFragment.isFinal) {
                contstate = WebSocketContinuationInProgress;
            } else {
                [self close:WebSocketCloseStatusProtocolError 
                    message:@"All data frames after the initial data frame must have opcode 0"];
            }            
        }
            break;
        case MessageOpCodeClose:
        {
            [self handleClose:aFragment];
        }
            break;
        case MessageOpCodePing:
        {
            [self handlePing:aFragment.payloadData];
        }
            break;
        case MessageOpCodePong:
        {
            // handle Pong frame in some way?
            // A response to an unsolicited Pong frame is not expected.
            // A Pong frame sent in response to a Ping frame must have identical
            // "Application data" as found in the message body of the Ping frame
            // being replied to.
            NSLog(@"We got a pong. Now what?");
        }
            break;
    }
}

- (void) handleCompleteFragments {    
    NSMutableData* messageData = [NSMutableData data];
    RSWebSocketFragment* fragment = [pendingFragments dequeue];
    
    if (fragment != nil) {
        MessageOpCode messageOpCode = fragment.opCode;
        //loop through, constructing single message
        
        while (fragment != nil) {
            // FIXME: What mechanism requires us to check for control frames here? They seem to be handled above first, but 
            // not dequeued?
            if (!fragment.isControlFrame)
                [messageData appendData:fragment.payloadData];
            fragment = [pendingFragments dequeue];
        }

        fragment = [RSWebSocketFragment fragmentWithOpCode:messageOpCode isFinal:YES payload:messageData mask:YES];
        [self handleCompleteFragment: fragment];
    }
}

- (void) handleClose:(RSWebSocketFragment*) aFragment {
    if (isClosing) {
        [self closeSocket];
        return;
    } else {
        isClosing = YES;
    
        NSUInteger length = aFragment.payloadData.length;
        if (length > 1) {
            //get status code
            unsigned char buffer[2];
            [aFragment.payloadData getBytes:&buffer length:2];
            closingStatusRemoteCode = buffer[0] << 8 | buffer[1];
            
            switch (closingStatusRemoteCode) {
                case 1004:
                case 1005:
                case 1006:
                case 1012:
                case 1013:
                case 1014:
                case 1015:
                case 1016:
                case 1100:
                case 2000:
                case 2999:
                {
                    [self close:WebSocketCloseStatusProtocolError message:nil];
                }
                    return;
                default:
                {
                    //get message
                    if (length > 2) {
                        closingStatusRemoteMessage = [[NSString alloc] initWithData:[aFragment.payloadData subdataWithRange:NSMakeRange(2, length - 2)] encoding:NSUTF8StringEncoding];
                        if (!closingStatusRemoteMessage) {
                            [self close:WebSocketCloseStatusInvalidUtf8 message:nil];
                            return;
                        }
                    }
                }
            }
        }
        
        [self close:closingStatusRemoteCode message:nil]; // Send the remote code back
        return;
    }
}

- (void) handlePing:(NSData*) aMessage {
    // FIXME: Debug
//    NSLog(@"Handling ping");

    if (!isClosing) {
        [self sendMessage:aMessage messageWithOpCode:MessageOpCodePong];
    
        if ([delegate respondsToSelector:@selector(didSendPong:)]) {
            [delegate didSendPong:aMessage];
        }
    }
}

- (void) handleFrameDataNew {
//    NSLog(@"handleFrameDataNew");
    // Make a new, empty frame fragment. fragment is expected to be nil.
    RSWebSocketFragment *fragment = [RSWebSocketFragment fragment]; 
    [pendingFragments enqueue:fragment];
    framestate = WebSocketFramePriHeaderFilling;
    utf8validate_reset();
}

- (NSData *) handleFrameDataPrimaryHeaderFill: (NSData *)aData {
//    NSLog(@"handleFrameDataPrimaryHeaderFill");
    RSWebSocketFragment *fragment = [pendingFragments lastObject]; // Grab last fragment; use if not complete
    NSUInteger needToConsume = 0; // Important it stays at zero.

    // 7-bit payload length specified within first 2 bytes of (primary) header
    if (fragment.fragment.length < 2 && [aData length] >= 1) {
        if      (fragment.fragment.length == 0) needToConsume = ([aData length] <= 1) ? 1 : 2;
        else if (fragment.fragment.length == 1) needToConsume = 1;
        else NSLog(@"handleFrameDataPrimaryHeaderFill: What state are we in here?");
        [fragment.fragment appendData: [aData subdataWithRange:NSMakeRange(0, needToConsume)]];
    }

    if (fragment.fragment.length == 2) {
        [fragment parseHeader]; // Re-parse frame
        framestate = WebSocketFrameExtHeaderFilling;
    }
    
    return (needToConsume >= [aData length]) ? nil:[aData subdataWithRange:NSMakeRange(needToConsume, [aData length] - needToConsume)];
}

- (NSData *) handleFrameDataExtendedHeaderFill: (NSData *) aData {
//    NSLog(@"handleFrameDataExtendedHeaderFill");
    RSWebSocketFragment *fragment = [pendingFragments lastObject]; // Grab last fragment; use if not complete

    NSUInteger needToConsume = 0; // Important it initializes to zero.

    if (fragment.payloadLength == 127 && fragment.fragment.length < 10) {
        // 64-bit payload length specified within first 10 bytes of header
        needToConsume = 10 - fragment.fragment.length;
    } else if (fragment.payloadLength == 126 && fragment.fragment.length < 4) {
        // 16-bit payload length specified within first 4 bytes of header
        needToConsume = 4 - fragment.fragment.length;
    } else if (fragment.payloadLength <= 125) {
        needToConsume = 0;
    } else {
//        NSLog(@"handleFrameDataExtendedHeaderFill: What state are we in here?");
//        NSLog(@"Error: WebSocketCloseStatusProtocolError during frame extended header construction");
//        [self close:WebSocketCloseStatusProtocolError message:nil];
//        return nil; // Failure condition, return immediately.
    }

    needToConsume = (needToConsume > [aData length]) ? [aData length] : needToConsume;

    if (needToConsume == 0) {
        if (![fragment isHeaderValid]) 
            [self close:WebSocketCloseStatusProtocolError message:nil];
        [fragment parseHeader]; // Re-parse frame
        framestate = WebSocketFrameDataFilling;
    } else {           
        [fragment.fragment appendData: [aData subdataWithRange:NSMakeRange(0, needToConsume)]];
    }
    return (needToConsume >= [aData length]) ? nil:[aData subdataWithRange:NSMakeRange(needToConsume, [aData length] - needToConsume)];
}



- (NSData *) handleFrameDataPayloadFill: (NSData *) aData {
    RSWebSocketFragment *fragment = [pendingFragments lastObject]; // Grab last fragment; use if not complete
    RSWebSocketFragment *fragmentFirst = [pendingFragments firstObject]; // Grab first fragment; use if not complete
    NSData *aSubData;
    NSUInteger needToConsume = 0; // Important it stays at zero.
    
    if (fragment && !fragment.isFrameComplete) {
        needToConsume = fragment.messageLength - fragment.fragment.length;
        needToConsume = (needToConsume > [aData length]) ? [aData length] : needToConsume;
        aSubData = [aData subdataWithRange:NSMakeRange(0, needToConsume)];
        [fragment.fragment appendData:aSubData];
    }
        
    // Special case, fast-fail on invalid UTF-8 substrings
    if (fragmentFirst.opCode == MessageOpCodeText && (fragment.opCode == MessageOpCodeContinuation || fragment.opCode == MessageOpCodeText) &&
        utf8validate((uint8_t *)[aData bytes], needToConsume)) {
//        printf("The UTF-8 string is malformed\n");
        [self close:WebSocketCloseStatusInvalidUtf8 message:nil];
        return nil;
    }
    
    if (fragment && fragment.isFrameComplete) {
        framestate = WebSocketFrameComplete;
    }
    
    return (needToConsume >= [aData length]) ? nil:[aData subdataWithRange:NSMakeRange(needToConsume, [aData length] - needToConsume)];
}

- (void) handleFrameDataComplete {
//    NSLog(@"handleFrameDataComplete\n");
    RSWebSocketFragment *fragment = [pendingFragments lastObject]; // Grab last fragment; use if not complete

    if (fragment.canBeParsed) [fragment parseContent];
    else NSLog(@"Error: Parsing error of frame during final frame construction");

    if (fragment.isValid) {
        framestate = WebSocketFrameComplete;
        if (isClosing && fragment.opCode != MessageOpCodeClose) {
            NSLog(@"Frame opcode: %ld", fragment.opCode);
            NSLog(@"Error: WebSocket closing during final frame construction");
            return; // Failure condition, return immediately.
        }
        [self handleCompleteFragment:fragment];
    } else {
        NSLog(@"Error: WebSocketCloseStatusProtocolError during final frame construction");
        [self close:WebSocketCloseStatusProtocolError message:nil];
    }
    framestate = WebSocketFrameNew;
}

- (NSData *) handleFrameData:(NSData*) aData {
    while (aData && !isClosing) {
        if (framestate == WebSocketFrameNew) [self handleFrameDataNew];
        
        if (framestate == WebSocketFramePriHeaderFilling)
            aData = [self handleFrameDataPrimaryHeaderFill: aData];
        
        if (framestate == WebSocketFrameExtHeaderFilling)
            aData =  [self handleFrameDataExtendedHeaderFill: aData];
        
        if (framestate == WebSocketFrameDataFilling)
            aData = [self handleFrameDataPayloadFill: aData];
        
        if (framestate == WebSocketFrameComplete) [self handleFrameDataComplete];
    }
    
    return aData;
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

- (NSString*) getRequest: (NSString*) aRequestPath {
    //create headers if they are missing
    NSMutableArray* headers = self.config.headers;
    if (headers == nil) {
        self.config.headers = headers = [NSMutableArray array];
    }
    
    //handle security keys
    [self generateSecKeys];
    [headers addObject:[HandshakeHeader headerWithValue:wsSecKey forKey:@"Sec-WebSocket-Key"]];
    
    //handle host
    [headers addObject:[HandshakeHeader headerWithValue:self.config.host forKey:@"Host"]];
    
    //handle origin
    [headers addObject:[HandshakeHeader headerWithValue:self.config.origin forKey:@"Sec-WebSocket-Origin"]];
    
    //handle version
    [headers addObject:[HandshakeHeader headerWithValue:[NSString stringWithFormat:@"%li",self.config.version] forKey:@"Sec-WebSocket-Version"]];
    
    //handle protocol
    if (self.config.protocols && self.config.protocols.count > 0) {
        //build protocol fragment
        NSMutableString* protocolFragment = [NSMutableString string];
        for (NSString* item in self.config.protocols) {
            if ([protocolFragment length] > 0) {
                [protocolFragment appendString:@", "];
            }
            [protocolFragment appendString:item];
        }
        
        //include protocols, if any
        if ([protocolFragment length] > 0) {
            [headers addObject:[HandshakeHeader headerWithValue:protocolFragment forKey:@"Sec-WebSocket-Protocol"]];
        }
    }
    
    //handle extensions
    if (self.config.extensions && self.config.extensions.count > 0) {
        //build extensions fragment
        NSMutableString* extensionFragment = [NSMutableString string];
        for (NSString* item in self.config.extensions) {
            if ([extensionFragment length] > 0) {
                [extensionFragment appendString:@", "];
            }
            [extensionFragment appendString:item];
        }
        
        //return request with extensions
        if ([extensionFragment length] > 0) {
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

- (HandshakeHeader*) headerForKey:(NSString*) aKey inHeaders:(NSMutableArray*) aHeaders {
    for (HandshakeHeader* header in aHeaders)
        if (header && [header keyMatchesCaseInsensitiveString:aKey]) return header;
    return nil;
}

- (BOOL) isUpgradeResponse: (NSString*) aResponse {
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
- (void) dispatchFailure:(NSError*) aError {
    if(delegate) [delegate didReceiveError:aError];
}

- (void) dispatchClosed {    
    if (delegate) [delegate didClose:closingStatusError 
                           localCode:closingStatusLocalCode  
                        localMessage:closingStatusLocalMessage
                          remoteCode:closingStatusRemoteCode
                       remoteMessage:closingStatusRemoteMessage];
}

- (void) dispatchOpened {
    if (delegate) [delegate didOpen];
}

- (void) dispatchTextMessageReceived:(NSString*) aMessage {
    if (delegate) [delegate didReceiveTextMessage:aMessage];
}

- (void) dispatchBinaryMessageReceived:(NSData*) aMessage {
    if (delegate)[delegate didReceiveBinaryMessage:aMessage];
}


#pragma mark AsyncSocket Delegate
- (void) onSocketDidDisconnect:(AsyncSocket*) aSock {
    readystate = WebSocketReadyStateClosed;
    if (closingStatusLocalCode == 0) {
        if (!isClosing) {
                closingStatusLocalCode = WebSocketCloseStatusAbnormalButMissingStatus;
        } else {
                closingStatusLocalCode = WebSocketCloseStatusNormalButMissingStatus;
        }
    }
    [self dispatchClosed];
}

- (void) onSocket:(AsyncSocket *) aSocket willDisconnectWithError:(NSError *) aError {
    switch (self.readystate) {
        case WebSocketReadyStateOpen:
        case WebSocketReadyStateConnecting:
        {
            readystate = WebSocketReadyStateClosing;
            [self dispatchFailure:aError];
        }
        case WebSocketReadyStateClosing:
        {
            closingStatusError = aError;
        }
    }

}

- (void) onSocket:(AsyncSocket*) aSocket didConnectToHost:(NSString*) aHost port:(UInt16) aPort {
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
    if (self.config.url.query) {
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
        NSString* response = [[NSString alloc] initWithData:aData encoding:NSASCIIStringEncoding];
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
        
        framestate = WebSocketFrameNew; // We set our initial frame state to 'new'.
    } else if (aTag == TagMessage) {
        [self handleFrameData:aData];
        //keep reading
        [self continueReadingMessageStream];
    }
}


#pragma mark Lifecycle
+ (id) webSocketWithConfig:(RSWebSocketConnectConfig*) aConfig delegate:(id<RSWebSocketDelegate>) aDelegate
{
    return [[[self class] alloc] initWithConfig:aConfig delegate:aDelegate];
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

-(void) dealloc {
    socket.delegate = nil;
    [socket disconnect];
}

@end

