# RestartLessOften

When programming an iOS or OS X application in Objective-C almost every minor parameter or code change requires a recompilation of the changed sources followed by an application restart to see the change.

This project offers some tools to reduce the number of restarts when adjusting numbers, strings, colors, images, OpenGL shaders, xib files and so forth even code changes can be done with limitations.

To enable your code to use RestartLessOften you have to include some source files into your Xcode project and create a configuration file for your app which you can modify at runtime to feed parameter changes into your app.

## QuickStart

First start `rlo_server.py` in a Terminal window. RestartLessOften comes with two preconfigured examples, one for iOS another for OS X that should just build and run.
When you make changes in `rloconfig.py` and save the file, the app should react to the changed parameter, try this with `backgroundcolor` in `GLExample/rloconfig.py`.
In GLExample at the end of `ViewController.m` you see `self.paused = NO;`. Change this into a YES and just build the app without restarting. The animation should stop immediately because a new version of `ViewController.m` was patched into the running code.

If you get this running you can try to run GLExample on an iOS device which should also work but this is usually more likely to fail. Change `self.paused` several times between YES and NO and build and see if it works for you.

DrawExample is a simple Cocoa app with a `-drawRect:` method in `DrawView.m` that you can modify as well at runtime. Try commenting out some drawing code and just build.

`InstallingRLO.md` explaines all steps necessary to add RestartLessOften into an existing app. There are quite some steps and if you follow everything correctly the code updates still might not work.
`RefactoringForRLO.md` explains how to restructure your code to make better use of RLO.

## The Client-Server Architecture

RestartLessOften tries to be minimally invasive. Because embedding an HTTP server in an app is way more complicated than emitting HTTP requests your Mac is the server-side and your app is the client.
Your app downloads the configuration file as a plist and updates the global dictionary with the current parameter values. Immediately afterwards it starts the next request but the server is blocking the request until some parameter has changed.
 
## The configuration file

The Python script `rloconfig.py` contains your configuration script which actually doesn't contain much code just data with the standard data types int, float, string, array, dict and Data.
Here is an excerpt of a `rloconfig.py` where you can see some nested dictionaries.


```python
def rloconfiguration():
    T = dict(
              rlo = dict(
                  log_http_requests = 0,
                  generate_urls = 0,
                  generate_urls_if_num_diffs_less_than = 10,
                  show_nondefault_vars = 1, # 1: show diff once, 2: show diff every time
                  show_config_diffs = 1,
                  show_config_diffs_if_num_diffs_less_than = 10,
                  persistent_updates = 0,
                  serverfilecache = 1,
                  use_bundle_load = 0,
                  supress_warning = 0,
                  delete_screenshots = 1,
                  # Directories are either absolute or relative to this directory of this rloconfig.py file.
                  testdata_directories = [
                      "GLExample/Shaders"
                      ],
              ),
              watch_files = ['*.vsh', '*.fsh'],
              # watch_xibfiles = [],
              # ignore_files = [],

              # ---------------- Only app specific variables below this point ----

              backgroundcolor = "#A5A5A5FF",
              disable_glkitcube = 0,
              num_triangles = 36,
    )
    return T
```

The `rlo` section is used by `rlo_server.py` and the RLO code inside your app. Some other variables `watch_files`, `watch_xibfiles`,  `ignore_files` are also used by `rlo_server.py` to see if resources of your app have changed.

## Explicit default values

When using RLO it should be very easy to tell what value is used when RLO is either not used (`RLO_ENABLED` is undefined) or when the RLO server is not running.
Each of the RLOGet macros has a second parameter that is the value being used in these cases.
The macro
```objective-c
RLOGetInt(@"num_triangles", 36)
```
will return the current value and the first time it differs from its default this will be logged, e.g.:
```
NDVi: num_triangles (default 36) is currently 12
```

## RLO startup in main.m

You probably know that before `applicationDidFinishLaunching:` is called a lot of your code has already run.
To give all of your code a chance to run with the current `rloconfig.py` the first config download is synchronous on the main-thread before the usual program startup with `UIApplicationMain` or `NSApplicationMain` begins. All following config downloads are on a background thread.

## The RLO Server

You start one `rlo_server.py` on your Mac which accepts and handles requests from several different apps at once, each request tells the server to which app and `rloconfig.py` it belongs.

## XcAddedMarkup

