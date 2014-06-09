//
//  main.m
//  MixedDrawExample
//
//  Created by michael on 12/7/13.
//  Copyright (c) 2013 Michael Krause. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#ifdef RLO_ENABLED
#import "RLODynamicEnvironment.h"
#endif

int main(int argc, const char * argv[])
{
    @autoreleasepool {
#ifdef RLO_ENABLED
        RLO_WATCH_CODE_UPDATES;
        RLO_INIT_CONFIGURATION(RLO_CONFIG_PATH, RLO_SERVERURL);
        RLO_START_CONF_LOADER;
#endif
        return NSApplicationMain(argc, argv);
    }
}
