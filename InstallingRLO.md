# Installing RestartLessOften

RestartLessOften comes with an example application 'GLExample' that is already set up to work with RLO.
I will describe how to set up this example starting from scratch.

# Create GLExample

In Xcode create a new project based on the iOS application template named 'OpenGL Game', name it GLExample and save it in the Examples directory of RestartLessOften.

## The Updater Bundle

Create a new target (iOS->Other->Cocoa Touch Unit Testing Bundle) named RLOUpdaterBundleGLExample of type XCTest.

In the build settings of RLOUpdaterBundleGLExample delete all frameworks from 'Other linker flags' ($(inherited) and XCTest). You have to double click in the column RLOUpdaterBundleGLExample to see these in the first place because they are defaults but they have to go. Then the Resolved column should be empty for 'Other linker flags'.

Also set 'Generate Debug Symbols' to NO to avoid a build warning.

Click your way to the build phases of RLOUpdaterBundleGLExample.

*	Select Editor->Add Build Phase->Add Run Script Build Phase
*	Enter this as shell script: `exec ${SRCROOT}/../../scripts/rlo_onbuildstart.sh RLOUpdaterBundle${TARGET_NAME}.xctest`
*	Rename the build phase name from  'Run Script' to `rlo_onbuildstart`
*	Move this build phase just below 'Target Dependencies' so it starts before the `Compile Sources` phase
*	Select Editor->Add Build Phase->Add Run Script Build Phase again
*	This is the script to run: `exec ${SRCROOT}/../../scripts/rlo_onbuildend.sh`
*	Rename the build phase name from 'Run Script' to `rlo_onbuildend`
*	Remove the target dependency GLExample
*   Add all frameworks your app is using under `Link Binary With Libraries`
*	Repeat the creation of these two build phases for the target GLExample as well
*	In the target GLExample add RLOUpdaterBundleGLExample as target depencency
*	Delete the file `RLOUpdaterBundleGLExample.m`
*	Add `#import "GLExample-Prefix.pch"` to RLOUpdaterBundleGLExample-Prefix.pch 

Create a copy of the directory RLORebuildCode in templates into Examples/GLExample and add this copy to the Xcode project only for the target RLOUpdaterBundleGLExample.

# Add RLO to the Xcode project

Add the directory `RLOClasses` to your Xcode project for the GLExample target.

Add these preprocessor statements
```objective-c
#if DEBUG
    #define RLO_ENABLED
    #define RLO_CONFIG_PATH (RLO_BUNDLEUPDATE_SRCROOT "/rloconfig.py")
#endif
#include "RLODefinitions.h"
```
to GLExample-Prefix.pch at the end of the `#ifdef __OBJC__` block.


and this checked import:
```objective.c
#ifdef RLO_ENABLED
#import "RLODynamicEnvironment.h"
#endif
```
to `main.m` as well as the startup code
```objective.c
#ifdef RLO_ENABLED
        RLO_WATCH_CODE_UPDATES;
        RLO_INIT_CONFIGURATION(RLO_CONFIG_PATH, RLO_SERVERURL);
        RLO_START_CONF_LOADER;
#endif
```
to `main.m` above `return UIApplicationMain`.
This must be in an `@autoreleasepool`, add one if necessary.

# Enabling code updates for a class

Copy the `rloconfig.py` from `templates` into `Examples/GLExample`.

# Enabling code updates for a class

In the file `ViewController.m` add this line
```objective-c
RLOaddObserver(self, @selector(rloNotification:));
```
at the end of `-viewDidLoad` and
```objective-c
RLOremoveObserver(self);
```
at the end of `-dealloc`.

# -rloNotification:

If almost any kind of thing changes like file content, parameters, code rebuild, some special key was pressed etc. `-rloNotification:` is called.
Add this before the `@end` of `ViewController.m`
```objective-c
#ifdef RLO_ENABLED

- (void)rloNotification:(NSNotification *)aNotification
{
    NSLog(@"rloNotification: %@", aNotification);
    self.paused = NO;
}

#endif

If you followed all the steps correctly you should be able to change the log message or set `self.paused` to 
YES and building the project should result in the new code being executed.
```

# Setting up your own project

You have to adjust the paths in the build phases for `rlo_onbuildstart.sh` and `rlo_onbuildend.sh`.

