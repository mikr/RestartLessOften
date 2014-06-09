#ifdef RLO_ENABLED

//
// RLOBundleUpdater.m
//
// Copyright (c) 2013 Michael Krause ( http://krause-software.com/ )
//

#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <dlfcn.h>
#include <objc/runtime.h>

#import "RLOBundleUpdater.h"
#import "RLOUnbundler.h"
#import "RLOUtils.h"

// RLODynamicEnvironment.h is generated before every build, so Xcode might not find this file before the first build.
#import "RLODynamicEnvironment.h"

#if !TARGET_OS_IPHONE
#ifdef RLO_HIDREMOTE_ENABLED
#import "RLOHidRemote.h"
#endif
#endif


#define RLO_BUNDLENAME @"RLOUpdaterBundle"

// To use simple polling of the bundle modification date instead of  filesystem events set this value to 0.
#define RLO_FSEVENTS_INTERVAL 0.01
#define RLO_POLLING_INTERVAL 0.1

#define RLOLog NSLog

#define RLO_BUILDSTART_HEADER @"RLO-Buildstart"
#define RLO_ANNOUNCETIME_HEADER @"RLO-Announcetime"
#define RLO_RESPONSETIME_HEADER @"RLO-Responsetime"
#define RLO_RESPONSEARRIVAL_HEADER @"RLO-Responsearrival"

@interface KeyComboEvent : NSObject {
    double last_nonsynthetic;
    double nonsynthetic_rate;
    BOOL wants_keyup;
    BOOL wants_keypress;
}
@property (nonatomic) double last_nonsynthetic;
@property (nonatomic) double nonsynthetic_rate;
@property (nonatomic) BOOL wants_keyup;
@property (nonatomic) BOOL wants_keypress;
@end

@implementation KeyComboEvent
@synthesize last_nonsynthetic;
@synthesize nonsynthetic_rate;
@synthesize wants_keyup;
@synthesize wants_keypress;
@end


@implementation RLOBundleUpdater

+ (void)startChecking:(RLOCheckMethod)method
{
    RLOAddResponseHandler(self);

#if TARGET_OS_EMBEDDED
    // Polling the filesystem for a freshly changed bundle makes no sense on a device.
    // Instead we look for bundles arriving from the RLO server.
    return;
#else

    NSMutableDictionary *threaddict = [[NSThread currentThread] threadDictionary];
#if !TARGET_OS_IPHONE
#ifdef RLO_HIDREMOTE_ENABLED
    NSString *hidremote_key = @"hidremote_key";
    RLOHidRemote *hidremote = [threaddict objectForKey:hidremote_key];
    if (! hidremote) {
        hidremote = [[RLOHidRemote alloc] init];
        [threaddict setObject:hidremote forKey:hidremote_key];
    }
#endif
#endif

    NSString *background_thread_active_key = @"background_thread_active__key";
    id thread_active = [threaddict objectForKey:background_thread_active_key];
    if (! thread_active) {
#if !TARGET_OS_IPHONE
        if (method == RLO_USE_FILESYSTEM_EVENTS) {
            [self initializeEventStream];
        } else {
            [self performSelectorInBackground:@selector(checkForNewBundles) withObject:nil];
        }
#else
        [self performSelectorInBackground:@selector(checkForNewBundles) withObject:nil];
#endif
        [threaddict setObject:@"active" forKey:background_thread_active_key];
    }
#endif
}

