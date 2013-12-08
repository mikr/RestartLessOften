//
//  GlobalEventHandler.m
//  RLOApp
//
//  Created by michael on 1/30/13.
//
//

#import "GlobalEventHandler.h"
#import "RLOCharacterMapping.h"
#import "NSString+URLAdditions.h"


NSString * const GlobalEventHandlerNotification = @"GlobalEventHandlerNotification";


@implementation GlobalEventHandler

@synthesize capturesKeyboard;

- (void)installKeyHandler
{
    CGEventMask eventMask;
    
    eventMask = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp);
    eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0,
                                eventMask, KeyHandler, (__bridge void *)self);
    if (! eventTap) {
        NSLog(@"failed to create event tap, can somebody make this work on Mavericks?");
        return;
    }
    
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
    CGEventTapEnable(eventTap, true);
}

CGEventRef KeyHandler(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon)
{    
    UniCharCount actualStringLength;
    UniCharCount maxStringLength = 1;
    UniChar chars[3];
    
    int64_t keycode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    CGEventFlags flags = CGEventGetFlags(event);
    
//    AppDelegate *delegate = (__bridge AppDelegate *)refcon;
//    if (keycode == kVK_F1) {
//        if (type == kCGEventKeyDown && CGEventGetIntegerValueField(event, kCGKeyboardEventAutorepeat) == 0) {
//            @autoreleasepool {
//                if (flags & kCGEventFlagMaskShift) {
//                    [[NSApplication sharedApplication] terminate:delegate];
//                }
//                [delegate toggleView];
//            }
//        }
//        return NULL;
//    } else
    GlobalEventHandler *gevhandler = (__bridge GlobalEventHandler *)refcon;

    if (gevhandler.capturesKeyboard) {
        CGEventKeyboardGetUnicodeString(event, maxStringLength, &actualStringLength, chars);
        NSString *eventtype = @"";
        if (type == kCGEventKeyDown) {
            eventtype = @"KeyDown";
        } else if (type == kCGEventKeyUp) {
            eventtype = @"KeyUp";
        }
        NSString *key = [RLOCharacterMapping stringForKeycode:keycode];
        
        NSMutableArray *array = [[NSMutableArray alloc] init];
        if (flags & kCGEventFlagMaskCommand) {
            [array addObject:@"Cmd"];
        }
        if (flags & kCGEventFlagMaskShift) {
            [array addObject:@"Shift"];
        }
        if (flags & kCGEventFlagMaskAlternate) {
            [array addObject:@"Opt"];
        }
        if (flags & kCGEventFlagMaskControl) {
            [array addObject:@"Ctrl"];
        }
        [array addObject:key];
        NSString *keycombo = [array componentsJoinedByString:@"-"];
        
        NSMutableDictionary *querydict = [@{
                                    @"event" : eventtype,
                                    @"keycombo" : keycombo,
                                    @"autorepeat": @(CGEventGetIntegerValueField(event, kCGKeyboardEventAutorepeat))
                                    } mutableCopy];
        
        if ([keycombo isEqualToString:@"Cmd-Q"]) {
            // Quitting an application is not intercepted and forwarded.
            return event;
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:GlobalEventHandlerNotification object:gevhandler userInfo:querydict];
        if ([querydict[@"handled"] isEqual:@YES]) {
            return NULL;
        }
    }
    
    return event;
}

@end
