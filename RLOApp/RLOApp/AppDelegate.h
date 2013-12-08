//
//  AppDelegate.h
//  RLOApp
//
//  Created by michael on 7/23/12.
//  Copyright (c) 2010-2013 Michael Krause ( http://krause-software.com/ ). All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GlobalEventHandler.h"
#import "RLOMainView.h"

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    BOOL capturesKeyboard;
    
    GlobalEventHandler *gevhandler;
}

- (void)toggleView;
- (void)forwardEvent:(NSString *)url;

@property (assign) IBOutlet NSWindow *window;

@end