+ (BOOL)handleRLOServerResponse:(NSHTTPURLResponse *)response data:(NSData *)data succeeded:(BOOL)succeeded
{
    NSError *error = nil;
    double current_millis = [self milliseconds];

    BOOL handled = NO;
    
    NSDictionary *all_headers = [response allHeaderFields];
    
    NSString *rloresponsetype = [all_headers objectForKey:@"RLOResponseType"];
    if (rloresponsetype && [rloresponsetype isEqualToString:@"RLOEvent"]) {
        NSDictionary *eventparameters = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&error];
        NSArray *events = [eventparameters objectForKey:@"events"];
        for (NSDictionary *event in events) {
            NSMutableDictionary *resultinfo = [event mutableCopy];
            if ([[resultinfo objectForKey:@"event"] isEqualToString:@"KeyUp"]) {
                [resultinfo setObject:@YES forKey:@"keyup"];
            }
            [[self class] notifyRLOConfigurationChangeOnMainThread:resultinfo];
        }
        return YES;
    }
    
    NSString *filename = [all_headers objectForKey:@"Filename"];

    if (! filename) {
        return NO;
    }

    filename = [filename stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    if ([filename hasSuffix:@".bundle"] || [filename hasSuffix:@".xctest"]) {
        // We consider this file as handled no matter if anything goes wrong now.
        handled = YES;
        NSDictionary *bundledict = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&error];
        
        if (! bundledict) {
            RLOLog(@"RLOBundleUpdater could not create a dictionary from the server response: %@", error);
            return handled;
        }

        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cachedir = [paths lastObject];
        NSString *destpath = [self reloadbundlePath:cachedir];
        BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:destpath withIntermediateDirectories:NO attributes:nil error:&error];
        if (! success) {
            RLOLog(@"Error creating dir: %@ %@", destpath, error);
            return handled;
        }
        success = [RLOUnbundler storeDirectory:bundledict root:destpath];
        if (! success) {
            RLOLog(@"Error unbundling reload bundle into:%@", destpath);
            return handled;
        }
        
        NSString *bundlepath = [destpath stringByAppendingPathComponent:filename];
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:all_headers];
        [dict setObject:[NSString stringWithFormat:@"%f", current_millis] forKey:RLO_RESPONSEARRIVAL_HEADER];
        [self loadBundleFromPath:bundlepath userInfo:dict];
    }
    return handled;
}

static NSDate *oldBundleModificationDate;

+ (NSString *)executableName:(NSString *)bundlepath
{
    NSString *filename = [bundlepath lastPathComponent];
    NSString *exename = [filename stringByDeletingPathExtension];
    return exename;
}

+ (NSString *)pathByAppendingExecutable:(NSString *)bundlepath
{
    NSString *bundle_executable_path = bundlepath;
#if !TARGET_OS_IPHONE
    bundle_executable_path = [bundle_executable_path stringByAppendingPathComponent:@"Contents/MacOS"];
#endif
    bundle_executable_path = [bundle_executable_path stringByAppendingPathComponent:[self executableName:RLO_BUNDLEUPDATE_BUNDLEPATH]];
    return bundle_executable_path;
}

+ (NSDate *)bundleModificationDate
{
    NSString *bundle_executable_path = RLO_BUNDLEUPDATE_BUNDLEPATH;
    bundle_executable_path = [self pathByAppendingExecutable:bundle_executable_path];
    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDictionary *attrs = [fileManager attributesOfItemAtPath:bundle_executable_path error:&error];
    return [attrs objectForKey:NSFileModificationDate];
}

+ (void)updateBundleModificationDate
{
    oldBundleModificationDate = [self bundleModificationDate];
}

+ (BOOL)bundleModificationDateChanged
{
    NSDate *newdate = [self bundleModificationDate];
    return  (oldBundleModificationDate && newdate && ! [oldBundleModificationDate isEqualToDate:newdate]);
}

+ (void)checkForNewBundles
{
    @autoreleasepool {
        [self updateBundleModificationDate];
        while (1) {
            if ([self bundleModificationDateChanged]) {
                [self loadNewBundle:nil];
                [self updateBundleModificationDate];
            } else {
                [NSThread sleepForTimeInterval:RLO_POLLING_INTERVAL];
            }
        }
    }
}

#if !TARGET_OS_IPHONE

void fsevents_callback(ConstFSEventStreamRef streamRef,
                       void *userData,
                       size_t numEvents,
                       void *eventPaths,
                       const FSEventStreamEventFlags eventFlags[],
                       const FSEventStreamEventId eventIds[])
{
    NSMutableArray *changed_paths = [NSMutableArray array];
    for (int i=0; i < numEvents; i++){
        NSString *path = [(__bridge NSArray *)eventPaths objectAtIndex:i];
        [changed_paths addObject:path];
    }
    if ([changed_paths count] > 0) {
        Class thisclass = (__bridge Class)userData;
        if ([thisclass bundleModificationDateChanged]) {
            [thisclass loadNewBundle:changed_paths];
            [thisclass updateBundleModificationDate];
        }
    }
}

