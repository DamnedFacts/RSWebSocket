//
//  WebSocketFragment.m
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

#import "RSWebSocketFragment.h"

#define WS_PAYLOAD_OFFSET 14 // 14 bytes offset in header to get to the payload data

#ifndef htonll
#define htonll(x) __DARWIN_OSSwapInt64(x) 
#endif

#ifndef ntohll
#define ntohll(x) __DARWIN_OSSwapInt64(x) 
#endif

MessageOpCode opcode_control[] =   {
    MessageOpCodeClose,
    MessageOpCodePing,
    MessageOpCodePong,
    MessageOpCodeReserved6, 
    MessageOpCodeReserved7, 
    MessageOpCodeReserved8, 
    MessageOpCodeReserved9, 
    MessageOpCodeReserved10};


MessageOpCode opcode_noncontrol[] = {
    MessageOpCodeText,
    MessageOpCodeBinary,
    MessageOpCodePong,
    MessageOpCodeReserved1,
    MessageOpCodeReserved2,
    MessageOpCodeReserved3,
    MessageOpCodeReserved4,
    MessageOpCodeReserved5};

@implementation RSWebSocketFragment

// Start Header
@synthesize isFinal;
@synthesize hasRSV1;
@synthesize hasRSV2;
@synthesize hasRSV3;
@synthesize opCode;
@synthesize hasMask;
@synthesize messageLength;
@synthesize mask;
@synthesize payloadData;
@synthesize payloadLength;
@synthesize payloadLengthExtended;
@synthesize fullPayloadLength;
@synthesize opCodeType;

// End Header
@synthesize fragment;
@synthesize isFrameComplete;

