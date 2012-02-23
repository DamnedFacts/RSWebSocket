//
//  WebSocketFragment.h
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

#import <Foundation/Foundation.h>


enum 
{
    MessageOpCodeIllegal = -1,
    MessageOpCodeContinuation = 0x0,
    MessageOpCodeText = 0x1,
    MessageOpCodeBinary = 0x2,
    MessageOpCodeReserved1 = 0x3,
    MessageOpCodeReserved2 = 0x4,
    MessageOpCodeReserved3 = 0x5,
    MessageOpCodeReserved4 = 0x6,
    MessageOpCodeReserved5 = 0x7,
    MessageOpCodeClose = 0x8,
    MessageOpCodePing = 0x9,
    MessageOpCodePong = 0xA,
    MessageOpCodeReserved6 = 0xB,
    MessageOpCodeReserved7 = 0xC,
    MessageOpCodeReserved8 = 0xD,
    MessageOpCodeReserved9 = 0xE,
    MessageOpCodeReserved10 = 0xF
};
typedef NSInteger MessageOpCode;

enum 
{
    PayloadTypeUnknown = 0,
    PayloadTypeText = 1,
    PayloadTypeBinary = 2
};
typedef NSInteger PayloadType;

enum 
{
    PayloadLengthIllegal = -1,
    PayloadLengthMinimum = 0,
    PayloadLengthShort = 1,
    PayloadLengthLong = 2
};
typedef NSInteger PayloadLength;


@interface RSWebSocketFragment : NSObject {
    BOOL            isFinal;
    BOOL            hasRSV1;
    BOOL            hasRSV2;
    BOOL            hasRSV3;
    MessageOpCode   opCode;
    BOOL            hasMask;
    NSUInteger      payloadLength;
    int             mask;
    NSUInteger      payloadStart;
    PayloadType     payloadType;
    NSData*         payloadData;
    NSMutableData*  fragment;
}

// Specific header tests
@property (nonatomic,assign) BOOL           isFinal;
@property (nonatomic,assign) BOOL           hasRSV1;
@property (nonatomic,assign) BOOL           hasRSV2;
@property (nonatomic,assign) BOOL           hasRSV3;
@property (nonatomic,assign) MessageOpCode  opCode;
@property (nonatomic,assign) BOOL         hasMask;
@property (nonatomic,readonly) NSUInteger   messageLength;
@property (nonatomic,assign) int            mask;
@property (nonatomic,retain) NSData*        payloadData;

@property (nonatomic,readonly) BOOL         isControlFrame;
@property (nonatomic,readonly) BOOL         isDataFrame;

@property (nonatomic,readonly) BOOL         isValid;
@property (nonatomic,readonly) BOOL         isHeaderValid;
@property (nonatomic,readonly) BOOL         isDataValid;
@property (nonatomic,readonly) BOOL         isFrameComplete;
@property (nonatomic,readonly) BOOL         canBeParsed;

@property (nonatomic,retain) NSMutableData* fragment;
@property (nonatomic,assign) PayloadType    payloadType;

- (int) generateMask;
- (NSData*) mask:(int) aMask data:(NSData*) aData;
- (NSData*) mask:(int) aMask data:(NSData*) aData range:(NSRange) aRange;
- (NSData*) unmask:(int) aMask data:(NSData*) aData;
- (NSData*) unmask:(int) aMask data:(NSData*) aData range:(NSRange) aRange;

- (void) parseHeader;
- (void) parseContent;
- (void) buildFragment;

+ (id) fragmentWithOpCode:(MessageOpCode) aOpCode isFinal:(BOOL) aIsFinal payload:(NSData*) aPayload;
+ (id) fragmentWithData:(NSData*) aData;
- (id) initWithOpCode:(MessageOpCode) aOpCode isFinal:(BOOL) aIsFinal payload:(NSData*) aPayload;
- (id) initWithData:(NSData*) aData;

@end
