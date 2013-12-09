//
//  RLOUtils.h
//  Copyright (c) 2013 Michael Krause. All rights reserved.
//

#ifdef RLO_ENABLED

#define RLO_WATCH_CODE_UPDATES do { [RLOBundleUpdater startChecking:RLO_USE_POLLING]; } while(0)
#define RLOaddObserver(observer, theSelector) do { [[NSNotificationCenter defaultCenter] addObserver:observer selector:theSelector name:RLOTIfiNotification object:nil]; } while(0)
#define RLOremoveObserver(observer) do { [[NSNotificationCenter defaultCenter] removeObserver:self name:RLOTIfiNotification object:nil]; } while(0)
#define RLONotificationContainsClassname(aNotification, classnames) [RLOBundleUpdater containsChangedClassname:classnames notification:aNotification]
#define RLONotificationHasKeyPress(aNotification, keycombo) [RLOBundleUpdater hasKeyPress:keycombo notification:aNotification]
#define RLONotificationHasKeyCombo(aNotification, keycombo) [RLOBundleUpdater hasKeyCombo:keycombo notification:aNotification]
#define RLONotificationHasKeyUpCombo(aNotification, keycombo) [RLOBundleUpdater hasKeyUpCombo:keycombo notification:aNotification]
#define RLONotificationKeyStatus(aNotification, keycombo) [RLOBundleUpdater keyStatus:keycombo notification:aNotification]


#define RLO_DOWNLOAD_DATA(name) [RLOUtils downloadFile:(name)]
#define RLO_START_CONF_LOADER [RLOUtils startConfLoader]
#define RLO_INIT_CONFIGURATION(path, url) [RLOUtils initRLOConfiguration:(path) serverURL:(url)]
#define RLO_LOAD_CONFIGURATION(x) [RLOUtils loadRLOConfiguration:(x)]
#define RLO_CHANGED_FILE(notification) [RLOUtils changedFile:(notification)]
#define RLO_LOAD_OBJECT(name) [RLOUtils loadObject:name]
#define RLO_SAVE_OBJECT(obj, objname) [RLOUtils saveObject:obj name:objname]

#define RLOGetInt(varname, default_value) [RLOUtils getIntVariable:varname defaultValue:default_value]
#define RLOSetInt(varname, v) [RLOUtils setIntVariable:varname value:v]
#define RLOGetFloat(varname, default_value) [RLOUtils getFloatVariable:varname defaultValue:default_value]
#define RLOSetFloat(varname, v) [RLOUtils setFloatVariable:varname value:v]
#define RLOGetObject(varname) [RLOUtils getObject:varname]
#define RLOGetObjectWithDefault(varname, default_value) [RLOUtils getObject:varname value:default_value]
#define RLOSetObject(varname, v) [RLOUtils setObjectVariable:varname value:v]
#define RLOGetFilecontent(filename) [RLOUtils getFilecontent:filename]
#define RLODeleteVar(varname) [RLOUtils deleteVariable:varname]
#define RLOVarChanged(varnames) [RLOUtils variableHasChanged:varnames]
#define RLOAddResponseHandler(handler) [RLOUtils addRLOResponseHandler:handler]


#define RLOLogDefinitionForUIImage(img, _xx, _yy, _noaliasZoom) [RLOUtils imageDefinitionForUIImage:img zoomX:_xx zoomY:_yy noaliasZoom:_noaliasZoom]
#define RLOLogDefinitionForCGImage(img, _xx, _yy, _noaliasZoom) [RLOUtils imageDefinitionForCGImage:img zoomX:_xx zoomY:_yy noaliasZoom:_noaliasZoom]
#define RLOLogDefinitionForContext(img, _xx, _yy, _noaliasZoom) [RLOUtils imageDefinitionForContext:img zoomX:_xx zoomY:_yy noaliasZoom:_noaliasZoom]
#define RLOLogUIImage(img, _xx, _yy, _noaliasZoom) do { NSString *s = [RLOUtils imageDefinitionForUIImage:img zoomX:_xx zoomY:_yy noaliasZoom:_noaliasZoom]; NSLog(@"%@", s); } while(0)
#define RLOLogCGImage(img, _xx, _yy, _noaliasZoom) do { NSString *s = [RLOUtils imageDefinitionForCGImage:img zoomX:_xx zoomY:_yy noaliasZoom:_noaliasZoom]; NSLog(@"%@", s); } while(0)
#define RLOLogContext(context, _xx, _yy, _noaliasZoom) do { NSString *s = [RLOUtils imageDefinitionForContext:context zoomX:_xx zoomY:_yy noaliasZoom:_noaliasZoom]; NSLog(@"%@", s); } while(0)