+ (void)initializeEventStream
{
    void *appPointer = (__bridge void *)self;
    
    FSEventStreamContext context = {0, appPointer, NULL, NULL, NULL};
    NSTimeInterval latency = RLO_FSEVENTS_INTERVAL;
    NSNumber* lastEventId = [NSNumber numberWithInt:0];
    
    NSString *myPath = [RLO_BUNDLEUPDATE_BUNDLEPATH stringByAppendingPathComponent:@"Contents/MacOS"];
    NSArray *pathsToWatch = [NSArray arrayWithObject:myPath];
    
    [self updateBundleModificationDate];
    
    FSEventStreamRef stream = FSEventStreamCreate(NULL,
                                                  &fsevents_callback,
                                                  &context,
                                                  (__bridge CFArrayRef) pathsToWatch,
                                                  [lastEventId unsignedLongLongValue],
                                                  (CFAbsoluteTime) latency,
                                                  kFSEventStreamCreateFlagUseCFTypes
                                                  );
    
    FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    FSEventStreamStart(stream);
}

#endif

+ (NSMutableArray *)oldBundles
{
    NSMutableDictionary *threaddict = [[NSThread currentThread] threadDictionary];
    NSString *oldbundles_key = @"RLOBundleUpdater-oldbundles";
    NSMutableArray *oldbundles = [threaddict objectForKey:oldbundles_key];
    if (! oldbundles) {
        oldbundles = [NSMutableArray array];
        [threaddict setObject:oldbundles forKey:oldbundles_key];
    }
    return oldbundles;
}

+ (NSString *)reloadbundlePath:(NSString *)directory
{
    NSTimeInterval timeInterval = [NSDate timeIntervalSinceReferenceDate];
    return [NSString stringWithFormat:@"%@/reload%.0f.bundle", directory, timeInterval * 1000.0];
}

+ (void)loadNewBundle:(NSArray *)changedpaths
{
    BOOL success;

    // Unload all previously loaded bundles except the last one
    // [self unloadOldBundles:[self oldbundles]];    
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *srcpath = RLO_BUNDLEUPDATE_BUNDLEPATH;
    // Generate a unique directory name for the new bundle. Replacing the bundle contents
    // in the same directory seems to prevent the loading of the new content.
    NSString *destpath = [self reloadbundlePath:RLO_BUNDLEUPDATE_TMPPATH];

    // The LIVEBUNDLEUPDATER_TMPPATH is deleted with a Product->Clean in Xcode, so we don't need
    // to delete the destination dictionary after e.g. a successful bundle unload or program termination.
    NSError *error = nil;
    success = [fileManager copyItemAtPath:srcpath toPath:destpath error:&error];
    if (success) {
        NSDictionary *userInfo = nil;
        NSString *buildstartfile = [RLO_BUNDLEPROJECT_TMPPATH stringByAppendingPathComponent:@"RLObuildstart.txt"];
        NSString *oldmillis_text = [NSString stringWithContentsOfFile:buildstartfile usedEncoding:nil error:NULL];
        if (oldmillis_text) {
            userInfo = @{RLO_BUILDSTART_HEADER: oldmillis_text};
        }
        [self loadBundleFromPath:destpath userInfo:userInfo];
    } else {
        RLOLog(@"The new bundle could not be copied to the destination directory: %@", error);
    }
}

