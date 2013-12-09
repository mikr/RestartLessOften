//
//  main.m
//  GLExample
//
//  Created by michael on 12/6/13.
//  Copyright (c) 2013 Michael Krause. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "AppDelegate.h"
#ifdef RLO_ENABLED
#import "RLODynamicEnvironment.h"
#endif

int main(int argc, char * argv[])
{
    @autoreleasepool {
        NSString *appClass = nil;
#ifdef RLO_ENABLED
        appClass = @"RLOUIApplication";
        RLOStartChecking;
        RLO_INIT_CONFIGURATION(RLO_CONFIG_PATH, RLO_SERVERURL);
        RLO_LOAD_CONFIGURATION(nil);
        RLO_START_CONF_LOADER;
#endif
        return UIApplicationMain(argc, argv, appClass, NSStringFromClass([AppDelegate class]));
    }
}
