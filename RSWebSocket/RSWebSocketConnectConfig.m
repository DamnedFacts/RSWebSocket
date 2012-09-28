//
//  WebSocketConnectConfig.m
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

#import "RSWebSocketConnectConfig.h"


@interface RSWebSocketConnectConfig()

- (NSString*) buildOrigin;
- (NSString*) buildHost;

@end


@implementation RSWebSocketConnectConfig


@synthesize version;
@synthesize maxPayloadSize;
@synthesize url;
@synthesize origin;
@synthesize host;
@synthesize timeout;
@synthesize closeTimeout;
@synthesize tlsSettings;
@synthesize protocols;
@synthesize verifySecurityKey;
@synthesize serverProtocol;
@synthesize isSecure;
@synthesize serverHeaders;
@synthesize headers;
@synthesize extensions;
@synthesize serverExtensions;


NSString* const WebSocketConnectConfigException = @"WebSocketConnectConfigException";
NSString* const WebSocketConnectConfigErrorDomain = @"WebSocketConnectConfigErrorDomain";


#pragma mark Lifecycle
+ (id) config
{
    return [[[self class] alloc] init];
}

+ (id) configWithURLString:(NSString*) aUrlString origin:(NSString*) aOrigin protocols:(NSArray*) aProtocols tlsSettings:(NSDictionary*) aTlsSettings headers:(NSArray*) aHeaders verifySecurityKey:(BOOL) aVerifySecurityKey extensions:(NSArray*) aExtensions
{
    return [[[self class] alloc] initWithURLString:aUrlString origin:aOrigin protocols:aProtocols tlsSettings:aTlsSettings headers:aHeaders verifySecurityKey:aVerifySecurityKey extensions:aExtensions];
}

- (id) initWithURLString:(NSString *) aUrlString origin:(NSString*) aOrigin protocols:(NSArray*) aProtocols tlsSettings:(NSDictionary*) aTlsSettings headers:(NSArray*) aHeaders verifySecurityKey:(BOOL) aVerifySecurityKey extensions:(NSArray*) aExtensions
{
    self = [super init];
    if (self) 
    {
        //validate
        NSURL* tempUrl = [NSURL URLWithString:aUrlString];
        if (![tempUrl.scheme isEqualToString:@"ws"] && ![tempUrl.scheme isEqualToString:@"wss"]) 
        {
            [NSException raise:WebSocketConnectConfigException format:@"Unsupported protocol %@",tempUrl.scheme];
        }
        
        //apply properties
        self.url = tempUrl;
        self.isSecure = [self.url.scheme isEqualToString:@"wss"];
        if (aOrigin)
        {
            self.origin = aOrigin;
            
            // Per RFC 3986, the leading slash after the authority (host name and port)
            // portion is treated as part of the path.
            if ([self.url.path compare:@""] == NSOrderedSame) {
                self.url = [self.url URLByAppendingPathComponent:@"/"];
            }
        }
        else
        {
            self.origin = [self buildOrigin];
        }
        self.host = [self buildHost];
        if (aProtocols)
        {
            self.protocols = [NSMutableArray arrayWithArray:aProtocols];
        }
        if (aTlsSettings)
        {
            self.tlsSettings = [NSMutableDictionary dictionaryWithDictionary:aTlsSettings];
        }
        if (aHeaders)
        {
            self.headers = [NSMutableArray arrayWithArray:aHeaders];
        }
        if (aExtensions)
        {
            self.extensions = [NSMutableArray arrayWithArray:aExtensions];
        }
        self.verifySecurityKey = aVerifySecurityKey;
        self.timeout = -1; // Don't apply timeouts during a session by default.
        self.closeTimeout = 30.0;
        self.maxPayloadSize = 32*1024;
        self.version = WebSocketVersionHybi13;
    }
    return self;
}

- (NSString*) buildOrigin
{
    // Per RFC 3986, the leading slash after the authority (host name and port) portion is treated as part of the path.
    return [NSString stringWithFormat:@"%@://%@%@", isSecure ? @"https" : @"http", [self buildHost], self.url.path ? self.url.path : @"/"];
}

- (NSString*) buildHost
{
    if (self.url.port)
    {
        if ([self.url.port intValue] == 80 || [self.url.port intValue] == 443)
        {
            return self.url.host;
        }
        
        return [NSString stringWithFormat:@"%@:%i", self.url.host, [self.url.port intValue]];
    }
    
    return self.url.host;
}


@end
