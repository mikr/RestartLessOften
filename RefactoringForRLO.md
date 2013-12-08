# Refactoring for RLO

Your company may pass the [Joel Test](http://www.joelonsoftware.com/articles/fog0000000043.html) with flying carpets but your app might still not make much use of RestartLessOften.
Often a resource is loaded from a resource bundle for example and it will never change during the runtime of a particular application start.

But still during development the programmer or designer may want to swap resources with different versions to quickly see differences in look or behavior.

We will use the `GLExample` to show some possible steps to enable parameter and resource tweaking.

# Lazy initialization

Writing resource allocation and initialization in a lazy kind of way makes it easy for RLO.
Usually you `nil` out the resources that have changed and the redisplay/reload methods populate these resource with their updated versions. 

# GLExample

We have to do some bookkeeping to properly reload the shaders.

At first add these lines below `@implementation ViewController`
```objective-c
#ifdef RLO_ENABLED

NSMutableDictionary *changedFiles;
BOOL shadersChanged;

- (NSString *)mainBundlePathForResource:(NSString *)name ofType:(NSString *)ext
{
    NSString *resourcename = [name stringByAppendingPathExtension:ext];
    if (changedFiles[resourcename]) {
        return [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:resourcename];
    }
    return [[NSBundle mainBundle] pathForResource:name ofType:ext];
}

- (void)destroyShaders
{
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}

#endif
```

then `-glkView:drawInRect:` must have some additional code.
```objective-c
- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
#ifdef RLO_ENABLED
    if (shadersChanged) {
        shadersChanged = NO;
        [self destroyShaders];
        [self loadShaders];
    }
#endif
```

In `-loadShaders`
replace both occurrences of `[[NSBundle mainBundle] pathForResource:` with our *check-changes-first* method call `[self mainBundlePathForResource:`.


In our `-rloNotification:` we check if a shader file has changed and if this is the case, we download the shader from the RLO server and write it to the cache directory. The shader data is stored in a dictionary under its name where the data could be picked up later. Could `-compileShader:` work with strings or data we would have used the data directly but in this case of a filename parameter we make it work via the cache directory.
The `setNeedsDisplay` is needed if you want to see the shader change also when the GLKView is paused (not animating and constantly redrawing).

In general calling a lot of application code from `-rloNotification:` is not a good idea, for example calling `destroyShaders` and `loadShaders` assume that you are on the correct thread as usual and the OpenGL context is set.
`-rloNotification:` is always called on the main thread to make simple UI changes easy but the bulk of the work should not be done directly from this method if possible.

```objective-c
#ifdef RLO_ENABLED

- (void)rloNotification:(NSNotification *)aNotification
{
    NSLog(@"rloNotification: %@", aNotification);
    self.paused = NO;
    
    NSString *changedfilename = DEBUG_CHANGED_FILE(aNotification);
    if (changedfilename) {
        NSData *data = DEBUG_DOWNLOAD_DATA(changedfilename);
        if (data) {
            NSString *cachedir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
            [data writeToFile:[cachedir stringByAppendingPathComponent:changedfilename] atomically:YES];
            if (! changedFiles) {
                changedFiles = [[NSMutableDictionary alloc] init];
            }
            changedFiles[changedfilename] = data;
            if ([@[@"vsh", @"fsh"] containsObject:[changedfilename pathExtension]]) {
                shadersChanged = YES;
                [self.view setNeedsDisplay];
            }
        }
    }
}

#endif
```

With these code changes you can replace
```
    gl_FragColor = colorVarying;
```
in `Shader.fsh` with
```
    gl_FragColor = colorVarying * vec4(1.0, 0.0, 0.0, 1.0);
```
and the moment you save the file you see the color of one cube change from white to red.

# Further Reading

Have a look at [Is Your Program Perfect? The de Mare Test](http://inglua.wordpress.com/2008/07/25/is-your-program-perfect-the-de-mare-test/) which should give you plenty of ideas to make your app more developer friendly.

