//
//  WebSocketFragment.m
//  UnittWebSocketClient
//
//  Created by Josh Morris on 6/12/11.
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

#import "RSWebSocketFragment.h"

#ifndef htonll
#define htonll(x) __DARWIN_OSSwapInt64(x) 
#endif

#ifndef ntohll
#define ntohll(x) __DARWIN_OSSwapInt64(x) 
#endif

@implementation RSWebSocketFragment

@synthesize isFinal;
@synthesize mask;
@synthesize opCode;
@synthesize payloadData;
@synthesize payloadType;
@synthesize fragment;
@synthesize messageLength;


#pragma mark Properties
- (BOOL) hasMask
{
    return self.mask != 0;
}

- (int) generateMask
{
    return arc4random();
}

- (BOOL) isControlFrame
{
    return self.opCode == MessageOpCodeClose || self.opCode == MessageOpCodePing || self.opCode == MessageOpCodePong;
}

- (BOOL) isDataFrame
{
    return self.opCode == MessageOpCodeContinuation || self.opCode == MessageOpCodeText || self.opCode == MessageOpCodeBinary;
}

- (BOOL) isValid {
    if (self.messageLength > 0) {
        return payloadStart + payloadLength == [fragment length];
    }
    
    return NO;
}

- (BOOL) canBeParsed {
    if (self.messageLength > 0) {
        return [fragment length] >= (payloadStart + payloadLength);
    }
    
    return NO;
}

- (BOOL) isHeaderValid
{
    return payloadStart;
}

- (BOOL) isDataValid
{
    return self.payloadData && [self.payloadData length];
}

- (NSUInteger) messageLength
{
    if (fragment && payloadStart) 
    {
        return payloadStart + payloadLength;
    }
    
    return 0;
}


#pragma mark Parsing
- (void) parseContent {
    if ([self.fragment length] >= payloadStart + payloadLength) {
        //set payload
        if (self.hasMask) {
            self.payloadData = [self unmask:self.mask data:self.fragment range:NSMakeRange(payloadStart, payloadLength)];
        } else {
            self.payloadData = [self.fragment subdataWithRange:NSMakeRange(payloadStart, payloadLength)];
        }
        
        //trim fragment, if necessary
        if ([self.fragment length] > self.messageLength) {
            self.fragment = [NSMutableData dataWithData:[self.fragment subdataWithRange:NSMakeRange(0, self.messageLength)]];
        }
    }
}

- (void) parseHeader
{
    //get header data bits
    NSUInteger bufferLength = 14;
    if ([self.fragment length] < bufferLength)
    {
        bufferLength = [self.fragment length];
    }
    unsigned char buffer[bufferLength];
    [self.fragment getBytes:&buffer length:bufferLength];
    
    //determine opcode
    if (bufferLength > 0) 
    {
        int index = 0;
        self.isFinal = buffer[index] & 0x80;
        self.opCode = buffer[index++] & 0x0F;
        
        //handle data depending on opcode
        switch (self.opCode) 
        {
            case MessageOpCodeText:
                self.payloadType = PayloadTypeText;
                break;
            case MessageOpCodeBinary:
                self.payloadType = PayloadTypeBinary;
                break;
        }
        
        //handle content, if any     
        if (bufferLength > 1)
        {
            //do we have a mask
            BOOL hasMask = buffer[index] & 0x80;
            
            //get payload length
            unsigned long long dataLength = buffer[index++] & 0x7F;
            if (dataLength == 126)
            {
                //exit if we are missing bytes
                if (bufferLength < 4)
                {
                    return;
                }
                
                unsigned short len;
                memcpy(&len, &buffer[index], sizeof(len));
                index += sizeof(len);
                dataLength = ntohs(len);
            }
            else if (dataLength == 127)
            {
                //exit if we are missing bytes
                if (bufferLength < 10)
                {
                    return;
                }
                
                unsigned long long len;
                memcpy(&len, &buffer[index], sizeof(len));
                index += sizeof(len);
                dataLength = ntohll(len);                   
            }
            
            //if applicable, set mask value
            if (hasMask)
            {              
                //exit if we are missing bytes
                if (bufferLength < index + 4)
                {
                    return;
                }
                
                //grab mask
                self.mask = buffer[index] << 24 | buffer[index+1] << 16 | buffer[index+2] << 8 | buffer[index+3];
                index += 4;
            }
            
            payloadStart = index;
            payloadLength = dataLength;
        }
    }
}

