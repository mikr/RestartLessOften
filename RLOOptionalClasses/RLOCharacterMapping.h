//
//  RLOCharacterMapping.h
//  RLOApp
//
//  Created by michael on 1/30/13.
//
//

#ifdef RLO_ENABLED

#import <Foundation/Foundation.h>

#if TARGET_OS_IPHONE

// This is for the iOS simulator
typedef enum GSEventFlags {
    kGSEventFlagMaskCommand = 1 << 16,
    kGSEventFlagMaskShift = 1 << 17,
    kGSEventFlagMaskAlternate = 1 << 19,
    kGSEventFlagMaskControl = 1 << 20
} GSEventFlags;

#endif

@interface RLOCharacterMapping : NSObject

#if TARGET_OS_IPHONE
+ (NSString *)stringForKeycode:(UniChar)keycode;
#else
+ (NSString *)stringForKeycode:(int64_t)keycode;
#endif

+ (NSString *)keynameForCharacters:(NSString *)text;
+ (NSString *)modifiedCharnames:(NSString *)charnames modifierFlags:(NSUInteger)modifierFlags;

@end

#endif
