//
//  RLOCharacterMapping.m
//  RLOApp
//
//  Created by michael on 1/30/13.
//
//

#ifdef RLO_ENABLED

#import "RLOCharacterMapping.h"

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

static NSString *keycodemapping_osx_german[] = {
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
    /*  49*/ @"Ö",
    /*  50*/ @"Ä",
    /*  51*/ @"#",
    /*  52*/ @"",
    /*  53*/ @"<",
    /*  54*/ @",",
    /*  55*/ @".",
    /*  56*/ @"-",
    /*  57*/ @"",
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

#if 0
// Keycode mapping for a german keyboard
// Map the keycode from CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode)
static NSString *keycodemapping[] = {
    /*  0*/ @"A",
    /*  1*/ @"S",
    /*  2*/ @"D",
    /*  3*/ @"F",
    /*  4*/ @"H",
    /*  5*/ @"G",
    /*  6*/ @"Y",
    /*  7*/ @"X",
    /*  8*/ @"C",
    /*  9*/ @"V",
    /* 10*/ @"^",
    /* 11*/ @"B",
    /* 12*/ @"Q",
    /* 13*/ @"W",
    /* 14*/ @"E",
    /* 15*/ @"R",
    /* 16*/ @"Z",
    /* 17*/ @"T",
    /* 18*/ @"1",
    /* 19*/ @"2",
    /* 20*/ @"3",
    /* 21*/ @"4",
    /* 22*/ @"6",
    /* 23*/ @"5",
    /* 24*/ @"´",
    /* 25*/ @"9",
    /* 26*/ @"7",
    /* 27*/ @"ß",
    /* 28*/ @"8",
    /* 29*/ @"0",
    /* 30*/ @"+",
    /* 31*/ @"O",
    /* 32*/ @"U",
    /* 33*/ @"Ü",
    /* 34*/ @"I",
    /* 35*/ @"P",
    /* 36*/ @"Return",
    /* 37*/ @"L",
    /* 38*/ @"J",
    /* 39*/ @"Ä",
    /* 40*/ @"K",
    /* 41*/ @"Ö",
    /* 42*/ @"#",
    /* 43*/ @",",
    /* 44*/ @"-",
    /* 45*/ @"N",
    /* 46*/ @"M",
    /* 47*/ @".",
    /* 48*/ @"Tab",
    /* 49*/ @"Space",
    /* 50*/ @"<",
    /* 51*/ @"Backspace",
    /* 52*/ @"Unknown",
    /* 53*/ @"Esc",
    /* 54*/ @"Unknown",
    /* 55*/ @"Command",
    /* 56*/ @"Shift",
    /* 57*/ @"CapsLock",
    /* 58*/ @"Opt",
    /* 59*/ @"Ctrl",
    /* 60*/ @"RightShift",
    /* 61*/ @"RightOpt",
    /* 62*/ @"RightCtrl",
    /* 63*/ @"Fn",
    /* 64*/ @"F17",
    /* 65*/ @"Num-,",
    /* 66*/ @"Unknown",
    /* 67*/ @"Num-*",
    /* 68*/ @"Unknown",
    /* 69*/ @"Num-+",
    /* 70*/ @"Unknown",
    /* 71*/ @"Num-Clear",
    /* 72*/ @"Unknown",
    /* 73*/ @"Unknown",
    /* 74*/ @"Unknown",
    /* 75*/ @"Num-/",
    /* 76*/ @"Num-Enter",
    /* 77*/ @"Unknown",
    /* 78*/ @"Num--",
    /* 79*/ @"F18",
    /* 80*/ @"F19",
    /* 81*/ @"Num-=",
    /* 82*/ @"Num-0",
    /* 83*/ @"Num-1",
    /* 84*/ @"Num-2",
    /* 85*/ @"Num-3",
    /* 86*/ @"Num-4",
    /* 87*/ @"Num-5",
    /* 88*/ @"Num-6",
    /* 89*/ @"Num-7",
    /* 90*/ @"Unknown",
    /* 91*/ @"Num-8",
    /* 92*/ @"Num-9",
    /* 93*/ @"Unknown",
    /* 94*/ @"Unknown",
    /* 95*/ @"Unknown",
    /* 96*/ @"F5",
    /* 97*/ @"F6",
    /* 98*/ @"F7",
    /* 99*/ @"F3",
    /*100*/ @"F8",
    /*101*/ @"F9",
    /*102*/ @"Unknown",
    /*103*/ @"F11",
    /*104*/ @"Unknown",
    /*105*/ @"F13",
    /*106*/ @"F16",
    /*107*/ @"F14",
    /*108*/ @"Unknown",
    /*109*/ @"F10",
    /*110*/ @"Unknown",
    /*111*/ @"F12",
    /*112*/ @"Unknown",
    /*113*/ @"F15",
    /*114*/ @"Help",
    /*115*/ @"Home",
    /*116*/ @"PageUp",
    /*117*/ @"Delete",
    /*118*/ @"F4",
    /*119*/ @"End",
    /*120*/ @"F2",
    /*121*/ @"PageDown",
    /*122*/ @"F1",
    /*123*/ @"Left",
    /*124*/ @"Right",
    /*125*/ @"Down",
    /*126*/ @"Up",
    /*127*/ @"Unknown",
};

#endif

typedef struct CharacterTable {
    UniChar charactercode;
    char *keyname;
} CharacterTable;

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


@implementation RLOCharacterMapping

#if TARGET_OS_IPHONE

+ (NSString *)stringForKeycode:(UniChar)keycode
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

#if !TARGET_OS_IPHONE

+ (NSString *)stringForKeycode:(int64_t)keycode
{
    NSString *result;
    if (keycode < sizeof(keycodemapping_osx_german) / sizeof(*keycodemapping_osx_german)) {
        result = keycodemapping_osx_german[keycode];
    } else {
        result = @"Unknown";
    }
    
    return result;
}

#endif

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

@end

#endif