- (void) buildFragment {
    NSMutableData* temp = [NSMutableData data];
    
    //build fin & reserved
    unsigned char byte = 0x0;
    if (self.isFinal) {
        byte = 0x80;
    }
    
    //build opmask
    byte = byte | (self.opCode & 0xF);
    
    //push first byte
    [temp appendBytes:&byte length:1];
    
    //use mask
    byte = 0x80;
    
    //payload length
    unsigned long long fullPayloadLength = [self.payloadData length];
    if (fullPayloadLength <= 125) {
        byte |= (fullPayloadLength & 0xFF);
        [temp appendBytes:&byte length:1];
    } else if (fullPayloadLength <= UINT16_MAX) {
        byte |= 126;
        [temp appendBytes:&byte length:1];
        short shortLength = htons(fullPayloadLength & 0xFFFF);
        [temp appendBytes:&shortLength length:2];
    } else if (fullPayloadLength <= UINT64_MAX) {
        byte |= 127;
        [temp appendBytes:&byte length:1];
        unsigned long long longLength = htonll(fullPayloadLength);
        [temp appendBytes:&longLength length:8];
    }
    
    //mask
    unsigned char maskBytes[4];
    maskBytes[0] = (int)((self.mask >> 24) & 0xFF) ;
    maskBytes[1] = (int)((self.mask >> 16) & 0xFF) ;
    maskBytes[2] = (int)((self.mask >> 8) & 0XFF);
    maskBytes[3] = (int)((self.mask & 0XFF));
    [temp appendBytes:maskBytes length:4];
    
    //payload data
    payloadStart = [temp length];
    payloadLength = fullPayloadLength;
    [temp appendData:[self mask:self.mask data:self.payloadData]];
    self.fragment = temp;
}

- (NSData*) mask:(int) aMask data:(NSData*) aData
{
    return [self mask:aMask data:aData range:NSMakeRange(0, [aData length])];
}

- (NSData*) mask:(int) aMask data:(NSData*) aData range:(NSRange) aRange
{
    NSMutableData* result = [NSMutableData data];
    unsigned char maskBytes[4];
    maskBytes[0] = (int)((aMask >> 24) & 0xFF) ;
    maskBytes[1] = (int)((aMask >> 16) & 0xFF) ;
    maskBytes[2] = (int)((aMask >> 8) & 0XFF);
    maskBytes[3] = (int)((aMask & 0XFF));
    unsigned char current;
    NSUInteger index = aRange.location;
    NSUInteger end = aRange.location + aRange.length;
    if (end > [aData length])
    {
        end = [aData length];
    }
    int m = 0;
    NSRange range = NSMakeRange(index, 1);
    while (index < end) 
    {
        //set current byte
        range.location = index;
        [aData getBytes:&current range:range];
        
        //mask
        current ^= maskBytes[m++ % 4];
        
        //append result & continue
        [result appendBytes:&current length:1];
        index++;
    }
    return result;
}

- (NSData*) unmask:(int) aMask data:(NSData*) aData
{
    return [self unmask:aMask data:aData range:NSMakeRange(0, [aData length])];
}

- (NSData*) unmask:(int) aMask data:(NSData*) aData range:(NSRange) aRange
{
    return [self mask:aMask data:aData range:aRange];
}


#pragma mark Lifecycle
+ (id) fragmentWithOpCode:(MessageOpCode) aOpCode isFinal:(BOOL) aIsFinal payload:(NSData*) aPayload 
{
    id result = [[[self class] alloc] initWithOpCode:aOpCode isFinal:aIsFinal payload:aPayload];
    
    return [result autorelease];
}

+ (id) fragmentWithData:(NSData*) aData
{
    id result = [[[self class] alloc] initWithData:aData];
    
    return [result autorelease];
}

- (id) initWithOpCode:(MessageOpCode) aOpCode isFinal:(BOOL) aIsFinal payload:(NSData*) aPayload
{
    self = [super init];
    if (self)
    {
        self.mask = [self generateMask];
        self.opCode = aOpCode;
        self.isFinal = aIsFinal;
        self.payloadData = aPayload;
        [self buildFragment];
    }
    return self;
}

- (id) initWithData:(NSData*) aData {
    self = [super init];
    if (self)
    {
        self.opCode = MessageOpCodeIllegal;
        self.fragment = [NSMutableData dataWithData:aData];
        [self parseHeader];
        if (self.messageLength <= [aData length])
        {
            [self parseContent];
        }
    }
    return self;
}

- (id) init {
    self = [super init];
    if (self)
    {
        self.opCode = MessageOpCodeIllegal;
    }
    return self;
}

- (void) dealloc {
    [payloadData release];
    [fragment release];
    
    [super dealloc];
}

@end
