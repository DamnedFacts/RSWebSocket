//
//  RSWebSocket.h
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



#import <Foundation/Foundation.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>

#import <RSWebSocket/NSData+Base64.h>
#import <RSWebSocket/MutableQueue.h>
#import <RSWebSocket/RSWebSocketConnectConfig.h>
#import <RSWebSocket/AsyncSocket.h>


// FIXME: How to handle extended range of error codes
enum {
    WebSocketCloseStatusNormal = 1000,  // Indicates a normal closure, meaning whatever purpose the 
                                        // connection was established for has been fulfilled
    
    WebSocketCloseStatusEndpointGone = 1001, //indicates that an endpoint is "going away", such as a 
                                             //server going down, or a browser having navigated away from a page
    
    WebSocketCloseStatusProtocolError = 1002, //indicates that an endpoint is terminating the connection 
                                              //due to a protocol error
    
    WebSocketCloseStatusInvalidDataType = 1003, //indicates that an endpoint is terminating the connection
                                                //because it has received a type of data it cannot accept 
                                                //(e.g. an endpoint that understands only text data MAY 
                                                //send this if it receives a binary message)
    
    WebSocketCloseStatusReserved1004 = 1004,    // NOT USED. Reserved.  The specific meaning might be defined in the future.
    
    WebSocketCloseStatusNormalButMissingStatus = 1005, // LOCAL ONLY. designated for use in applications expecting a status code 
                                                       //to indicate that no status code was actually present
    
    WebSocketCloseStatusAbnormalButMissingStatus = 1006, // LOCAL ONLY. designated for use in	applications expecting a status code
                                                         //to indicate that the connection was closed abnormally, e.g.
                                                         //without sending or receiving a Close control frame.
    
    WebSocketCloseStatusInvalidUtf8 = 1007, //indicates that an endpoint is terminating the connection because it has 
                                           //received data that was supposed to be UTF-8 (such as in a text frame) that 
                                           //was in fact not valid UTF-8
    
    WebSocketCloseStatusViolatedPolicy = 1008, //indicates that an endpoint has received a message that violates its policy. 

    WebSocketCloseStatusMessageTooLarge = 1009, //indicates that an endpoint is terminating the connection
                                                //because it has received a message that is too large

    WebSocketCloseStatusUnnegotiatedExtensions = 1010, // endpoint (client) is terminating the
                                                       // connection because it has expected the server to negotiate one or
                                                       // more extension, but the server didn't return them in the response
                                                       // message of the WebSocket handshake. 
    
    WebSocketCloseStatusUnexpectedCondition = 1011 // Indicates an unexpected condition that prevented it from fulfilling the request

};
typedef NSUInteger WebSocketCloseStatus;

enum {
    WebSocketReadyStateConnecting   = 0,  // The connection has not yet been established.
    WebSocketReadyStateOpen         = 1,  // The WebSocket connection is established and communication is possible.
    WebSocketReadyStateClosing      = 2,  // The connection is going through the closing handshake.
    WebSocketReadyStateClosed       = 3   // The connection has been closed or could not be opened
};
typedef NSUInteger RSWebSocketReadyState;

enum {
    WebSocketFrameNew               = 0,  // Frame is newly created
    WebSocketFramePriHeaderFilling  = 1,  // Frame is currently being filled primary header
    WebSocketFrameExtHeaderFilling  = 2,  // Frame is currently being filled extended header
    WebSocketFrameDataFilling       = 3,  // Frame is currently being filled with data
    WebSocketFrameComplete          = 4,  // Frame is filled, and complete
};
typedef NSUInteger RSWebSocketFrameState;

enum {
    WebSocketContinuationNone         = 0,  // Frame is newly created
    WebSocketContinuationStart        = 1,  // Frame is newly created
    WebSocketContinuationInProgress   = 2,  // Frame is currently being filled primary header
    WebSocketContinuationEnd          = 3,  // Frame is currently being filled extended header
};
typedef NSUInteger RSWebSocketContinuationState;