+ (void)loadBundleFromPath:(NSDictionary *)parameters
{
    BOOL use_bundle_load = RLOGetInt(@"rlo.use_bundle_load", 0);
    
    NSString *destpath = [parameters objectForKey:@"destpath"];
    NSDictionary *userInfo = [parameters objectForKey:@"userInfo"];

    NSString *bundle_executable_path = destpath;
    bundle_executable_path = [self pathByAppendingExecutable:bundle_executable_path];
    int fd;
    fpos_t pos;
    BOOL supress_warning = RLOGetInt(@"rlo.supress_warning", 0);
    if (supress_warning) {
        fflush(stderr);
        fgetpos(stderr, &pos);
        fd = dup(fileno(stderr));
        freopen("/dev/null", "w", stderr);
    }

    BOOL success = NO;
    NSBundle *new_bundle = nil;
    NSMutableSet *currentClassesSet = nil;
    if (use_bundle_load) {
        new_bundle = [NSBundle bundleWithPath:destpath];
        success = [new_bundle load];
    } else {
        NSMutableSet *classesSet = [self currentClassesSet];
        void *libHandle = dlopen([bundle_executable_path cStringUsingEncoding:NSUTF8StringEncoding], RTLD_NOW | RTLD_GLOBAL);
        char *err = dlerror();
        currentClassesSet = [self currentClassesSet];
        [currentClassesSet minusSet:classesSet];
        success = libHandle && !err && [currentClassesSet count];
    }
    
    if (supress_warning) {
        fflush(stderr);
        dup2(fd, fileno(stderr));
        close(fd);
        clearerr(stderr);
        fsetpos(stderr, &pos);        /* for C9X */
    }
    
    if (success) {
        if (use_bundle_load) {
            [[self oldBundles] addObject:new_bundle];
        } else {
            [self performInjectionWithClassesInSet:currentClassesSet];
        }

        [self showBuildUpdateTime:userInfo];
        [[self class] notifyRLOConfigurationChangeOnMainThread:@{@"changedClasses": [self changedClassNames:currentClassesSet]}];
    } else {
        RLOLog(@"Error: the new bundle (%@) could not be loaded", bundle_executable_path);
    }
}

+ (void)notifyRLOConfigurationChangeOnMainThread:(NSDictionary *)aUserInfo
{
    [[self class] performSelectorOnMainThread:@selector(notifyRLOConfigurationChange:) withObject:aUserInfo waitUntilDone:NO];
}

+ (void)notifyRLOConfigurationChange:(NSDictionary *)aUserInfo
{
    [[NSNotificationCenter defaultCenter] postNotificationName:RLOTIfiNotification object:[self class] userInfo:aUserInfo];
}

/*
 * This method removes the bundle name from a mangled swift class name and adapts the
 * length of the resulting class name in the mangled encoding.
 * E.g.:
 *     [self classNameForBundleClassname:@"_TtC27RLOUpdaterBundleDrawExample10SwiftyView" bundleName:@"RLOUpdaterBundle"]
 *     returns @"_TtC11DrawExample10SwiftyView"
 */
+ (NSString *)classNameForBundleClassname:(NSString *)bundleClassname bundleName:(NSString *)bundleName
{
    NSRange r = [bundleClassname rangeOfString:bundleName];
    if (r.location == NSNotFound || r.location == 0) {
        // There should be a number preceding the bundleName.
        return nil;
    }
    NSString *suffix = [bundleClassname substringFromIndex:NSMaxRange(r)];
    NSInteger digitloc = r.location - 1;
    NSUInteger numberbegin = r.location;
    do {
        UniChar digit = [bundleClassname characterAtIndex:digitloc];
        if (digit >= '0' && digit <= '9') {
            numberbegin = digitloc;
            digitloc--;
        } else {
            break;
        }
    } while (digitloc >= 0);
    
    if (numberbegin == r.location) {
        // No number found
        return nil;
    }
    
    NSString *numstring = [bundleClassname substringWithRange:NSMakeRange(numberbegin, r.location - numberbegin)];
    NSString *prefix = [bundleClassname substringToIndex:numberbegin];
    NSInteger cnlength = [numstring integerValue];
    cnlength -= [bundleName length];
    NSString *origClassName = [NSString stringWithFormat:@"%@%ld%@", prefix, cnlength, suffix];
    return origClassName;
}

+ (NSSet *)changedClassNames:(NSSet *)classesSet
{
    NSMutableSet *result = [[NSMutableSet alloc] init];
    for (NSValue *classWrapper in classesSet) {
        Class clz;
        [classWrapper getValue:&clz];
        NSString *className = NSStringFromClass(clz);
        if ([className hasPrefix:@"__"] && [className hasSuffix:@"__"]) {
            // Skip some O_o classes
        } else {
            [result addObject:className];
        }
    }
    return [[NSSet alloc] initWithSet:result];
}

