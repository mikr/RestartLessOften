//
// RLOBundleUpdater.h
//
// Copyright (c) 2013 Michael Krause ( http://krause-software.com/ )
//

#ifndef RLOBundleUpdater_h
#define RLOBundleUpdater_h

#ifdef RLO_ENABLED
#ifdef __OBJC__

#import "RLOUtils.h"

enum RLOCheckMethod {
    RLO_USE_POLLING,
    RLO_USE_FILESYSTEM_EVENTS
};
typedef enum RLOCheckMethod RLOCheckMethod;

typedef NS_ENUM(NSUInteger, KeyEventStatus) {
    RLOKEYNONE = 0,
    RLOKEYDOWN,
    RLOKEYUP
};

@interface RLOBundleUpdater : NSObject

+ (void)startChecking:(RLOCheckMethod)method;
+ (void)loadNewBundle:(NSArray *)changedpaths;
+ (BOOL)containsChangedClassname:(NSString *)classnames notification:(NSNotification *)aNotification;
+ (BOOL)hasKeyPress:(NSString *)theKeycombo notification:(NSNotification *)aNotification;
+ (BOOL)hasKeyCombo:(NSString *)theKeycombo notification:(NSNotification *)aNotification;
+ (BOOL)hasKeyUpCombo:(NSString *)theKeycombo notification:(NSNotification *)aNotification;
+ (void)keyComboEvent:(NSDictionary *)keyinfo synthetic:(BOOL)synthetic;
+ (KeyEventStatus)keyStatus:(NSString *)theKeycombo notification:(NSNotification *)aNotification;

@end

#endif
#endif
#endif
