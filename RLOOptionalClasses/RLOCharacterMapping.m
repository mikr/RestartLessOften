//
//  RLOCharacterMapping.m
//  RLOApp
//
//  Created by michael on 1/30/13.
//
//

#ifdef RLO_ENABLED

#import "RLOCharacterMapping.h"

typedef struct CharacterTable {
    UniChar charactercode;
    char *keyname;
} CharacterTable;


static NSString *keycodemapping_ios_german[] = {
    /*  0*/ @"",
    /*  1*/ @"",
    /*  2*/ @"",
    /*  3*/ @"",
    /*  4*/ @"A",
    /*  5*/ @"B",
    /*  6*/ @"C",
    /*  7*/ @"D",
    /*  8*/ @"E",
    /*  9*/ @"F",
    /*  10*/ @"G",
    /*  11*/ @"H",
    /*  12*/ @"I",
    /*  13*/ @"J",
    /*  14*/ @"K",
    /*  15*/ @"L",
    /*  16*/ @"M",
    /*  17*/ @"N",
    /*  18*/ @"O",
    /*  19*/ @"P",
    /*  20*/ @"Q",
    /*  21*/ @"R",
    /*  22*/ @"S",
    /*  23*/ @"T",
    /*  24*/ @"U",
    /*  25*/ @"V",
    /*  26*/ @"W",
    /*  27*/ @"X",
    /*  28*/ @"Z",
    /*  29*/ @"Y",
    /*  30*/ @"1",
    /*  31*/ @"2",
    /*  32*/ @"3",
    /*  33*/ @"4",
    /*  34*/ @"5",
    /*  35*/ @"6",
    /*  36*/ @"7",
    /*  37*/ @"8",
    /*  38*/ @"9",
    /*  39*/ @"0",
    /*  40*/ @"Return",
    /*  41*/ @"Esc",
    /*  42*/ @"Backspace",
    /*  43*/ @"Tab",
    /*  44*/ @"Space",
    /*  45*/ @"ß",
    /*  46*/ @"´",
    /*  47*/ @"Ü",
    /*  48*/ @"+",
    /*  49*/ @"#",
    /*  50*/ @"",
    /*  51*/ @"Ö",
    /*  52*/ @"Ä",
    /*  53*/ @"<",
    /*  54*/ @",",
    /*  55*/ @".",
    /*  56*/ @"-",
    /*  57*/ @"Caps-Lock",
    /*  58*/ @"F1",
    /*  59*/ @"F2",
    /*  60*/ @"F3",
    /*  61*/ @"F4",
    /*  62*/ @"F5",
    /*  63*/ @"F6",
    /*  64*/ @"F7",
    /*  65*/ @"F8",
    /*  66*/ @"F9",
    /*  67*/ @"F10",
    /*  68*/ @"F11",
    /*  69*/ @"F12",
    /*  70*/ @"",
    /*  71*/ @"",
    /*  72*/ @"",
    /*  73*/ @"",
    /*  74*/ @"Home",
    /*  75*/ @"PageUp",
    /*  76*/ @"Delete",
    /*  77*/ @"End",
    /*  78*/ @"PageDown",
    /*  79*/ @"Right",
    /*  80*/ @"Left",
    /*  81*/ @"Down",
    /*  82*/ @"Up",
    /*  83*/ @"Num-Clear",
    /*  84*/ @"Num-/",
    /*  85*/ @"Num-*",
    /*  86*/ @"Num--",
    /*  87*/ @"Num-+",
    /*  88*/ @"Num-Enter",
    /*  89*/ @"Num-1",
    /*  90*/ @"Num-2",
    /*  91*/ @"Num-3",
    /*  92*/ @"Num-4",
    /*  93*/ @"Num-5",
    /*  94*/ @"Num-6",
    /*  95*/ @"Num-7",
    /*  96*/ @"Num-8",
    /*  97*/ @"Num-9",
    /*  98*/ @"Num-0",
    /*  99*/ @"Num-,",
    /*  100*/ @"^",
    /*  101*/ @"",
    /*  102*/ @"",
    /*  103*/ @"Num-=",
    /*  104*/ @"F13",
    /*  105*/ @"F14",
    /*  106*/ @"F15",
    /*  107*/ @"F16",
    /*  108*/ @"F17",
    /*  109*/ @"F18",
    /*  110*/ @"F19"
};

