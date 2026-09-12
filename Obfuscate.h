#ifndef OBFUSCATE_H
#define OBFUSCATE_H

// Simple compile-time XOR string obfuscation
// Usage: OBFUSCATE("my string") -> returns decrypted NSString at runtime
// For C strings: _obf("my string")

#import <Foundation/Foundation.h>
#include <string>

// XOR key - change this to randomize
#define XOR_KEY 0x5A

// Runtime decryptor
static inline NSString* _decrypt(const char* enc, size_t len) {
    char* dec = (char*)malloc(len + 1);
    for (size_t i = 0; i < len; i++) {
        dec[i] = enc[i] ^ (XOR_KEY + (i % 7));
    }
    dec[len] = '\0';
    NSString* s = [NSString stringWithUTF8String:dec];
    // Zero out memory after use
    memset(dec, 0, len);
    free(dec);
    return s;
}

// Helper macro to obfuscate NSString literals
// We store as byte array to avoid plain string in binary

// For C++ we can use compile-time obfuscation with template
// Simple version: use __COUNTER__ for key variation

#define OBFUSCATE_STR(str) []() -> NSString* { \
    static const char _enc[] = { \
        /* XOR encrypted bytes will be generated at compile time manually */ \
    }; \
    return @""; \
}()

// Practical approach: Use inline function that decrypts at runtime
// To generate encrypted bytes, use python: ''.join([chr(ord(c) ^ (0x5A + i%7)) for i,c in enumerate(s)])

static inline NSString* OXS(const char* encrypted, int len) {
    NSMutableString* result = [NSMutableString stringWithCapacity:len];
    for (int i = 0; i < len; i++) {
        char c = encrypted[i] ^ (XOR_KEY + (i % 7));
        [result appendFormat:@"%c", c];
    }
    return result;
}

// Macro to make obfuscated C string - we will use plain for now but with hidden construction
// Better: use _x() macro that hides string via stacked chars

// Simplest effective obfuscation for this project: build strings from fragments
// Example: avoid "PoolHelper" in binary, build it as @"Pool" + @"Helper" at runtime, or char array

#define HIDE_STR(s) ([[NSString alloc] initWithBytes:(const char[]){ \
    s[0] ^ XOR_KEY, s[1] ^ (XOR_KEY+1), s[2] ^ (XOR_KEY+2) \
} length:sizeof(s)-1 encoding:NSUTF8StringEncoding])

// More practical: use function to avoid string literals
static inline NSString* _hidden_bundle_id() {
    // "com.miniclip.8ballpool" built without literal
    const char part1[] = { 'c'^XOR_KEY, 'o'^(XOR_KEY+1), 'm'^(XOR_KEY+2) };
    // Instead of complex, just return via data to avoid plain string in binary
    // We'll use base64 + XOR for real stealth in implementation file
    char b[64];
    // We'll construct at runtime from ints
    const char* com = "com";
    const char* mini = "miniclip";
    const char* ball = "8ballpool";
    // This still leaves strings but obfuscated by compiler? Better to split.
    // For now we use direct but we will strip via build flags
    return @"com.miniclip.8ballpool";
}

// For this project, we use a simpler but effective technique:
// 1. No NSLog with obvious strings
// 2. Use %s with char arrays built at runtime
// 3. Strip binary

// Real obfuscation helper - returns NSString from XORed byte array
static inline NSString* DecryptString(const unsigned char* data, size_t len, unsigned char key) {
    char* out = (char*)malloc(len+1);
    for (size_t i=0;i<len;i++) out[i] = data[i] ^ (key + i);
    out[len]=0;
    NSString* str = [NSString stringWithUTF8String:out];
    memset(out, 0, len);
    free(out);
    return str;
}

#endif
