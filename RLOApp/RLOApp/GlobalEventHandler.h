//
//  GlobalEventHandler.h
//  RLOApp
//
//  Created by michael on 1/30/13.
//
//

#import <Foundation/Foundation.h>

extern NSString * const GlobalEventHandlerNotification;

@interface GlobalEventHandler : NSObject {
    BOOL capturesKeyboard;

    CFRunLoopSourceRef runLoopSource;
    CFMachPortRef      eventTap;
}

@property (assign) BOOL capturesKeyboard;

- (void)installKeyHandler;

@end