// We only list special keycodes that cannot be resolved with the
// modified or unmodified input.
CharacterTable keycodes_ios[] = {
    { 40, "Return" },
    { 41, "Esc" },
    { 42, "Backspace" },
    { 43, "Tab" },
    { 44, "Space" },
    { 57, "Caps-Lock" },
    { 58, "F1" },
    { 59, "F2" },
    { 60, "F3" },
    { 61, "F4" },
    { 62, "F5" },
    { 63, "F6" },
    { 64, "F7" },
    { 65, "F8" },
    { 66, "F9" },
    { 67, "F10" },
    { 68, "F11" },
    { 69, "F12" },
    { 74, "Home" },
    { 75, "PageUp" },
    { 76, "Delete" },
    { 77, "End" },
    { 78, "PageDown" },
    { 79, "Right" },
    { 80, "Left" },
    { 81, "Down" },
    { 82, "Up" },
    { 83, "Num-Clear" },
    { 84, "Num-/" },
    { 85, "Num-*" },
    { 86, "Num--" },
    { 87, "Num-+" },
    { 88, "Num-Enter" },
    { 89, "Num-1" },
    { 90, "Num-2" },
    { 91, "Num-3" },
    { 92, "Num-4" },
    { 93, "Num-5" },
    { 94, "Num-6" },
    { 95, "Num-7" },
    { 96, "Num-8" },
    { 97, "Num-9" },
    { 98, "Num-0" },
    { 99, "Num-," },
    { 103, "Num-=" },
    { 104, "F13" },
    { 105, "F14" },
    { 106, "F15" },
    { 107, "F16" },
    { 108, "F17" },
    { 109, "F18" },
    { 110, "F19" }
};

CharacterTable chartab[] = {
    { 0x3, "Num-Enter" },
    { 0x9, "Tab" },
    { 0xd, "Return" },
    { 0x1b, "Esc" },
    { 0x20, "Space" },
    { 0x21, "!" },
    { 0x22, "\"" },
    { 0x23, "#" },
    { 0x24, "$" },
    { 0x25, "%" },
    { 0x26, "&" },
    { 0x28, "(" },
    { 0x29, ")" },
    { 0x2a, "*" },
    { 0x2b, "+" },
    { 0x2c, "," },
    { 0x2d, "-" },
    { 0x2e, "." },
    { 0x2f, "/" },
    { 0x30, "0" },
    { 0x31, "1" },
    { 0x32, "2" },
    { 0x33, "3" },
    { 0x34, "4" },
    { 0x35, "5" },
    { 0x36, "6" },
    { 0x37, "7" },
    { 0x38, "8" },
    { 0x39, "9" },
    { 0x3c, "<" },
    { 0x3d, "=" },
    { 0x3f, "?" },
    { 0x61, "A" },
    { 0x62, "B" },
    { 0x63, "C" },
    { 0x64, "D" },
    { 0x65, "E" },
    { 0x66, "F" },
    { 0x67, "G" },
    { 0x68, "H" },
    { 0x69, "I" },
    { 0x6a, "J" },
    { 0x6b, "K" },
    { 0x6c, "L" },
    { 0x6d, "M" },
    { 0x6e, "N" },
    { 0x6f, "O" },
    { 0x70, "P" },
    { 0x71, "Q" },
    { 0x72, "R" },
    { 0x73, "S" },
    { 0x74, "T" },
    { 0x75, "U" },
    { 0x76, "V" },
    { 0x77, "W" },
    { 0x78, "X" },
    { 0x79, "Y" },
    { 0x7a, "Z" },
    { 0x7f, "Backspace" },
    { 0xa7, "§" },
    { 0xb0, "°" },
    { 0xdf, "ß" },
    { 0xe4, "Ä" },
    { 0xf6, "Ö" },
    { 0xfc, "Ü" },
    { 0xf700, "Up" },
    { 0xf701, "Down" },
    { 0xf702, "Left" },
    { 0xf703, "Right" },
    { 0xf704, "F1" },
    { 0xf705, "F2" },
    { 0xf706, "F3" },
    { 0xf707, "F4" },
    { 0xf708, "F5" },
    { 0xf709, "F6" },
    { 0xf70a, "F7" },
    { 0xf70b, "F8" },
    { 0xf70c, "F9" },
    { 0xf70d, "F10" },
    { 0xf70e, "F11" },
    { 0xf70f, "F12" },
    { 0xf710, "F13" },
    { 0xf711, "F14" },
    { 0xf712, "F15" },
    { 0xf713, "F16" },
    { 0xf714, "F17" },
    { 0xf715, "F18" },
    { 0xf716, "F19" },
    { 0xf728, "Delete" },
    { 0xf729, "Home" },
    { 0xf72b, "End" },
    { 0xf72c, "PageUp" },
    { 0xf72d, "PageDown" },
    { 0xf739, "Num-Clear" }
};

#pragma mark - OS X

CharacterTable specialchartab[] = {
    { 0x3, "Num-Enter" },
    { 0x9, "Tab" },
    { 0xd, "Return" },
    { 0x1b, "Esc" },
    { 0x20, "Space" },
    { 0x7f, "Backspace" },
};

// These are for a german keyboard.

CharacterTable specialkeycodes[] = {
    { 0xa, "^" },
    { 0x18, "´" },
};