The Xcode plugin [XcAddedMarkup](https://github.com/mikr/XcAddedMarkup) supports RLO in that it recognizes macros like `RLOGetInt(@"num_triangles, 36)` in the source code when the cursor is positioned in a macro call. In this situation XcAddedMarkup tries to get the most recent RLO config from the RLO server and if it downloads a proper config it shows a popup with a slider and text field. Changing the slider or textfield is immediately reflected in the running application. The parameter change is not persistent, if you want to keep the current value it must be copied as default parameter or into the `rloconfig.py`.

A default slider of XcAddedMarkup has a default range from 0 to 100 which is almost always wrong. By adding a dictionary next to and named as the parameter itself followed by `_spec` the min and max values for the slider can be specified.

```python
num_triangles = 36,
num_triangles_spec = dict(
	min=0, max=36
)
```

## RLO_ENABLED

RestartLessOften only uses `#ifdef RLO_ENABLED` to include RLO code into your app.
If you use this:
```objective-c
#if DEBUG
#define RLO_ENABLED
#endif
```
or something else is your choice but please make sure that you never distribute an application where `RLO_ENABLED` was still defined. It would send requests to a host with your local hostname on the network of your users which would be embarrassing for you and me.  
On the upside if you get this one right you never have to remove RLO code from your app before building the distribution binary.
All RLO classes are within '#ifdef RLO_ENABLED ... #endif' the only thing remaining in effect for a distribution build are the RLO macros that will either do nothing, return 0, NO, nil or the given default value for RLOGet macros (see `RLODefinitions.h`).

Another goal of RestartLessOften is that if `RLO_ENABLED` is undefined no code at all should be included that is only needed by RLO and not the app itself. See `Classes without -dealloc` for an example.

## Classes without `-dealloc`

If `RLOremoveObserver(self)` would be the only thing in your `-dealloc` method, an empty `-dealloc` would still remain when `RLO_ENABLED` is not defined. 
To remove `-dealloc` for a clean distribution build you use this:
```objective-c
#ifdef RLO_ENABLED
- (void)dealloc
{
    RLOremoveObserver(self);
}
#endif
```
But make sure to remove the `#ifdef RLO_ENABLED` if any other code gets added to the `-dealloc` of this class.

## Keyboard support

RestartLessOften supports sending key events from the Mac keyboard into the iOS Simulator. This makes use of undocumented APIs and is likely to break with a minor update of the iOS Simulator. If you really want to send key events into your app that is running on the device, you can start build and run RLOApp and keep it in the foreground. Key events are send from `RLOApp` via the RLO server to your app. See `GLExample/Viewcontroller.m` how to handle key events. This method of forwarding key events is also a bit brittle but may be useful nonetheless.

## Changing Parameters via HTTP requests

When you want to change parameters like `num_triangles` in the GLExample many times like toggling back and forth between 12 and 36, changing the `rloconfig.py` manually and saving each time becomes tiresome. When `rlo.generate_urls` is set each change results in a URL being printed to the console. Change `num_triangles` from 36 to 12 and save `rloconfig.py` and this URL appears in the console.
```
http://localhost:8080/update/GLExample?num_triangles=12
```
Change it back to 36 and you get the URL with `num_triangles=36`. You can now use these URLs anywhere on your Mac to change this parameter by clicking on one of the URLs.
If you change several parameters and save them at once they will appear together in a single URL.

Different types of URLs are supported each with their own pros and cons.

1. `rlo://` This is a custom URL scheme which needs [XcAddedMarkup](https://github.com/mikr/XcAddedMarkup) and RLOApp which is included with RestartLessOften. These can be clicked directly in the Xcode console after they have been printed.
2. `vemmi://` Xcode recognizes these as valid URLs, RLOApp is registered for them and if they are clicked the default browser does not open which is nice.
3. `http://hostname.local` These work on your local network.
4. `http://localhost` Those are preferable if you want to share links with others.

Advanced users may want to compile and run `RLOApp` with
```objective-c
[NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
```
present in `AppDelegate.m`. This allows clicking on rlo: or vemmi: links in your source code with no application annoyingly opening itself in the front. With this you can switch rapidly between parameter sets by embedding vemmi: links for example in source comments near the code that deals with them.

## Enabling C++ sources

If you want code updates in Objective-C++ files, make a copy of RLORebuildCode.m named RLORebuildCode.mm and add it to the Xcode project only for the target RLOUpdaterBundleGLExample. The script `rlo_newerfiles.py` generates imports for Objective-C++ files into RLORebuildCode.mm. The need for this distinction is that the default include paths for Objective-C and Objective-C++ are different and this is handled by having these two files.

## Known Problems

* auto-synthesized properties
	-	I have had problems updating code in classes with auto-synthesized properties, which resulted in the new code having a different class layout.
Manually adding the synthesize `@synthesize theproperty=_theproperty;` fixed these kind of problems. This might have been caused by certain clang versions in the past and may not be a problem any more. 
* class layout changes
	
	- when adding, removing or renaming an instance variable or property a code update requires a restart of the app.

## Security

The RLO server should only deliver files that are listed in the `testdata_directories` and below but RLO does not contain security measures to run safely between your app and the server on a hostile network.

## Documentation

There is a lot more documentation to be written about this project but first I wanted to get it out there to see if at least the preconfigured examples run for most users. Feedback is welcome.

## Credits

RestartLessOften was written by [Michael Krause](http://krause-software.com).

John Holdsworth must be credited for creating Injection for Xcode https://github.com/johnno1962/injectionforxcode
from where I picked up the code update technique via bundles. You should definitely try out his tool which is much easier to set up than RestartLessOften and may be more suitable for you.

The Dynamic code injection Tool https://github.com/DyCI/dyci-main helped a lot in requiring less manual modifications of the users source code to enable code updates.

## License

RestartLessOften is available under the MIT license. See the LICENSE file for more info.
