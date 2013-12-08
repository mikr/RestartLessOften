#ifdef RLO_ENABLED
#if TARGET_OS_IPHONE

//
//  RLOUIApplication.m
//
//

#import "RLOUIApplication.h"
#import "RLOCharacterMapping.h"

#define GSEVENT_TYPE 2
#define GSEVENT_FLAGS 12
#define GSEVENTKEY_KEYCODE 15
#define GSEVENT_TYPE_KEYUP 11


typedef struct __CFRuntimeBase {
    void* _isa;
    uint16_t _info;
    uint16_t _rc;
} CFRuntimeBase;


typedef enum __GSEventType {
    kGSEventLeftMouseDown = 1,
    kGSEventLeftMouseUp = 2,
    kGSEventMouseMoved = 5,
    kGSEventLeftMouseDragged = 6,
    
    kGSEventKeyDown = 10,
    kGSEventKeyUp = 11,
    kGSEventModifiersChanged = 12,
    kGSEventSimulatorKeyDown = 13,
    kGSEventHardwareKeyDown = 14,   // Maybe?
    kGSEventScrollWheel = 22,
    kGSEventAccelerate = 23,
    kGSEventProximityStateChanged = 24,
    kGSEventDeviceOrientationChanged = 50,
    kGSAppPreferencesChanged = 60,
    kGSEventUserDefaultsDidChange = 60, // backward compatibility.
    
    kGSEventResetIdleTimer = 100,
    kGSEventResetIdleDuration = 101,
    kGSEventProcessScript = 200,
    kGSEventDumpUIHierarchy = 500,
    kGSEventDumpScreenContents = 501,
    
    kGSEventMenuButtonDown = 1000,
    kGSEventMenuButtonUp = 1001,
    kGSEventVolumeChanged = 1006,
    kGSEventVolumeUpButtonDown = 1006,
    kGSEventVolumeUpButtonUp = 1007,
    kGSEventVolumeDownButtonDown = 1008,
    kGSEventVolumeDownButtonUp = 1009,
    kGSEventLockButtonDown = 1010,
    kGSEventLockButtonUp = 1011,
    kGSEventRingerOff = 1012,
    kGSEventRingerOn = 1013,
    kGSEventRingerChanged = 1013,   // backward compatibility.
    kGSEventLockDevice = 1014,
    kGSEventStatusBarMouseDown = 1015,
    kGSEventStatusBarMouseDragged = 1016,
    kGSEventStatusBarMouseUp = 1017,
    kGSEventHeadsetButtonDown = 1018,
    kGSEventHeadsetButtonUp = 1019,
    kGSEventMotionBegin = 1020,
    kGSEventHeadsetAvailabilityChanged = 1021,
    kGSEventMediaKeyDown = 1022,    // â‰¥3.2
    kGSEventMediaKeyUp = 1023,  // â‰¥3.2
    
    kGSEventVibrate = 1100,
    kGSEventSetBacklightFactor = 1102,
    kGSEventSetBacklightLevel = 1103,
    
    kGSEventApplicationLaunch = 2000,
    kGSEventAnotherApplicationFinishedLaunching = 2001,
    kGSEventSetAppThreadPriority = 2002,
    kGSEventApplicationResume = 2003,
    kGSEventApplicationDidEndResumeAnimation = 2004,
    kGSEventApplicationBeginSuspendAnimation = 2005,
    kGSEventApplicationHandleTestURL = 2006,
    kGSEventApplicationSuspendEventsOnly = 2007,
    kGSEventApplicationSuspend = 2008,
    kGSEventApplicationExit = 2009,
    kGSEventQuitTopApplication = 2010,
    kGSEventApplicationUpdateSuspendedSettings = 2011,
    
    kGSEventHand = 3001,
    
    kGSEventAccessoryAvailabilityChanged = 4000,
    kGSEventAccessoryKeyStateChanged = 4001,
    kGSEventAccessory = 4002,
    
    kGSEventOutOfLineDataRequest = 5000,
    kGSEventOutOfLineDataResponse = 5001,
    
    kGSEventUrgentMemoryWarning = 6000,
    
    kGSEventShouldRouteToFrontMost = 1<<17
} GSEventType;

typedef UInt32 GSEventSubtype;

typedef struct GSEventRecord {
    GSEventType type; // 0x8
    GSEventSubtype subtype; // 0xC
    CGPoint location;       // 0x10
    CGPoint windowLocation; // 0x18
    CFTimeInterval time;    // 0x20
    GSEventFlags flags;
    unsigned short number;
    CFIndex size; // 0x2c
} GSEventRecord;

typedef struct __GSEvent {
    CFRuntimeBase _base;
    GSEventRecord record;
} GSEvent;
typedef struct __GSEvent* GSEventRef;


// Roughly from http://stackoverflow.com/questions/18747759/ios-7-hardware-keyboard-events