+ (BOOL)containsChangedClassname:(NSString *)classnames notification:(NSNotification *)aNotification
{
    NSSet *changed_classes = [aNotification.userInfo objectForKey:@"changedClasses"];
    for (NSString *classname in [classnames componentsSeparatedByString:@" "]) {
        if ([changed_classes containsObject:classname]) {
            return YES;
        }
    }
    return NO;
}

#pragma mark - Key Event Handling

/*
  The key event handling tries to translate incoming events that were
  gleaned from undocumented APIs or key events coming in via the server
  into a simple string based interface.
  So that events with a userInfo like this arrive:
    userInfo = {
        eventFlags = 131072;
        key = F;
        keycode = 9;
        keycombo = "Shift-F";
        keycomboevent = "<KeyComboEvent: 0x1095542f0>";
    }
 
  I find that being able to press a key combination when the iOS Simulator is running (without screen keyboard)
  and then to invoke a command in response to a keycombo is very useful.
  Unfortunately the attempt to simulate soft key-repeat events made the code way too convoluted.
  This contents of the userInfo keys is likely to change when we figure out a better way but the simplicity
  of strings for keycombo, e.g. @"Up", @"Down", @"Num-Enter", @"Cmd-Shift-D" should be kept.
*/

typedef NS_ENUM(NSUInteger, KeyEventMode) {
    KEYEVENT_INTEREST_PRESS,
    KEYEVENT_INTEREST_COMBO,
    KEYEVENT_INTEREST_UP_COMBO
};

+ (BOOL)hasKeyEvent:(NSString *)theKeycombo notification:(NSNotification *)aNotification eventtype:(KeyEventMode)eventtype
{
    NSString *keycombo = [aNotification.userInfo objectForKey:@"keycombo"];
    if (! [theKeycombo isEqualToString:keycombo]) {
        return NO;
    }
    
    BOOL keyup = [[aNotification.userInfo objectForKey:@"keyup"] boolValue];
    if (eventtype == KEYEVENT_INTEREST_COMBO) {
        return ! keyup;
    }

    KeyComboEvent *ev = [aNotification.userInfo objectForKey:@"keycomboevent"];
    if (ev && [ev isKindOfClass:[KeyComboEvent class]]) {
        if (eventtype == KEYEVENT_INTEREST_PRESS) {
            ev.wants_keypress = YES;
        } else if (eventtype == KEYEVENT_INTEREST_UP_COMBO) {
            ev.wants_keyup = YES;
        }
    }

    if (eventtype == KEYEVENT_INTEREST_PRESS) {
        return ! keyup;
    } else if (eventtype == KEYEVENT_INTEREST_UP_COMBO) {
        return keyup;
    }

    return NO;
}

+ (BOOL)hasKeyPress:(NSString *)theKeycombo notification:(NSNotification *)aNotification
{
    return [self hasKeyEvent:theKeycombo notification:aNotification eventtype:KEYEVENT_INTEREST_PRESS];
}

+ (BOOL)hasKeyCombo:(NSString *)theKeycombo notification:(NSNotification *)aNotification
{
    return [self hasKeyEvent:theKeycombo notification:aNotification eventtype:KEYEVENT_INTEREST_COMBO];
}

+ (BOOL)hasKeyUpCombo:(NSString *)theKeycombo notification:(NSNotification *)aNotification
{
    return [self hasKeyEvent:theKeycombo notification:aNotification eventtype:KEYEVENT_INTEREST_UP_COMBO];
}

+ (KeyEventStatus)keyStatus:(NSString *)theKeycombo notification:(NSNotification *)aNotification
{
    if ([self hasKeyCombo:theKeycombo notification:aNotification]) {
        return RLOKEYDOWN;
    } else if ([self hasKeyUpCombo:theKeycombo notification:aNotification]) {
        return RLOKEYUP;
    } else {
        return RLOKEYNONE;
    }
}