@protocol RSWebSocketDelegate <NSObject>

/**
 * Called when the web socket connects and is ready for reading and writing.
 **/
- (void) didOpen;


/**
 * Called when the web socket closes. aError will be nil if it closes cleanly.
 **/
- (void) didClose: (NSError *) closingStatusError 
                       localCode: (NSUInteger) closingStatusLocalCode  
                    localMessage: (NSString *) closingStatusLocalMessage
                      remoteCode: (NSUInteger) closingStatusRemoteCode
                   remoteMessage: (NSString *) closingStatusRemoteMessage;

/**
 * Called when the web socket receives an error. Such an error can result in the
 socket being closed.
 **/
- (void) didReceiveError:(NSError*) aError;

/**
 * Called when the web socket receives a message.
 **/
- (void) didReceiveTextMessage:(NSString*) aMessage;

/**
 * Called when the web socket receives a message.
 **/
- (void) didReceiveBinaryMessage:(NSData*) aMessage;

@optional
/**
 * Called when pong is sent... For keep-alive optimization.
 **/
- (void) didSendPong:(NSData*) aMessage;

@end


@interface RSWebSocket : NSObject {
@private
    id<RSWebSocketDelegate>  delegate;
    AsyncSocket* socket;
    RSWebSocketReadyState           readystate;
    RSWebSocketFrameState           framestate;
    RSWebSocketContinuationState    contstate;
    NSString* wsSecKey;
    NSString* wsSecKeyHandshake;
    MutableQueue* pendingFragments;
    BOOL isClosing;
    NSMutableDictionary *closingStatus;
    NSError *closingStatusError;
    NSUInteger closingStatusLocalCode;
    NSString *closingStatusLocalMessage;
    NSUInteger closingStatusRemoteCode;
    NSString *closingStatusRemoteMessage;
//    BOOL sendCloseInfoToListener;
    RSWebSocketConnectConfig* config;
//    int i;

}


/**
 * Callback delegate for websocket events.
 **/
@property(retain, nonatomic) id<RSWebSocketDelegate> delegate;

/**
 * Config info for the websocket connection.
 **/
@property(nonatomic,retain) RSWebSocketConnectConfig* config;

/**
 * Represents the state of the connection. It can have the following values:
 * - WebSocketReadyStateConnecting: The connection has not yet been established.
 * - WebSocketReadyStateOpen: The WebSocket connection is established and communication is possible.
 * - WebSocketReadyStateClosing: The connection is going through the closing handshake.
 * - WebSocketReadyStateClosed: The connection has been closed or could not be opened.
 **/
@property(nonatomic,readonly) RSWebSocketReadyState readystate;


+ (id) webSocketWithConfig:(RSWebSocketConnectConfig*) aConfig delegate:(id<RSWebSocketDelegate>) aDelegate;
- (id) initWithConfig:(RSWebSocketConnectConfig*) aConfig delegate:(id<RSWebSocketDelegate>) aDelegate;


/**
 * Connect the websocket and prepare it for reading and writing.
 **/
- (void) open;

/* Returns YES if the socket and streams are open, connected, and ready for reading and writing. */
- (BOOL) isConnectionOpen;

///**
// * Finish all reads/writes and close the websocket. Sends a status of WebSocketCloseStatusNormal and no message.
// **/
- (void) close;

/**
 * Finish all reads/writes and close the websocket. Sends the specified status and message.
 **/
- (void) close:(NSUInteger) aStatusCode message:(NSString*) aMessage;

/**
 * Write a UTF-8 encoded NSString message to the websocket.
 **/
- (void) sendText:(NSString*)message;

/**
 * Write a binary message to the websocket.
 **/
- (void) sendBinary:(NSData*)message;

/**
 * Send ping message to the websocket
 */
- (void) sendPing:(NSData*)message;

extern NSString *const WebSocketException;
extern NSString *const WebSocketErrorDomain;

@end
