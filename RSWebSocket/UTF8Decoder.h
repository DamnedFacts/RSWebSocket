//
//  UTF8Decoder.h
//  RSWebSocket
//
//  Created by Richard Sarkis on 8/12/12.
//
//

#ifndef RSWebSocket_UTF8Decoder_h
#define RSWebSocket_UTF8Decoder_h

#include <stdlib.h>
#include <stdint.h>


#define UTF8_ACCEPT 0
#define UTF8_REJECT 1

void utf8validate_reset(void);
void utf8validate_forcereset(void);
int utf8validate(uint8_t *s, size_t count);

#endif