#define RLOZoomFit(s) (MIN(RLOGetInt(@"rlo.consolewidth", 1264) / (float)(s.width), RLOGetInt(@"rlo.consoleheight", 600) / (float)(s.height)))
#define RLOZoomFill(s) (RLOGetInt(@"rlo.consolewidth", 1264) / (float)(s.width))

#define RLOUploadData(data, filename_arg) [RLOUtils uploadData:(data) filename:(filename_arg)];
#define RLOUploadImage(image) [RLOUtils uploadImage:(image)];
#define RLOUploadContext(context) [RLOUtils uploadContext:(context)];
#if TARGET_OS_IPHONE
#define RLO_DOWNLOAD_UIIMAGE(name) [RLOUtils downloadImage:(name)]
#define RLOUploadUIImage(image) [RLOUtils uploadUIImage:(image)];
#else
#define RLOUploadNSImage(image) [RLOUtils uploadNSImage:(image)];
#endif


#else


#endif

#ifdef RLO_ENABLED

#define RLOTIfiNotification @"RLOTIfiNotification"


extern NSMutableDictionary *rlo_vars_dict;

@interface NSDictionary (Difference)

- (NSDictionary *)compareWithDictionary:(NSDictionary *)otherDict prefix:(NSString *)prefix;

@end

@interface RLOUtils : NSObject

+ (int)getIntVariable:(NSString *)varname defaultValue:(int)default_value;
+ (void)setIntVariable:(NSString *)varname value:(int)value;
+ (float)getFloatVariable:(NSString *)varname defaultValue:(float)default_value;
+ (void)setFloatVariable:(NSString *)varname value:(float)value;
+ (id)getObject:(NSString *)varname;
+ (id)getObject:(NSString *)varname value:(id)value;
+ (void)setObjectVariable:(NSString *)varname value:(id)value;
+ (void)registerAddressOfIntVariable:(NSString *)varname address:(int *)adr;

+ (id)getFilecontent:(NSString *)aFilename;
+ (void)deleteVariable:(NSString *)varname;
+ (BOOL)variableHasChanged:(NSString *)keypaths;
+ (void)clearLastDiffDict;

+ (NSString *)changedFile:(NSNotification *)aNotification;

+ (NSData *)downloadFile:(NSString *)filename;
+ (BOOL)uploadData:(NSData *)data filename:(NSString *)filename;
+ (BOOL)takeSimulatorScreenshot:(NSString *)filename;

+ (void)initRLOConfiguration:(NSString *)path serverURL:(NSString *)theServerURL;
+ (int)loadRLOConfiguration:(NSString *)client_id;
+ (void)startConfLoader;

+ (id)loadObject:(NSString *)name;
+ (BOOL)saveObject:(NSObject *)obj name:(NSString *)name;

+ (BOOL)uploadImage:(CGImageRef)image;
+ (BOOL)uploadContext:(CGContextRef)ctx;

#if TARGET_OS_IPHONE
+ (UIImage *)downloadImage:(NSString *)imagename;
+ (BOOL)uploadUIImage:(UIImage *)image;
#endif

#if !TARGET_OS_IPHONE
+ (BOOL)uploadNSImage:(NSImage *)image;
#endif

#ifdef HAVE_XCADDEDMARKUP
+ (NSString *)imageDefinitionForPNGData:(NSData *)data size:(CGSize)size zoomX:(float)zoomX zoomY:(float)zoomY noaliasZoom:(BOOL)noaliasZoom;
+ (NSString *)imageDefinitionForCGImage:(CGImageRef)image zoomX:(float)zoomX zoomY:(float)zoomY noaliasZoom:(BOOL)noaliasZoom;
+ (NSString *)imageDefinitionForContext:(CGContextRef)ctx zoomX:(float)zoomX zoomY:(float)zoomY noaliasZoom:(BOOL)noaliasZoom;
#if TARGET_OS_IPHONE
+ (NSString *)imageDefinitionForUIImage:(UIImage *)image zoomX:(float)zoomX zoomY:(float)zoomY noaliasZoom:(BOOL)noaliasZoom;
#endif
#endif

+ (void)addRLOResponseHandler:(id)handler;

@end

#endif