+ (void)keyComboEvent:(NSDictionary *)keyinfo synthetic:(BOOL)synthetic
{
    static NSMutableDictionary *pressedkeys = nil;
    if (! pressedkeys) {
        pressedkeys = [[NSMutableDictionary alloc] init];
    }

    NSString *keycombo = [keyinfo objectForKey:@"keycombo"];
    double now = [self milliseconds];
    KeyComboEvent *ev = [pressedkeys objectForKey:keycombo];
    BOOL first_event = ev == nil;
    if (! ev) {
        ev = [[KeyComboEvent alloc] init];
        ev.nonsynthetic_rate = 0.0;
    }
    double delayInSeconds = 1.0 / 61.0;
    BOOL start_timer = NO;
    BOOL send_notification = NO;
    
    NSMutableDictionary *resultinfo = [NSMutableDictionary dictionaryWithDictionary:keyinfo];
    [resultinfo setObject:ev forKey:@"keycomboevent"];
    if (! synthetic) {
        if (first_event) {
            send_notification = YES;
        } else {
#if !TARGET_OS_IPHONE
            double diff = now - ev.last_nonsynthetic;
            if (diff < 0.250) {
                // This is a fast system generated key repeat after the initial delay of 250ms before the repeat starts.
                ev.nonsynthetic_rate = MAX(now - ev.last_nonsynthetic, ev.nonsynthetic_rate);
            }
#endif
        }
        ev.last_nonsynthetic = now;
        if (first_event) {
#if !TARGET_OS_IPHONE
            start_timer = NO;
#endif
        }
        
        if ([[keyinfo objectForKey:@"event"] isEqualToString:@"KeyUp"]) {
            if (keycombo) {
                [pressedkeys removeObjectForKey:keycombo];
            }
            [resultinfo setObject:@YES forKey:@"keyup"];
            send_notification = YES;
        }
    } else {
        if (now - ev.last_nonsynthetic > 0.260
            || (ev.nonsynthetic_rate != 0.0 && now - ev.last_nonsynthetic > ev.nonsynthetic_rate * 1.2)) {
            // No new events -> key released
            [pressedkeys removeObjectForKey:keycombo];
            [resultinfo setObject:@YES forKey:@"keyup"];
            send_notification = YES;
        } else {
            start_timer = YES;
            send_notification = YES;
        }
    }

    dispatch_time_t when = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    if (send_notification) {
        [RLOUtils clearLastDiffDict];
        [[self class] notifyRLOConfigurationChangeOnMainThread:resultinfo];
        // Only start timer if a listener is interested in a keyup-Event for this combo.
        if (ev.wants_keypress) {
            start_timer = NO;
        }
    }
    if (start_timer) {
        [pressedkeys setObject:ev forKey:keycombo];
        dispatch_after(when, dispatch_get_main_queue(), ^(void){
            [self keyComboEvent:keyinfo synthetic:YES];
        });
    }
}

#pragma mark -

//=======================================================================
// Code adapted from: https://github.com/DyCI/dyci-main

+ (void)performInjectionWithClassesInSet:(NSMutableSet *)classesSet
{
    for (NSValue * classWrapper in classesSet) {
        Class clz;
        [classWrapper getValue:&clz];
        NSString * className = NSStringFromClass(clz);
        if ([className hasPrefix:@"__"] && [className hasSuffix:@"__"]) {
            // Skip some O_o classes
        } else {
            NSString *origClassName = [self classNameForBundleClassname:className bundleName:RLO_BUNDLENAME];
            if (origClassName) {
                Class originalClass = NSClassFromString(origClassName);
                if (originalClass) {
                    [self performInjectionWithClass:clz originalClass:originalClass];
                } else {
                    RLOLog(@"RLOBundleUpdater could not replace class %@ with new class %@ from bundle", origClassName, className);
                }
            } else {
                [self performInjectionWithClass:clz];
            }
        }
    }
}

+ (NSMutableSet *)currentClassesSet
{
    NSMutableSet * classesSet = [NSMutableSet set];
    
    int classesCount = objc_getClassList(NULL, 0);
    Class * classes = NULL;
    if (classesCount > 0) {
        classes = (Class *) malloc(sizeof(Class) * classesCount);
        classesCount = objc_getClassList(classes, classesCount);
        for (int i = 0; i < classesCount; ++i) {
            NSValue * wrappedClass = [NSValue value:&classes[i] withObjCType:@encode(Class)];
            [classesSet addObject:wrappedClass];
        }
        free(classes);
    }
    return classesSet;
}

