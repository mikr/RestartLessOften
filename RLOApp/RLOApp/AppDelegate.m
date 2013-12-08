//
//  AppDelegate.m
//  RLOApp
//
//  Created by michael on 7/23/12.
//  Copyright (c) 2010-2013 Michael Krause ( http://krause-software.com/ ). All rights reserved.
//

#import "AppDelegate.h"
#import <Carbon/Carbon.h>
#import "RLOCharacterMapping.h"
#import "NSString+URLAdditions.h"


@implementation AppDelegate

@synthesize window = _window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    //[NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    // Register ourselves as a URL handler for this URL
    NSAppleEventManager *appleEventManager = [NSAppleEventManager sharedAppleEventManager];
    [appleEventManager setEventHandler:self andSelector:@selector(handleGetURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
    
//    [NSEvent addGlobalMonitorForEventsMatchingMask:NSKeyDownMask handler:^(NSEvent *event) {
//        NSString *chars = [[event characters] lowercaseString];
//        if (chars.length > 0) {
//            UniChar c = [chars characterAtIndex:0];
//            if (c == 0xf704) {  // F1-key
//                NSApplicationActivationPolicy policy = [NSApp activationPolicy];
//                NSApplicationActivationPolicy newpolicy = policy == NSApplicationActivationPolicyRegular ? NSApplicationActivationPolicyProhibited : NSApplicationActivationPolicyRegular;
//                [NSApp setActivationPolicy:newpolicy];
//                if (newpolicy == NSApplicationActivationPolicyRegular) {
//                    [[NSApplication sharedApplication] hide:self];
//                }
//            }
//        }
//    }];
    
    gevhandler = [[GlobalEventHandler alloc] init];
    [gevhandler installKeyHandler];
    gevhandler.capturesKeyboard = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(globalEvent:) name:GlobalEventHandlerNotification object:gevhandler];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(globalEvent:) name:GlobalEventHandlerNotification object:self.window.contentView];
}

- (void)globalEvent:(NSNotification *)aNotification
{
    NSMutableDictionary *userInfo = (NSMutableDictionary *)[aNotification userInfo];
    
    if (! [userInfo[@"skipfrontappcheck"] isEqual:@YES]) {
        NSRunningApplication *frontapp = [[NSWorkspace sharedWorkspace] frontmostApplication];
        if (! [frontapp.bundleIdentifier isEqualToString:@"com.apple.iphonesimulator"]) {
            userInfo[@"handled"] = @NO;
            return;
        }
    }

    NSString *keycombo = [userInfo objectForKey:@"keycombo"];
    NSString *event = [userInfo objectForKey:@"event"];
    if ([keycombo isEqualToString:@"Shift-F1"]) {
       [[NSApplication sharedApplication] terminate:self];
    } else if ([keycombo isEqualToString:@"F1"] && [event isEqualToString:@"KeyDown"]) {
        [self toggleView];
    }
    
    NSString *querystring = [userInfo urlEncodedString];
    [self forwardEvent:querystring];
    
    userInfo[@"handled"] = @YES;
}

- (void)toggleView
{
    capturesKeyboard = ! capturesKeyboard;
    NSApplicationActivationPolicy newpolicy = capturesKeyboard ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyProhibited;
    [NSApp setActivationPolicy:newpolicy];
    if (newpolicy == NSApplicationActivationPolicyRegular) {
        [_window setHidesOnDeactivate:NO];
        [[NSApplication sharedApplication] unhide:self];
        [_window orderFront:self];
        //[NSApp activateIgnoringOtherApps:YES];
    } else {
        [_window setHidesOnDeactivate:YES];
        [[NSApplication sharedApplication] hide:self];
    }
}

- (void)forwardEvent:(NSString *)url
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        [self forwardRequest:[NSString stringWithFormat:@"rlo://app/event?%@", url] filename:nil];
    });
}

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
    NSString *url = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    //NSLog(@"handleGetURLEvent: %@", url);
    [self forwardRequest:url filename:nil];
    [[NSApplication sharedApplication] unhide:self];
}

- (BOOL)forwardRequest:(NSString *)reqURL filename:(NSString *)filenames
{
    NSHTTPURLResponse *response;
    NSError *error = nil;
    NSString *http_server = @"http://localhost:8080";

    NSURL *u = [NSURL URLWithString:reqURL];
    NSString *path = [u path];
    NSString *query = [u query];
    NSString *host = [u host];

    NSString *myRequestString = [NSString stringWithFormat:@"%@%@/%@", http_server, path, host];
    NSURL *url = [NSURL URLWithString:myRequestString];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:@"POST"];
    NSData *postdata = [query dataUsingEncoding:NSUTF8StringEncoding];
    [request setHTTPBody:postdata];
    NSData *responsedata = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if ([responsedata length] > 0) {
        NSLog(@"responsedata: %@", responsedata);
        return NO;
    }
    if (error) {
        NSLog(@"Error URL: %@", url);
        return NO;
    }
    return YES;
}

- (void)application:(NSApplication *)theApplication
          openFiles:(NSArray *)filenames
{
    NSLog(@"application: %@", theApplication);
    NSLog(@"filenames: %@", filenames); 
}

//- (void)applicationWillBecomeActive:(NSNotification *)aNotification
//{
//    // TODO: it would be nice if the app could stay in background when handleGetURLEvent is going to be called
//    [[NSApplication sharedApplication] deactivate];
//    [[NSApplication sharedApplication] hide:self];
//    NSLog(@"applicationWillBecomeActive");
//
//}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:GlobalEventHandlerNotification object:gevhandler];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:GlobalEventHandlerNotification object:self.window.contentView];
}

@end
