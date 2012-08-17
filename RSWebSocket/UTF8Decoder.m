// Flexible and Economical UTF-8 Decoder
// Copyright (c) 2008-2009 Bjoern Hoehrmann <bjoern@hoehrmann.de>
// See http://bjoern.hoehrmann.de/utf-8/decoder/dfa/ for details.

#include "UTF8Decoder.h"
#include <stdio.h>

uint32_t static state = UTF8_ACCEPT;
BOOL static codepoint = FALSE;

static const uint8_t utf8d[] = {
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 00..1f
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 20..3f
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 40..5f
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, // 60..7f
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9, // 80..9f
    7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7, // a0..bf
    8,8,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, // c0..df
    0xa,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x3,0x4,0x3,0x3, // e0..ef
    0xb,0x6,0x6,0x6,0x5,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8,0x8, // f0..ff
    0x0,0x1,0x2,0x3,0x5,0x8,0x7,0x1,0x1,0x1,0x4,0x6,0x1,0x1,0x1,0x1, // s0..s0
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,1,1,0,1,0,1,1,1,1,1,1, // s1..s2
    1,2,1,1,1,1,1,2,1,2,1,1,1,1,1,1,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1, // s3..s4
    1,2,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1,1,1,1,1,1,3,1,3,1,1,1,1,1,1, // s5..s6
    1,3,1,1,1,1,1,3,1,3,1,1,1,1,1,1,1,3,1,1,1,1,1,1,1,1,1,1,1,1,1,1, // s7..s8
};

uint32_t static inline utf8decode(uint32_t* state, uint32_t* codep, uint8_t byte) {
    uint32_t type = utf8d[byte];
    
    *codep = (*state != UTF8_ACCEPT) ?
    (byte & 0x3fu) | (*codep << 6) :
    (0xff >> type) & (byte);
    
    *state = utf8d[256 + *state*16 + type];
    return *state;
}

int utf8validate(uint8_t *s, size_t count) {
    /* Incrementally validate a chunk of bytes provided as string.
     
     As soon as an octet is encountered which renders the octet sequence
     invalid, a UTF8_REJECT is returned.
     */
    int j = 0;
//    printf("State: %u\n", state);
    for (int i = 0, j = 0; i < count; ++i) {
        state = utf8d[256 + (state << 4) + utf8d[s[i]]];
        if (state == UTF8_REJECT) {
            j += i;
//            printf("Valid: False EndsOnCodePoint: False, State: %u, %d, %d\n", state, i, j);
            return UTF8_REJECT;
        }
    }
    j += count;
//    printf("Valid: True EndsOnCodePoint: %s, State: %u, %lu, %d\n", state==UTF8_ACCEPT?"True":"False", state, count, j);
    codepoint = (state==UTF8_ACCEPT?TRUE:FALSE);
    return UTF8_ACCEPT;
}


void utf8validate_reset(void) {
//    printf("check before resetting state: %d codepoint: %d\n", state, codepoint);

    if ((state == UTF8_REJECT) || (state == UTF8_ACCEPT && codepoint == TRUE)) {
//        printf("resetting state: %d\n", state);
        state = UTF8_ACCEPT;
        codepoint = FALSE;
    }
}

void utf8validate_forcereset(void) {
//    printf("check before resetting state: %d codepoint: %d\n", state, codepoint);
    state = UTF8_ACCEPT;
    codepoint = FALSE;
}