#if TARGET_OS_IPHONE

enum {
    NSUpArrowFunctionKey        = 0xF700,
    NSDownArrowFunctionKey      = 0xF701,
    NSLeftArrowFunctionKey      = 0xF702,
    NSRightArrowFunctionKey     = 0xF703,
    NSF1FunctionKey             = 0xF704,
    NSF2FunctionKey             = 0xF705,
    NSF3FunctionKey             = 0xF706,
    NSF4FunctionKey             = 0xF707,
    NSF5FunctionKey             = 0xF708,
    NSF6FunctionKey             = 0xF709,
    NSF7FunctionKey             = 0xF70A,
    NSF8FunctionKey             = 0xF70B,
    NSF9FunctionKey             = 0xF70C,
    NSF10FunctionKey            = 0xF70D,
    NSF11FunctionKey            = 0xF70E,
    NSF12FunctionKey            = 0xF70F,
    NSF13FunctionKey            = 0xF710,
    NSF14FunctionKey            = 0xF711,
    NSF15FunctionKey            = 0xF712,
    NSF16FunctionKey            = 0xF713,
    NSF17FunctionKey            = 0xF714,
    NSF18FunctionKey            = 0xF715,
    NSF19FunctionKey            = 0xF716,
    NSDeleteFunctionKey         = 0xF728,
    NSHomeFunctionKey           = 0xF729,
    NSEndFunctionKey            = 0xF72B,
    NSPageUpFunctionKey         = 0xF72C,
    NSPageDownFunctionKey       = 0xF72D,
    NSClearLineFunctionKey      = 0xF739,
};

#endif

#if !TARGET_OS_IPHONE

static CharacterTable functionkeys[] = {
    { NSUpArrowFunctionKey,      "Up" },
    { NSDownArrowFunctionKey,    "Down" },
    { NSLeftArrowFunctionKey,    "Left" },
    { NSRightArrowFunctionKey,   "Right" },
    { NSF1FunctionKey,           "F1" },
    { NSF2FunctionKey,           "F2" },
    { NSF3FunctionKey,           "F3" },
    { NSF4FunctionKey,           "F4" },
    { NSF5FunctionKey,           "F5" },
    { NSF6FunctionKey,           "F6" },
    { NSF7FunctionKey,           "F7" },
    { NSF8FunctionKey,           "F8" },
    { NSF9FunctionKey,           "F9" },
    { NSF10FunctionKey,          "F10" },
    { NSF11FunctionKey,          "F11" },
    { NSF12FunctionKey,          "F12" },
    { NSF13FunctionKey,          "F13" },
    { NSF14FunctionKey,          "F14" },
    { NSF15FunctionKey,          "F15" },
    { NSF16FunctionKey,          "F16" },
    { NSF17FunctionKey,          "F17" },
    { NSF18FunctionKey,          "F18" },
    { NSF19FunctionKey,          "F19" },
    { NSDeleteFunctionKey,       "Delete" },
    { NSHomeFunctionKey,         "Home" },
    { NSEndFunctionKey,          "End" },
    { NSPageUpFunctionKey,       "PageUp" },
    { NSPageDownFunctionKey,     "PageDown" },
    { NSClearLineFunctionKey,    "Num-Clear" }
};

#endif

@implementation RLOCharacterMapping

#if TARGET_OS_IPHONE

+ (NSString *)stringForIOS6Keycode:(UniChar)keycode
{
    NSString *result;
    if (keycode < sizeof(keycodemapping_ios_german) / sizeof(*keycodemapping_ios_german)) {
        result = keycodemapping_ios_german[keycode];
    } else {
        result = @"Unknown";
    }
    
    return result;
}

#endif

+ (NSString *)stringForCharactersIgnoringModifiers:(NSString *)characters
{
    UniChar c = 0;
    if (characters.length == 1) {
        c = [characters characterAtIndex:0];
    }
    
#if !TARGET_OS_IPHONE
    // Handle functions keys
    
    if (characters.length == 1) {
        // See NSEvent.h
        if (c >= 0xF700 && c <= 0xF8FF) {
            for (int j=0; j < sizeof(functionkeys) / sizeof(*functionkeys); j++) {
                if (functionkeys[j].charactercode == c) {
                    return [NSString stringWithUTF8String:functionkeys[j].keyname];
                }
            }
        }
    }
#endif
    
    // Handle printable characters
    
    NSCharacterSet *printableCharacterSet = [NSCharacterSet alphanumericCharacterSet];
    if (characters.length == 1) {
        if ((c <= 0x7F && isprint(c))
            || (c >= 0x80 && c <= 0xFF)
            || [printableCharacterSet characterIsMember:c]) {
            NSString *uppercase = [characters uppercaseString];
            return uppercase.length == 1 ? uppercase : characters;
        }
    }

    return nil;
}

