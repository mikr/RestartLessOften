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
+ (NSString *)stringForIOS6Keycode:(UniChar)keycode;
#endif
+ (NSString *)stringForKeycode:(UniChar)keycode characters:(NSString *)characters charactersIgnoringModifiers:(NSString *)charactersIgnoringModifiers;

+ (NSString *)keynameForCharacters:(NSString *)text;
+ (NSString *)modifiedCharnames:(NSString *)charnames modifierFlags:(NSUInteger)modifierFlags;
+ (NSString *)modifiedCharnames:(NSString *)charnames characters:(NSString *)characters modifierFlags:(NSUInteger)modifierFlags;

@end

#endif