@interface PhysicalKeyboardEvent : UIEvent {//UIPhysicalButtonsEvent
    NSString *_modifiedInput;
    NSString *_unmodifiedInput;
    NSString *_shiftModifiedInput;
    NSString *_commandModifiedInput;
    NSString *_markedInput;
    int _modifierFlags;
    int _inputFlags;
    NSString *_privateInput;
}

@property(retain) NSString * _modifiedInput;
@property(retain) NSString * _unmodifiedInput;
@property(retain) NSString * _shiftModifiedInput;
@property(retain) NSString * _commandModifiedInput;
@property(retain) NSString * _markedInput;
@property(retain) NSString * _privateInput;
@property int _modifierFlags;
@property(readonly) int _gsModifierFlags;
@property(readonly) BOOL _isKeyDown;
@property(readonly) long _keyCode;
@property int _inputFlags;

+ (id)_eventWithInput:(id)arg1 inputFlags:(int)arg2;

- (BOOL)isEqual:(id)arg1;
- (void)dealloc;
- (int)type;
- (id)_privateInput;
- (id)_shiftModifiedInput;
- (id)_commandModifiedInput;
- (void)set_inputFlags:(int)arg1;
- (void)set_modifierFlags:(int)arg1;
- (id)_markedInput;
- (void)_privatizeInput;
- (id)_cloneEvent;
- (id)_unmodifiedInput;
- (int)_inputFlags;
- (id)_modifiedInput;
- (int)_gsModifierFlags;
- (long)_keyCode;
- (int)_modifierFlags;
- (BOOL)_matchesKeyCommand:(id)arg1;
- (BOOL)_isKeyDown;
//- (void)_setHIDEvent:(struct __IOHIDEvent { }*)arg1 keyboard:(struct __GSKeyboard { }*)arg2;

@end

@interface UIResponder (KeyCommands)

- (id)_keyCommandForEvent:(id)arg1;

@end

@interface UIEvent(GSEventAddition)

- (id)_gsEvent;

@end

@implementation RLOUIApplication

#pragma mark iOS 7

#ifdef RLO_ENABLED

- (id)_keyCommandForEvent:(PhysicalKeyboardEvent *)event
{
    //Some reason it gets called twice and it's not because of keyup. Keyup seems to not mention it's original key.
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self performSelector:@selector(processEvent:) withObject:event afterDelay:0];
    return [super _keyCommandForEvent:event];
}

- (void)processEvent:(PhysicalKeyboardEvent *)event
{
    long keycode = [event _keyCode];
    BOOL iskeydown = [event _isKeyDown];
    NSString *key = [RLOCharacterMapping stringForKeycode:keycode];
    NSString *keycombo = [RLOCharacterMapping modifiedCharnames:key modifierFlags:[event _gsModifierFlags]];
    NSMutableDictionary *keyinfo = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                             [NSNumber numberWithShort:keycode], @"keycode",
                             [NSNumber numberWithInt:[event _gsModifierFlags]], @"eventFlags",
                             key, @"key",
                             keycombo, @"keycombo",
                             nil];
    if (! iskeydown) {
        keyinfo[@"event"] = @"KeyUp";
    }
    [RLOBundleUpdater keyComboEvent:keyinfo synthetic:NO];
}

#endif

#pragma mark iOS 6

// Code adapted from: http://nacho4d-nacho4d.blogspot.de/2012/01/catching-keyboard-events-in-ios.html

#ifdef RLO_ENABLED
// This does not work any more with iOS 7.
#ifndef __IPHONE_7_0

- (void)sendEvent:(UIEvent *)event
{
    [super sendEvent:event];
    if ([event respondsToSelector:@selector(_gsEvent)]) {
        // Key events come in form of UIInternalEvents.
        // They contain a GSEvent object which containsan
        // a GSEventRecord among other things
        int *eventMem = (int *)(__bridge void *)[event performSelector:@selector(_gsEvent)];
        if (eventMem) {
            int eventType = eventMem[GSEVENT_TYPE];
            if (eventType == kGSEventKeyDown) {
                int eventFlags = eventMem[GSEVENT_FLAGS];
                int tmp = eventMem[GSEVENTKEY_KEYCODE];
                UniChar *keycode = (UniChar *)&tmp;
                UniChar code = keycode[0];
                NSString *key = [RLOCharacterMapping stringForKeycode:code];
                NSString *keycombo = [RLOCharacterMapping modifiedCharnames:key modifierFlags:eventFlags];
                
                NSDictionary *keyinfo = [[NSDictionary alloc] initWithObjectsAndKeys:
                                          [NSNumber numberWithShort:code], @"keycode",
                                          [NSNumber numberWithInt:eventFlags], @"eventFlags",
                                          key, @"key",
                                          keycombo, @"keycombo",
                                          nil];
                [RLOBundleUpdater keyComboEvent:keyinfo synthetic:NO];
            }
        }
    }
}

#endif
#endif

@end

#endif
#endif