+ (NSString *)stringForKeycode:(UniChar)keycode characters:(NSString *)characters charactersIgnoringModifiers:(NSString *)charactersIgnoringModifiers
{
#if TARGET_OS_IPHONE
    if (RLOGetInt(@"rlo.simulator_keyboard_german", 0)) {
        return [self stringForIOS6Keycode:keycode];
    }
#endif

    NSString *printable_result = [self stringForCharactersIgnoringModifiers:charactersIgnoringModifiers];
    if (printable_result) {
        return printable_result;
    }
    
#if !TARGET_OS_IPHONE

    if (charactersIgnoringModifiers.length == 1) {
        UniChar c = [charactersIgnoringModifiers characterAtIndex:0];
        for (int j=0; j < sizeof(specialchartab) / sizeof(*specialchartab); j++) {
            if (specialchartab[j].charactercode == c) {
                return [NSString stringWithUTF8String:specialchartab[j].keyname];
            }
        }
    }

    // Handle dead keys via keycode

    for (int j=0; j < sizeof(specialkeycodes) / sizeof(*specialkeycodes); j++) {
        if (specialkeycodes[j].charactercode == keycode) {
            return [NSString stringWithUTF8String:specialkeycodes[j].keyname];
        }
    }
    
#else

    for (int j=0; j < sizeof(keycodes_ios) / sizeof(*keycodes_ios); j++) {
        if (keycodes_ios[j].charactercode == keycode) {
            return [NSString stringWithUTF8String:keycodes_ios[j].keyname];
        }
    }
    
#endif

    return @"Unknown";
}

+ (NSString *)keynameForCharacters:(NSString *)text
{
    for (int i = 0; i < text.length; i++) {
        UniChar c = [[text lowercaseString] characterAtIndex:i];
        
        for (int j=0; j < sizeof(chartab) / sizeof(*chartab); j++) {
            if (chartab[j].charactercode == c) {
                return [NSString stringWithUTF8String:chartab[j].keyname];
            }
        }
    }

    return nil;
}

#if !TARGET_OS_IPHONE

#define IOS_SIMULATOR_MODIFIER_CMD NSCommandKeyMask
#define IOS_SIMULATOR_MODIFIER_SHIFT NSShiftKeyMask
#define IOS_SIMULATOR_MODIFIER_OPT NSAlternateKeyMask
#define IOS_SIMULATOR_MODIFIER_CTRL NSControlKeyMask

#else

#define IOS_SIMULATOR_MODIFIER_CMD kGSEventFlagMaskCommand
#define IOS_SIMULATOR_MODIFIER_SHIFT kGSEventFlagMaskShift
#define IOS_SIMULATOR_MODIFIER_OPT kGSEventFlagMaskAlternate
#define IOS_SIMULATOR_MODIFIER_CTRL kGSEventFlagMaskControl

#endif

+ (NSString *)modifiedCharnames:(NSString *)charnames modifierFlags:(NSUInteger)modifierFlags
{
    NSMutableArray *array = [[NSMutableArray alloc] init];
    if (modifierFlags & IOS_SIMULATOR_MODIFIER_CMD) {
        [array addObject:@"Cmd"];
    }
    if (modifierFlags & IOS_SIMULATOR_MODIFIER_SHIFT) {
        [array addObject:@"Shift"];
    }
    if (modifierFlags & IOS_SIMULATOR_MODIFIER_OPT) {
        [array addObject:@"Opt"];
    }
    if (modifierFlags & IOS_SIMULATOR_MODIFIER_CTRL) {
        [array addObject:@"Ctrl"];
    }
#if !TARGET_OS_IPHONE
    if (modifierFlags & NSNumericPadKeyMask) {
        [array addObject:@"Num"];
    }
//    if (modifierFlags & NSFunctionKeyMask) {
//        [array addObject:@"Fn"];
//    }
#endif
    if (charnames) {
        [array addObject:charnames];
    }
    
    return [array componentsJoinedByString:@"-"];
}

+ (NSString *)modifiedCharnames:(NSString *)charnames characters:(NSString *)characters modifierFlags:(NSUInteger)modifierFlags
{
#if !TARGET_OS_IPHONE
    if (characters.length == 1) {
        UniChar c = [characters characterAtIndex:0];
        if (c == NSUpArrowFunctionKey
            || c == NSDownArrowFunctionKey
            || c == NSLeftArrowFunctionKey
            || c == NSRightArrowFunctionKey) {
            // The cursor keys have the NSNumericPadKeyMask set
            // but we prefer getting 'Right' instead of 'Num-Right'.
            if (modifierFlags & NSNumericPadKeyMask) {
                modifierFlags = modifierFlags & ~NSNumericPadKeyMask;
            }
        }
    }
#endif
    return [self modifiedCharnames:charnames modifierFlags:modifierFlags];
}

@end

#endif