+ (void)replaceMethodsOfClass:(Class)originalClass withMethodsOfClass:(Class)injectedClass
{
    if (originalClass != injectedClass) {
        // Original class methods
        int i = 0;
        unsigned int mc = 0;
        
        Method * injectedMethodsList = class_copyMethodList(injectedClass, &mc);
        for (i = 0; i < mc; i++) {
            
            Method m = injectedMethodsList[i];
            SEL selector = method_getName(m);
            const char * types = method_getTypeEncoding(m);
            IMP injectedImplementation = method_getImplementation(m);
            
            //  Replacing old implementation with new one
            class_replaceMethod(originalClass, selector, injectedImplementation, types);
        }
    }
}

+ (void)performInjectionWithClass:(Class)injectedClass originalClass:(Class)originalClass
{
    // Replacing instance methods
    [self replaceMethodsOfClass:originalClass withMethodsOfClass:injectedClass];
    
    // Additionally we need to update Class methods (not instance methods) implementations
    [self replaceMethodsOfClass:object_getClass(originalClass) withMethodsOfClass:object_getClass(injectedClass)];
}

+ (void)performInjectionWithClass:(Class)injectedClass
{
    // This is really fun
    // Even if we load two instances of classes with the same name :)
    // NSClassFromString Will return FIRST(Original) Instance. And this is cool!
    NSString * className = [NSString stringWithFormat:@"%s", class_getName(injectedClass)];
    Class originalClass = NSClassFromString(className);
    [self performInjectionWithClass:injectedClass originalClass:originalClass];
}

//=======================================================================

+ (void)loadBundleFromPath:(NSString *)destpath userInfo:(NSDictionary *)userInfo
{
    NSDictionary *parameters = @{@"destpath": destpath, @"userInfo": userInfo};
    [self performSelectorOnMainThread:@selector(loadBundleFromPath:) withObject:parameters waitUntilDone:NO];
}

+ (NSString *)timediff:(NSString *)time1 startTime:(NSString *)startTime
{
    if (! time1 || [time1 length] == 0 || ! startTime || [startTime length] == 0) {
        return @"";
    }
    double a = [startTime doubleValue];
    double b = [time1 doubleValue];
    return [NSString stringWithFormat:@" %.0fms", round((b-a) * 1000.0)];
}

+ (void)showBuildUpdateTime:(NSDictionary *)userInfo
{
    if (userInfo) {
        NSString *text = @"RLO code update:";
        text = [text stringByAppendingString:[self timediff:[userInfo objectForKey:RLO_ANNOUNCETIME_HEADER] startTime:[userInfo objectForKey:RLO_BUILDSTART_HEADER]]];
        text = [text stringByAppendingString:[self timediff:[userInfo objectForKey:RLO_RESPONSETIME_HEADER] startTime:[userInfo objectForKey:RLO_BUILDSTART_HEADER]]];
        text = [text stringByAppendingString:[self timediff:[userInfo objectForKey:RLO_RESPONSEARRIVAL_HEADER] startTime:[userInfo objectForKey:RLO_BUILDSTART_HEADER]]];
        text = [text stringByAppendingString:[self timediff:[NSString stringWithFormat:@"%f", [self milliseconds]] startTime:[userInfo objectForKey:RLO_BUILDSTART_HEADER]]];
        RLOLog(@"%@", text);
    }
}

+ (void)unloadOldBundles:(NSMutableArray *)oldbundles
{
    NSMutableArray *unloaded_bundles = [NSMutableArray array];
    NSBundle *last_bundle = [oldbundles lastObject];
    for (NSBundle *oldbundle in oldbundles) {
        if (oldbundle != last_bundle) {
            BOOL success = [oldbundle unload];
            if (success) {
                [unloaded_bundles addObject:oldbundle];
            }
        }
    }
    [oldbundles removeObjectsInArray:unloaded_bundles];
}

+ (double)milliseconds
{
    struct timeval time;
    gettimeofday(&time, NULL);
    double millis = time.tv_sec + (time.tv_usec / 1000000.0);
    return millis;
}

@end

#endif