#pragma mark Properties
- (BOOL) hasMask {
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

- (BOOL) isFrameComplete {
    return (self.messageLength == [fragment length]);
}

- (BOOL) isValid {
    if (self.messageLength > 0) {
        BOOL isValidState = TRUE;
        isValidState &=  (self.messageLength <= [fragment length]);
        isValidState = [self isHeaderValid];
        return isValidState;
    }
    
    return NO;
}

- (BOOL) canBeParsed {
    if (self.messageLength > 0) {
        return self.messageLength <= [fragment length];
    }
    
    return NO;
}


- (BOOL) isHeaderValid {
    BOOL isValidState = NO;

    if ([fragment length] >= 2) { 
        isValidState = YES;
        // A frame header needs at minimum two bytes to before we can describe the payload size.
         

        isValidState &= !hasRSV1; // FIXME This state can be valid if negotiated by an extension.
        isValidState &= !hasRSV2; // FIXME This state can be valid if negotiated by an extension.
        isValidState &= !hasRSV3; // FIXME This state can be valid if negotiated by an extension.
        
        // FIXME check that we receive a valid opcode
        switch (self.opCode) {
            case MessageOpCodeContinuation:
                break;
            case MessageOpCodeText:
                break;
            case MessageOpCodeBinary:
                break;
            case MessageOpCodeClose:;
            case MessageOpCodePing:
            case MessageOpCodePong:
                if (payloadLength > 125) isValidState &= FALSE; // Pings must not be > 125 bytes.
                if (!isFinal) isValidState &= FALSE; // Pings must not be fragmented.
                break;
            case MessageOpCodeReserved1:
            case MessageOpCodeReserved2:
            case MessageOpCodeReserved3:
            case MessageOpCodeReserved4:
            case MessageOpCodeReserved5:
            case MessageOpCodeReserved6:
            case MessageOpCodeReserved7:
            case MessageOpCodeReserved8:
            case MessageOpCodeReserved9:
            case MessageOpCodeReserved10:
                isValidState &= FALSE; // Autobahn tests that we fail on reserved opcodes.
                break;
            default:
                isValidState &= FALSE; // Unknown opcode
                break;
        }
        
        isValidState &= !self.hasMask;   // FIXME: This is only valid when we are a client. 
                                    // Clients do not receive masked packets.
    
        if (payloadLength == 126 && [fragment length] < 4) { 
            // 16-bit (2 bytes) extended payload length requires at least a 4 byte header.
            isValidState &= FALSE;
        } else if (payloadLength == 127 && [fragment length] < 10) {
            // 64-bit (8 bytes) extended payload length requires at least a 10 byte header.
            isValidState &= FALSE;
        }
    }
    return isValidState;
}

- (BOOL) isDataValid {
    return self.payloadData && [self.payloadData length];
}

- (NSUInteger) messageLength {
    if (fragment && payloadStart) {        
        return payloadStart + self.fullPayloadLength;
    }
    
    return 0;
}

- (unsigned long long) fullPayloadLength {
    if (fragment && payloadStart) {
        if  (payloadLength <= 125) 
            return  payloadLength;
        else if  (payloadLength == 126 || payloadLength == 127)
            return  payloadLengthExtended;
    }
    
    return 0;
}

#pragma mark Parsing
- (void) parseContent {
    if ([self canBeParsed]) {
        //set payload
        if (self.hasMask) {
            self.payloadData = [self unmask:self.mask data:self.fragment range:NSMakeRange(payloadStart, self.fullPayloadLength)];
        } else {
            self.payloadData = [self.fragment subdataWithRange:NSMakeRange(payloadStart, self.fullPayloadLength)];
        }
        
        //trim fragment, if necessary
        if ([self.fragment length] > self.messageLength) {
            self.fragment = [NSMutableData dataWithData:[self.fragment subdataWithRange:NSMakeRange(0, self.messageLength)]];
        }
    }
}

- (void) setOpCodeType {
    for (int i = 0; i < (sizeof opcode_control) / (sizeof opcode_control[0]); i++) {
        if (self.opCode == opcode_control[i]) { 
            self.opCodeType = OpCodeTypeControl;
            return;
        }
    }
    
    for (int i = 0; i < (sizeof opcode_control) / (sizeof opcode_control[0]); i++) {
        if (self.opCode == opcode_noncontrol[i]) {
            self.opCodeType = OpCodeTypeNonControl;
            return;
        }
    } 
    
    if (self.opCode == MessageOpCodeContinuation) {
        self.opCodeType = OpCodeTypeContinuation;
        return;
    }

    // If set to unknown, we have a problem.
    self.opCodeType = OpCodeTypeUnknown;
}

- (void) parseHeader {
    /***
     Base Framing for WebSocket Protocol
     
     0                   1                   2                   3
     0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
     +-+-+-+-+-------+-+-------------+-------------------------------+
     |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
     |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
     |N|V|V|V|       |S|             |   (if payload len==126/127)   |
     | |1|2|3|       |K|             |                               |
     +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
     |     Extended payload length continued, if payload len == 127  |
     + - - - - - - - - - - - - - - - +-------------------------------+
     |                               |Masking-key, if MASK set to 1  |
     +-------------------------------+-------------------------------+
     | Masking-key (continued)       |          Payload Data         |
     +-------------------------------- - - - - - - - - - - - - - - - +
     :                     Payload Data continued ...                :
     + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
     |                     Payload Data continued ...                |
     +---------------------------------------------------------------+
     ***/
    
    //get header data bits        
//    NSUInteger bufferLength =  WS_PAYLOAD_OFFSET;
//    if ([self.fragment length] < WS_PAYLOAD_OFFSET) {
//        bufferLength = [self.fragment length];
//    } 
    
    unsigned char *buffer = (unsigned char *) [self.fragment bytes];
    
    int index = 0;    
    
    self.isFinal  = (buffer[index] & (1 << 7)) >> 7;   // Test for Final frame bit
    self.hasRSV1  = (buffer[index] & (1 << 6)) >> 6;   // Test for Reserve bit 1
    self.hasRSV2  = (buffer[index] & (1 << 5)) >> 5;   // Test for Reserve bit 2
    self.hasRSV3  = (buffer[index] & (1 << 4)) >> 4;   // Test for Reserve bit 3
    self.opCode   = buffer[index++] & 0x0F; // Pull out Opcode, bits 4-7.
    self.hasMask  = (buffer[index] & (1 << 7)) >> 7;
    
    [self setOpCodeType];
    
    
    // We check the 7 bit data length field. Valid values:
    // 0 - 125: that is the payload length.  
    // 126:     the following 2 bytes interpreted as a
    //          16-bit unsigned integer are the payload length.
    // 127:     the following 8 bytes interpreted as a 64-bit unsigned integer
    payloadLength = buffer[index++] & 0x7F;
    
    // Multibyte length quantities are expressed in network byte order.
    // Therefore we switch them to our host byte order.
    if (payloadLength <= 125) {
        payloadLengthExtended = 0;
    } else if (payloadLength == 126) {            
            unsigned short len; // 16-bit value for data length
            memcpy(&len, &buffer[index], sizeof(len));
            index += sizeof(len);
            payloadLengthExtended = ntohs(len);
    } else if (payloadLength == 127) {
            unsigned long long len; // 64-bit value for data length
            memcpy(&len, &buffer[index], sizeof(len));
            index += sizeof(len);
            payloadLengthExtended = ntohll(len);                   
    }
        
    // If applicable, set masking key 
    // (we would be in a server mode receiving a client's masked packet if it were set).
    if (self.hasMask) {              
        self.mask = buffer[index] << 24 | buffer[index+1] << 16 | buffer[index+2] << 8 | buffer[index+3];
        index += 4;
    }

    // FIXME: Debug mode
//    if ([self.fragment length])
//        NSLog(@"Frame header [FIN: %d] [RSV1: %d] [RSV2: %d] [RSV3: %d] [Opcode: %ld] [Mask: %d] [Len: %lu] [LenExt: %llu]", isFinal,hasRSV1,hasRSV2,hasRSV3,opCode,hasMask, payloadLength, payloadLengthExtended);

    
    payloadStart = index;
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
    if (self.hasMask) byte = 0x80;
    else         byte = 0;
    
    //payload length
    NSUInteger payloadLen= [self.payloadData length];
    if (payloadLen <= 125) {
        byte |= (payloadLen & 0xFF);
        [temp appendBytes:&byte length:1];
    } else if (payloadLen <= UINT16_MAX) {
        byte |= 126;
        [temp appendBytes:&byte length:1];
        short shortLength = htons(payloadLen & 0xFFFF);
        [temp appendBytes:&shortLength length:2];
    } else if (payloadLen <= UINT64_MAX) {
        byte |= 127;
        [temp appendBytes:&byte length:1];
        unsigned long long longLength = htonll(payloadLen);
        [temp appendBytes:&longLength length:8];
    }
    

    //mask
    unsigned char maskBytes[4];
    if (self.hasMask) {
        maskBytes[0] = (int)((self.mask >> 24) & 0xFF) ;
        maskBytes[1] = (int)((self.mask >> 16) & 0xFF) ;
        maskBytes[2] = (int)((self.mask >> 8) & 0XFF);
        maskBytes[3] = (int)((self.mask & 0XFF));
        [temp appendBytes:maskBytes length:4];
    }
    

    //payload data
    payloadStart = [temp length];
    payloadLength = payloadLen;
    [temp appendData:[self mask:self.mask data:self.payloadData]];
    self.fragment = temp;
    
    [self setOpCodeType];
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
+ (id) fragmentWithOpCode:(MessageOpCode) aOpCode isFinal:(BOOL) aIsFinal payload:(NSData*) aPayload mask:(BOOL) setMask {
    id result = [[[self class] alloc] initWithOpCode:aOpCode isFinal:aIsFinal payload:aPayload mask:setMask];
    return [result autorelease];
}

+ (id) fragmentWithData:(NSData*) aData {
    id result = [[[self class] alloc] initWithData:aData];
    return [result autorelease];
}

- (id) initWithOpCode:(MessageOpCode)aOpCode isFinal:(BOOL)aIsFinal payload:(NSData*)aPayload mask:(BOOL)setMask {
    self = [super init];
    if (self) {
        if (setMask) self.mask = [self generateMask];
        else         self.mask = 0;
        self.opCode            = aOpCode;
        self.isFinal           = aIsFinal;
        self.payloadData       = aPayload;
        [self buildFragment];
    }
    return self;
}

- (id) initWithData:(NSData*) aData {
    self = [super init];
    if (self) {
        self.opCode = MessageOpCodeIllegal;
        self.fragment = [NSMutableData dataWithData:aData];

        [self parseHeader];
        
        if (self.messageLength <= [aData length]) [self parseContent];
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
