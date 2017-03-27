//
//  RLOUtils.m
//  Copyright (c) 2013 Michael Krause. All rights reserved.
//


#ifdef RLO_ENABLED

#import "RLOUtils.h"
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <netdb.h>

#ifndef HAVE_XCADDEDMARKUP
#define RLOLogRED(s, ...) NSLog((s), ##__VA_ARGS__)
#define RLOLogGREEN(s, ...) NSLog((s), ##__VA_ARGS__)
#define RLOLogBLUE(s, ...) NSLog((s), ##__VA_ARGS__)
#else
#define RLOLogRED DebugLogRED
#define RLOLogGREEN DebugLogGREEN
#define RLOLogBLUE DebugLogBLUE
#endif

#define RLOLog NSLog
#define RLOLogf NSLog

#define RLOVAR_HTTP_SERVER @"_rloutils_http_server"
#define RLOVAR_RLOCONF_FILENAME @"_rloutils_rloconf_filename"

#define RLOCONFIG_FILENAME @"rloconfig.plist"
#define CHANGED_FILE_KEY @"changed_file"

#define kShowNonDefaultVars @"rlo.show_nondefault_vars"

#ifndef DebugDecorateM
#define DebugDecorateM(s) (s)
#endif
#define logNonDefaultVar(s, ...) NSLog(DebugDecorateM(s), ##__VA_ARGS__)

#define RLOCONF_LOADER_SUCCEEDED 0
#define RLOCONF_LOADED_INVALID 1
#define RLOCONF_LOADED_ERROR 2

#define RLO_VARTYPE_INTEGER 1
#define RLO_VARTYPE_FLOAT 2

static inline void RLOPrint(NSString *format, ...)
{
    va_list args;
    va_start(args, format);
    NSString *string = [[NSString alloc] initWithFormat:format  arguments:args];
    va_end(args);
    printf("%s\n", [string UTF8String]);
}

@protocol RLOResponseHandler <NSObject>

+ (BOOL)handleRLOServerResponse:(NSHTTPURLResponse *)response data:(NSData *)data succeeded:(BOOL)succeeded;

@end


static NSTimeInterval starttime = 0;
static unsigned int rlo_config_download_request_nr = 0;
static NSMutableDictionary *rlo_reported_failed_downloads;

NSMutableDictionary *rlo_vars_dict;
NSDictionary *rlo_vars_lastdiff_dict;
NSMutableSet *rlo_vars_diffset;
// rlo_vars_symboladdresses is mapping of symbolname => (vartype, varaddress)
NSMutableDictionary *rlo_vars_symboladdresses;

#pragma mark -

#define kDifferenceFirstKey @"a"
#define kDifferenceSecondKey @"b"
#define kDifferenceDeletedKeys @"deleted"

@implementation NSDictionary (Difference)

- (NSDictionary *)compareWithDictionary:(NSDictionary *)otherDict prefix:(NSString *)prefix
{
    NSMutableDictionary *o = [NSMutableDictionary dictionaryWithDictionary:self];
    NSMutableDictionary *n = [NSMutableDictionary dictionaryWithDictionary:otherDict];
    NSSet *allkeys = [[NSSet setWithArray:[o allKeys]] setByAddingObjectsFromArray:[n allKeys]];
    NSString *subprefix;
    if (! prefix || [prefix length] == 0) {
        subprefix = @"";
    } else {
        subprefix = [NSString stringWithFormat:@"%@.", prefix];
    }
    NSMutableArray *deleted_keys = [[NSMutableArray alloc] init];
    for (id k in allkeys) {
        // keys starting with an underscore are internal keys that are ignored for comparison.
        if ([k hasPrefix:@"_"]) {
            [o removeObjectForKey:k];
            [n removeObjectForKey:k];
            continue;
        }
        id a = [o objectForKey:k];
        id b = [n objectForKey:k];
        if (a && b) {
            if ([a isEqual:b]) {
                [o removeObjectForKey:k];
                [n removeObjectForKey:k];
            } else if ([a isKindOfClass:[NSDictionary class]] && [b isKindOfClass:[NSDictionary class]]) {
                NSDictionary *diff = [a compareWithDictionary:b prefix:[subprefix stringByAppendingString:k]];
                id old = [diff objectForKey:kDifferenceFirstKey];
                id new = [diff objectForKey:kDifferenceSecondKey];
                [deleted_keys addObjectsFromArray:[diff objectForKey:kDifferenceDeletedKeys]];
                if ([old isEqual:new]) {
                    [o removeObjectForKey:k];
                    [n removeObjectForKey:k];
                } else {
                    [o setObject:old forKey:k];
                    [n setObject:new forKey:k];
                }
            }
        } else if (a && !b) {
            [deleted_keys addObject:[subprefix stringByAppendingString:k]];
        }
    }
    
    NSDictionary *result = @{kDifferenceFirstKey: o, kDifferenceSecondKey: n, kDifferenceDeletedKeys: deleted_keys};
    return result;
}

@end

#pragma mark -

static NSMutableArray *handlers;

@implementation RLOUtils

+ (void)initialize
{
    if (! handlers) {
        handlers = [[NSMutableArray alloc] init];
    }
    if (! rlo_vars_dict) {
        rlo_vars_dict = [[NSMutableDictionary alloc] init];
    }
    if (! rlo_vars_diffset) {
        rlo_vars_diffset = [[NSMutableSet alloc] init];
    }
    if (! rlo_vars_symboladdresses) {
        rlo_vars_symboladdresses = [[NSMutableDictionary alloc] init];
    }
}

+ (void)registerAddressOfIntVariable:(NSString *)varname address:(int *)adr
{
    [rlo_vars_symboladdresses setObject:@[@RLO_VARTYPE_INTEGER, [NSValue valueWithPointer:adr]]
                                   forKey:varname];
}

+ (void)updateGlobalVariable:(NSString *)varname
{
    NSNumber *v = [rlo_vars_dict objectForKey:varname];
    if (v) {
        NSArray *vartuple = [rlo_vars_symboladdresses objectForKey:varname];
        if (vartuple) {
            if ([[vartuple objectAtIndex:0] intValue] == RLO_VARTYPE_INTEGER) {
                int *adr = [[vartuple objectAtIndex:1] pointerValue];
                *adr = [v intValue];
            }
        }
    }
}

+ (void)updateGlobalVariables
{
    if (! rlo_vars_symboladdresses)
        return;
    
    for (NSString *varname in rlo_vars_symboladdresses) {
        [[self class] updateGlobalVariable:varname];
    }
}

static int showNondefaultVarsKey = -1;
static void refreshShowNondefaultVars(NSString *keyPath)
{
    if (!keyPath || [keyPath isEqualToString:kShowNonDefaultVars]) {
        showNondefaultVarsKey = -1;
    }
}

static int getShowNondefaultVars()
{
    if (showNondefaultVarsKey == -1) {
        showNondefaultVarsKey = [[rlo_vars_dict valueForKeyPath:kShowNonDefaultVars] intValue];
    }
    return showNondefaultVarsKey;
}

static id getDebugValue(NSString *keyPath)
{
    @try {
        return [rlo_vars_dict valueForKeyPath:keyPath];
    }
    @catch (NSException *exception) {
        RLOLogf(@"keyPath '%@' invalid: %@", keyPath, exception);
        return nil;
    }
}

static void setDebugValue(NSString *keyPath, id value)
{
    @try {
        [rlo_vars_dict setValue:value forKeyPath:keyPath];
        refreshShowNondefaultVars(keyPath);
    }
    @catch (NSException *exception) {
        RLOLogf(@"keyPath '%@' invalid: %@", keyPath, exception);
    }
}

+ (void)addEntriesToDebugDict:(NSDictionary *)aDict
{
    [rlo_vars_dict addEntriesFromDictionary:aDict];
    refreshShowNondefaultVars(nil);
}

+ (void)deleteKeysFromDebugDict:(NSArray *)keys
{
    if (keys) {
        for (NSString *key in keys) {
            [rlo_vars_dict setValue:nil forKeyPath:key];
        }
    }
    refreshShowNondefaultVars(nil);
}

static BOOL shouldShowNondefaultVariable(NSString *varname)
{
    int show_nondefault_vars = getShowNondefaultVars();
    if (show_nondefault_vars == 0) {
        return NO;
    }
    
    if (show_nondefault_vars == 1) {
        if ([rlo_vars_diffset member:varname]) {
            return NO;
        } else {
            [rlo_vars_diffset addObject:varname];
        }
    }
    
    return YES;
}

+ (int)getIntVariable:(NSString *)varname defaultValue:(int)default_value
{
    if (! rlo_vars_dict)
        return default_value;
    NSNumber *v = getDebugValue(varname);
    if (v) {
        int i = [v intValue];
        if (shouldShowNondefaultVariable(varname)) {
            if (i != default_value) {
                logNonDefaultVar(@"NDVi: %@ (default %d) is currently %d", varname, default_value, i);
            }
        }
        return i;
    }
    return default_value;
}

+ (void)setIntVariable:(NSString *)varname value:(int)value
{
    if (! rlo_vars_dict)
        return;
    setDebugValue(varname, @(value));
    [[self class] updateGlobalVariable:varname];
}

+ (float)getFloatVariable:(NSString *)varname defaultValue:(float)default_value
{
    if (! rlo_vars_dict)
        return default_value;
    NSNumber *v = getDebugValue(varname);
    if (v) {
        float f = [v floatValue];
        if (shouldShowNondefaultVariable(varname)) {
            if (f != default_value) {
                logNonDefaultVar(@"NDVf: %@ (default %f) is currently %f", varname, default_value, f);
            }
        }
        return f;
    }
    
    return default_value;
}

+ (void)setFloatVariable:(NSString *)varname value:(float)value
{
    if (! rlo_vars_dict)
        return;
    setDebugValue(varname, @(value));
    [[self class] updateGlobalVariable:varname];
}

+ (id)getObject:(NSString *)varname
{
    if (! rlo_vars_dict)
        return nil;
    id v = getDebugValue(varname);
    if (! v) {
        return nil;
    }
    id result = nil;
    if ([v isKindOfClass:[NSString class]]) {
        result = [self substituteKeypaths:v];
    } else if ([v isKindOfClass:[NSObject class]]) {
        result = v;
    }
    if (result && shouldShowNondefaultVariable(varname)) {
        logNonDefaultVar(@"NDVo: %@ (default nil) is currently '%@'", varname, result);
    }
    return result;
}

+ (id)getObject:(NSString *)varname value:(id)value
{
    if (! rlo_vars_dict)
        return nil;
    id v = getDebugValue(varname);
    if (! v) {
        v = value;
        if (shouldShowNondefaultVariable(varname)) {
            logNonDefaultVar(@"NDVo: %@ (default %@) is currently nil", varname, value);
        }
    }
    id result = nil;
    if ([v isKindOfClass:[NSString class]]) {
        result = [self substituteKeypaths:v];
    } else if ([v isKindOfClass:[NSObject class]]) {
        result = v;
    }
    
    if (shouldShowNondefaultVariable(varname)) {
        if (! [result isEqual:value]) {
            logNonDefaultVar(@"NDVo: %@ (default %@) is currently '%@'", varname, value, result);
        }
    }
    
    return result;
}

+ (void)setObjectVariable:(NSString *)varname value:(id)value
{
    if (! rlo_vars_dict)
        return;
    setDebugValue(varname, value);
    [[self class] updateGlobalVariable:varname];
}

+ (id)getFilecontent:(NSString *)aFilename
{
    if (! rlo_vars_dict)
        return nil;
    
    NSString *filename = [aFilename stringByRemovingPercentEncoding];
    NSString *keyname = [NSString stringWithFormat:@"file_%@", filename];
    NSData *v = getDebugValue(keyname);
    if (! v) {
        return nil;
    }
    return v;
}

+ (void)setFilecontent:(NSString *)aFilename value:(id)value
{
    if (! rlo_vars_dict)
        return;
    
    NSString *filename = [aFilename stringByRemovingPercentEncoding];
    NSString *keyname = [NSString stringWithFormat:@"file_%@", filename];
    [rlo_vars_dict setObject:value forKey:keyname];
}

+ (void)deleteVariable:(NSString *)varname
{
    if (! rlo_vars_dict)
        return;
    setDebugValue(varname, nil);
}

+ (NSString *)substituteKeypaths:(NSString *)inputtext
{
    NSError *error = NULL;
    static NSRegularExpression *regex = nil;
    if (! regex) {
        regex = [NSRegularExpression regularExpressionWithPattern:@"\\{\\{([^{}]*)\\}\\}"
                                                          options:0
                                                            error:&error];
    }
    NSArray *matches = [regex matchesInString:inputtext options:0 range:NSMakeRange(0, [inputtext length])];
    NSMutableArray *fragments = [NSMutableArray array];
    NSUInteger cursor = 0;
    for (NSTextCheckingResult *match in matches) {
        NSRange matchRange = [match range];
        [fragments addObject:[inputtext substringWithRange:NSMakeRange(cursor, matchRange.location - cursor)]];
        NSRange symbolrange = [match rangeAtIndex:1];
        NSString *symbol = [inputtext substringWithRange:symbolrange];
        id obj = [self getObject:symbol];
        if (obj) {
            [fragments addObject:[NSString stringWithFormat:@"%@", obj]];
        } else {
            [fragments addObject:[inputtext substringWithRange:matchRange]];
        }
        cursor = matchRange.location + matchRange.length;
    }
    [fragments addObject:[inputtext substringFromIndex:cursor]];
    NSString *result = [fragments componentsJoinedByString:@""];
    return result;
}

+ (NSString *)projectname
{
    NSString *project_name = @"unknownproject";
    NSString *rloconf_filename = RLOGetObject(RLOVAR_RLOCONF_FILENAME);
    if (! rloconf_filename) {
        return project_name;
    }
    NSArray *components = [rloconf_filename pathComponents];
    if ([components count] == 0) {
        return nil;
    }
    NSUInteger identposition = [components count] - 1;
    if (identposition > 0 && [[components objectAtIndex:identposition] hasSuffix:@".py"]) {
        identposition -= 1;
    }
    if (identposition > 0 && [[components objectAtIndex:identposition] isEqualToString:@"scripts"]) {
        identposition -= 1;
    }
    project_name = [components objectAtIndex:identposition];
    return project_name;
}

+ (NSString *)requestURLForDownload:(NSString *)filename
{
    NSString *http_server = RLOGetObject(RLOVAR_HTTP_SERVER);
    if (! http_server) {
        return nil;
    }
    NSString *rloconf_filename = RLOGetObject(RLOVAR_RLOCONF_FILENAME);
    if (! rloconf_filename) {
        return nil;
    }
    
    filename = [filename lastPathComponent];
    filename = [filename stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    return [NSString stringWithFormat:@"%@/download?&rloconf=%@&filename=%@", http_server, rloconf_filename, filename];
}

+ (NSString *)urlWithReplacedHostname:(NSURL *)url hostname:(NSString *)hostname
{
    NSMutableString *s = [NSMutableString string];
    [s appendFormat:@"%@://%@",[url scheme], hostname];
    if ([url port]!=nil){
        [s appendFormat:@":%@",[url port]];
    }
    [s appendFormat:@"%@",[url path]];
    if ([url parameterString]!=nil){
        [s appendFormat:@";%@",[url parameterString]];
    }
    if ([url query]!=nil){
        [s appendFormat:@"?%@",[url query]];
    }
    if ([url fragment]!=nil){
        [s appendFormat:@"#%@",[url fragment]];
    }
    return [NSString stringWithString:s];
}

+ (BOOL)downloadFile:(NSString *)filename data:(NSData **)data response:(NSHTTPURLResponse **)response
{
    BOOL success;
    if (RLOGetInt(@"rlo.hostname_resolution", 0)) {
        NSString *serverurl = RLOGetObject(RLOVAR_HTTP_SERVER);
        NSURL *url = [NSURL URLWithString:serverurl];
        NSString *hostname = [url host];
        
        if (! [self isNumericIPV4Address:hostname]) {
            NSString *request_string = [self requestURLForDownload:filename];
            if (! request_string) {
                return NO;
            }
            
            NSArray *ip_addresses = [self ipAddressesFromString:hostname];
            if (ip_addresses) {
                NSURL *requesturl = [NSURL URLWithString:serverurl];
                for (NSString *ip in ip_addresses) {
                    NSString *testurl = [self urlWithReplacedHostname:requesturl hostname:ip];
                    success = [self downloadFileFromURL:testurl filename:filename data:data response:response];
                    if (success) {
                        NSString *newserverurl = [self urlWithReplacedHostname:url hostname:ip];
                        RLOSetObject(RLOVAR_HTTP_SERVER, newserverurl);
                        return success;
                    }
                }
            }
        }
    }
    
    return [self downloadFileDirect:(NSString *)filename data:(NSData **)data response:(NSHTTPURLResponse **)response];
}

// From: https://forums.developer.apple.com/thread/11519
+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request
                 returningResponse:(__autoreleasing NSURLResponse **)responsePtr
                             error:(__autoreleasing NSError **)errorPtr
{
    dispatch_semaphore_t sem;
    __block NSData *result;
    result = nil;
    sem = dispatch_semaphore_create(0);
    [[[NSURLSession sharedSession] dataTaskWithRequest:request
                                     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                         if (errorPtr != NULL) {
                                             *errorPtr = error;
                                         }
                                         if (responsePtr != NULL) {
                                             *responsePtr = response;
                                         }
                                         if (error == nil) {
                                             result = data;
                                         }
                                         dispatch_semaphore_signal(sem);
                                     }] resume];
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);

    return result;
}

+ (BOOL)downloadFileFromURL:(NSString *)theUrl filename:(NSString *)filename data:(NSData **)data response:(NSHTTPURLResponse **)response
{
    NSError *error = nil;
    NSURL *url = [NSURL URLWithString:theUrl];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod: @"GET"];
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    NSData *responsedata = [self sendSynchronousRequest:request returningResponse:response error:&error];
    NSArray *components = [filename componentsSeparatedByString:@"&"];
    NSString *name = components.count > 0 ? components[0] : nil;
    
    if (! rlo_reported_failed_downloads) {
        rlo_reported_failed_downloads = [[NSMutableDictionary alloc] init];
    }
    if (error) {
        *data = nil;
        if (name) {
            if (rlo_reported_failed_downloads[name]) {
                return NO;
            }
            rlo_reported_failed_downloads[name] = @(YES);
        }
        RLOLogRED(@"Error downloading file %@ from %@: %@", filename, theUrl, [error localizedDescription]);
        return NO;
    }
    if ((([*response statusCode] / 100) == 2) && [responsedata length] > 0) {
        *data = responsedata;
        if (name) {
            // After a successful download if the next download of this file fails it will be logged.
            [rlo_reported_failed_downloads removeObjectForKey:name];
        }
        return YES;
    }
    *data = nil;
    if (name) {
        if (rlo_reported_failed_downloads[name]) {
            return NO;
        }
        rlo_reported_failed_downloads[name] = @(YES);
    }
    RLOLogRED(@"Error: Server response for downloading file '%@' from '%@': (%ld) %@", filename, theUrl, (long)[*response statusCode], [[NSString alloc] initWithData:responsedata encoding:NSUTF8StringEncoding]);
    return NO;
}

+ (BOOL)downloadFileDirect:(NSString *)filename data:(NSData **)data response:(NSHTTPURLResponse **)response
{
    NSString *request_string = [self requestURLForDownload:filename];
    if (! request_string) {
        return NO;
    }
    
    return [self downloadFileFromURL:request_string filename:filename data:data response:response];
}

+ (BOOL)downloadFile:(NSString *)filename data:(NSData **)data
{
    NSHTTPURLResponse *response;
    return [self downloadFile:filename data:data response:&response];
}

+ (NSData *)downloadFile:(NSString *)filename
{
    NSData *data = nil;
    BOOL succeeded = [[self class] downloadFile:filename data:&data];
    if (succeeded && data) {
        return data;
    }
    
    return nil;
}

+ (BOOL)doHTTPRequest:(NSString *)action data:(NSData *)data filename:(NSString *)filename
{
    NSHTTPURLResponse *response;
    NSError *error = nil;
    NSString *http_server = RLOGetObject(RLOVAR_HTTP_SERVER);
    if (! http_server) {
        RLOLogRED(@"Warning: RLOVAR_HTTP_SERVER is not set");
        return NO;
    }
    NSString *rloconf_filename = RLOGetObject(RLOVAR_RLOCONF_FILENAME);
    if (! rloconf_filename) {
        return NO;
    }
    
    filename = [filename lastPathComponent];
    filename = [filename stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    rloconf_filename = [rloconf_filename stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    if (! filename) {
        filename = @"";
    }
    NSString *request_string = [NSString stringWithFormat:@"%@/%@?rloconf=%@&filename=%@", http_server, action, rloconf_filename, filename];
    NSURL *url = [NSURL URLWithString:request_string];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    if (data) {
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:data];
    }
    NSData *responsedata = [self sendSynchronousRequest:request returningResponse:&response error:&error];
    if ([responsedata length] > 0) {
        NSLog(@"responsedata: %@", responsedata);
        return NO;
    }
    if (error) {
        NSLog(@"Error sending file %@: %@", filename, error);
        NSLog(@"URL: %@", url);
        return NO;
    }
    return YES;
}

+ (BOOL)takeSimulatorScreenshot:(NSString *)filename
{
    return [self doHTTPRequest:@"takescreenshot" data:nil filename:filename];
}

+ (BOOL)uploadData:(NSData *)data filename:(NSString *)filename
{
    NSHTTPURLResponse *response;
    NSError *error = nil;
    if (! filename) {
        RLOLog(@"Error in uploadData, filename is nil");
        return NO;
    }
    NSString *http_server = RLOGetObject(RLOVAR_HTTP_SERVER);
    if (! http_server) {
        RLOLogRED(@"Warning: Trying to upload '%@' (%lu bytes) but RLOVAR_HTTP_SERVER is not set", filename, (unsigned long)data.length);
        return NO;
    }
    NSString *rloconf_filename = RLOGetObject(RLOVAR_RLOCONF_FILENAME);
    if (! rloconf_filename) {
        return NO;
    }
    
    filename = [filename lastPathComponent];
    filename = [filename stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    rloconf_filename = [rloconf_filename stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *request_string = [NSString stringWithFormat:@"%@/upload?rloconf=%@&filename=%@", http_server, rloconf_filename, filename];
    NSURL *url = [NSURL URLWithString:request_string];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:data];
    NSData *responsedata = [self sendSynchronousRequest:request returningResponse:&response error:&error];
    if ([responsedata length] > 0) {
        NSLog(@"responsedata: %@", responsedata);
        return NO;
    }
    if (error) {
        NSLog(@"Error sending file %@: %@", filename, error);
        NSLog(@"URL: %@", url);
        return NO;
    }
    return YES;
}

#if TARGET_OS_IPHONE

+ (UIImage *)downloadImage:(NSString *)imagename
{
    NSData *data = nil;
    BOOL succeeded = [[self class] downloadFile:imagename data:&data];
    if (succeeded && data) {
        return [UIImage imageWithData:data];
    }
    
    return nil;
}

#endif

+ (NSString *)changedFile:(NSNotification *)aNotification
{
    if (aNotification) {
        NSDictionary *userInfo = [aNotification userInfo];
        if (userInfo) {
            return [userInfo objectForKey:CHANGED_FILE_KEY];
        }
    }
    return nil;
}

+ (BOOL)isNumericIPV4Address:(NSString *)address
{
    return [[address stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789."]] length] == 0;
}

+ (NSArray *)ipAddressesFromString:(NSString*)string
{
    NSMutableSet *addresses = [[NSMutableSet alloc] init];
    
    struct addrinfo *result;
    struct addrinfo *res;
    int error;
    
    error = getaddrinfo([string UTF8String], NULL, NULL, &result);
    if (error != 0) {
        return NULL;
    }
    
    for (res = result; res != NULL; res = res->ai_next)    {
        char hostname[NI_MAXHOST] = "";
        if (getnameinfo(res->ai_addr, res->ai_addrlen, hostname, NI_MAXHOST, NULL, 0, NI_NUMERICHOST) == 0) {
            NSString *name = [NSString stringWithUTF8String:hostname];
            if ([[name stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"0123456789."]] length] == 0) {
                [addresses addObject:name];
            }
        }
    }
    
    freeaddrinfo(result);
    
    NSMutableArray *returnArray = [NSMutableArray arrayWithCapacity:[addresses count]];
    for (id obj in addresses) {
        [returnArray addObject:obj];
    }
    
    NSArray *sorted_addresses = [returnArray sortedArrayUsingComparator:^(id obj1, id obj2) {
        return [(NSString *)obj1 compare:(NSString *)obj2 options:NSNumericSearch];
    }];
    
    return sorted_addresses;
}

+ (void)initRLOConfiguration:(NSString *)path serverURL:(NSString *)theServerURL
{
    RLOSetObject(RLOVAR_RLOCONF_FILENAME, [path stringByStandardizingPath]);
    RLOSetObject(RLOVAR_HTTP_SERVER, theServerURL);
}

+ (NSString *)defaultClientID
{
    if (starttime == 0) {
        starttime = [[NSDate date] timeIntervalSince1970];
    }
    return [NSString stringWithFormat:@"%f", starttime];
}

+ (int)loadRLOConfiguration:(NSString *)client_id blocking:(BOOL)blocking
{
    NSData *data = nil;
    NSString *blocking_param = blocking ? @"&blocking=1" : @"";
    BOOL succeeded = NO;
    
    if (! client_id) {
        client_id = [[self class] defaultClientID];
    }
    
    if ([client_id hasSuffix:@".plist"])  {
        // Load rloconfig from resource directory
        NSString *rloconfigpath = [[NSBundle mainBundle] pathForResource:client_id ofType:nil];
        if (rloconfigpath) {
            data = [NSData dataWithContentsOfFile:rloconfigpath];
            succeeded = data != nil;
        }
    } else {
        NSHTTPURLResponse *response;
        succeeded = [[self class] downloadFile:[NSString stringWithFormat:@"%@&starttime=%@%@", RLOCONFIG_FILENAME, client_id, blocking_param] data:&data response:&response];
        if (! succeeded && rlo_config_download_request_nr == 0) {
            RLOLog(@"The rlo_server.py is not running so you cannot see parameters changes in rloconfig.py in the app.");
            RLOLog(@"But if you are content with only doing code updates without restart that is perfectly fine for OS X and the simulator without a running RLO server.");
            RLOLog(@"Code updates during runtime on an iOS device on the other hand require a running RLO server.");
        }
        rlo_config_download_request_nr++;
        
        NSDictionary *all_headers = [response allHeaderFields];
        NSString *filename = [all_headers objectForKey:@"Filename"];
        
        // Check if this content is handled a registered handler
        for (id<RLOResponseHandler> handler in handlers) {
            if ([handler isKindOfClass:[NSObject class]] && [handler respondsToSelector:@selector(handleRLOServerResponse:data:succeeded:)]) {
                BOOL handled = [handler handleRLOServerResponse:response data:data succeeded:succeeded];
                if (handled) {
                    return RLOCONF_LOADER_SUCCEEDED;
                }
            }
        }
        
        if (filename && ![filename isEqualToString:RLOCONFIG_FILENAME]) {
            [self setFilecontent:filename value:data];
            RLOLogGREEN(@"File '%@' was replaced", filename);
            [[self class] performSelectorOnMainThread:@selector(notifyRLOConfigurationChange:) withObject:@{CHANGED_FILE_KEY:filename} waitUntilDone:NO];
            return RLOCONF_LOADER_SUCCEEDED;
        }
    }
    
    if (succeeded && data) {
        NSError *error = nil;
        NSPropertyListFormat format;
        id plist = [NSPropertyListSerialization propertyListWithData:data
                                                             options:NSPropertyListMutableContainersAndLeaves
                                                              format:&format
                                                               error:&error];
        if (error || ! [plist isKindOfClass:[NSDictionary class]]) {
            return RLOCONF_LOADED_INVALID;
        }
        NSDictionary *dict_a = [rlo_vars_dict copy];
        [self addEntriesToDebugDict:plist];
        NSDictionary *diff = [dict_a compareWithDictionary:plist prefix:@""];
        [self deleteKeysFromDebugDict:[diff objectForKey:kDifferenceDeletedKeys]];
        if (! [[diff objectForKey:kDifferenceFirstKey] isEqualToDictionary:[diff objectForKey:kDifferenceSecondKey]]) {
            if (RLOGetInt(@"rlo.show_config_diffs", 0)) {
                NSArray *parameters = [self generateRLOURL:diff keypath:@""];
                if ([parameters count] < RLOGetInt(@"rlo.show_config_diffs_if_num_diffs_less_than", 0)) {
                    RLOLogBLUE(@"%@", [diff objectForKey:kDifferenceFirstKey]);
                    RLOLogGREEN(@"%@", [diff objectForKey:kDifferenceSecondKey]);
                }
            }
            [self generateRLOURL:[diff objectForKey:kDifferenceSecondKey]];
        }
        rlo_vars_lastdiff_dict = diff;
        [[self class] updateGlobalVariables];
        [[self class] performSelectorOnMainThread:@selector(notifyRLOConfigurationChange:) withObject:nil waitUntilDone:NO];
        // almost immediately continue with the next blocking request
        return RLOCONF_LOADER_SUCCEEDED;
    } else {
        return RLOCONF_LOADED_ERROR;
    }
}

+ (BOOL)variableHasChanged:(NSString *)keypaths
{
    NSArray *array = [keypaths componentsSeparatedByString:@" "];
    for (NSString *path in array) {
        if ([rlo_vars_lastdiff_dict valueForKeyPath:[NSString stringWithFormat:@"%@.%@", kDifferenceFirstKey, path]]) {
            return YES;
        }
        if ([rlo_vars_lastdiff_dict valueForKeyPath:[NSString stringWithFormat:@"%@.%@", kDifferenceSecondKey, path]]) {
            return YES;
        }
        NSArray *deleted_keys = [rlo_vars_lastdiff_dict objectForKey:kDifferenceDeletedKeys];
        for (NSString *delkey in deleted_keys) {
            if ([path isEqualToString:delkey]) {
                return YES;
            }
            // If the dictionary 'subdict' is deleted for example, the path 'subdict.subvariable' is considered changed.
            if ([path hasPrefix:[delkey stringByAppendingString:@"."]]) {
                return YES;
            }
        }
    }
    return NO;
}

+ (void)clearLastDiffDict
{
    rlo_vars_lastdiff_dict = @{};
}

+ (void)notifyRLOConfigurationChange:(NSDictionary *)aUserInfo
{
    [[NSNotificationCenter defaultCenter] postNotificationName:RLOTIfiNotification object:[self class] userInfo:aUserInfo];
    [self clearLastDiffDict];
}

+ (NSArray *)generateRLOURL:(NSDictionary *)dictdiff keypath:(NSString *)keypath
{
    NSMutableArray *params = [NSMutableArray array];
    for(id key in dictdiff) {
        id value = [dictdiff objectForKey:key];
        if ([value isKindOfClass:[NSDictionary class]]) {
            [params addObjectsFromArray:[self generateRLOURL:value keypath:[keypath stringByAppendingFormat:@"%@.", key]]];
        } else if ([value isKindOfClass:[NSArray class]]) {
            // TODO: We cannot generate URLs from array values at the moment
        } else {
            NSString *parameter = [NSString stringWithFormat:@"%@%@=%@", [keypath stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
                                   [key stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]],
                                   [[value description] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
            [params addObject:parameter];
        }
    }
    return [NSArray arrayWithArray:params];
}

+ (void)generateRLOURL:(NSDictionary *)dictdiff
{
    int generate_urls = RLOGetInt(@"rlo.generate_urls", 0);
    if (generate_urls) {
        NSArray *parameters = [self generateRLOURL:dictdiff keypath:@""];
        NSString *protocol = nil;
        switch (generate_urls) {
            case 1: protocol = @"rlo"; break;
            case 2: protocol = @"vemmi"; break;
            default: protocol = @"http"; break;
                break;
        }
        if ([parameters count] < RLOGetInt(@"rlo.generate_urls_if_num_diffs_less_than", 0)) {
            NSString *projectname = [self projectname];
            NSString *paramlist = [parameters componentsJoinedByString:@"&"];
            NSString *pathargs = [NSString stringWithFormat:@"%@/update?%@", projectname, paramlist];
            NSString *url = [NSString stringWithFormat:@"%@://%@", protocol, pathargs];
            printf("=======================================================================\n");
            NSString *serverurl;
            NSArray *host_port, *comps;
            switch (generate_urls) {
#ifdef HAVE_XCADDEDMARKUP
                case 1: RLOPrint(@"%@", DebugLink(url)); break;
#else
                case 1: RLOPrint(@"URL: %@", url); break;
#endif
                case 2: RLOPrint(@"%@", url); break;
                default:
                    serverurl = RLOGetObject(RLOVAR_HTTP_SERVER);
                    if (generate_urls == 4) {
                        // Replace hostname.local with localhost
                        comps = [serverurl pathComponents];
                        host_port = [comps[1] componentsSeparatedByString:@":"];
                        if (host_port.count > 1) {
                            serverurl = [NSString stringWithFormat:@"%@//localhost:%@", comps[0], host_port[host_port.count - 1]];
                        } else {
                            serverurl = [NSString stringWithFormat:@"%@//localhost", comps[0]];
                        }
                    }
                    RLOPrint(@"%@/%@", serverurl, [NSString stringWithFormat:@"update/%@?%@", projectname, paramlist]);
                    break;
            }
            printf("=======================================================================\n");
        }
    }
}

+ (void)addRLOResponseHandler:(id)handler
{
    if ([handler respondsToSelector:@selector(handleRLOServerResponse:data:succeeded:)]) {
        [handlers addObject:handler];
    } else {
        RLOLog(@"Error: handler '%@' does not implement handleRLOServerResponse:data:succeeded:", handler);
    }
}

+ (int)loadRLOConfiguration:(NSString *)client_id
{
    return [[self class] loadRLOConfiguration:client_id blocking:NO];
}

+ (void)confLoader:(id)arg
{
    BOOL ready = NO;
    while (1) {
        @autoreleasepool {
            if (! ready ) {
                RLOLogf(@"RLOConfigLoader started");
                ready = YES;
            }
            int status = [[self class] loadRLOConfiguration:nil blocking:YES];
            if (status == RLOCONF_LOADED_INVALID) {
                continue;
            } else if (status == RLOCONF_LOADER_SUCCEEDED) {
                [NSThread sleepForTimeInterval:0];
            } else if (status == RLOCONF_LOADED_ERROR) {
                [NSThread sleepForTimeInterval:1];
            }
            
        }
    }
}

+ (void)startConfLoader
{
    // Although we a request blocking the request returns immediately because a client with this
    // starttime has not requested the configuration before.
    // blocking:YES is necessary so that the next request on the background thread is blocked
    // (until a config change happens) and we only get a single RLO change notification instead of two.
    [[self class] loadRLOConfiguration:[[self class] defaultClientID] blocking:YES];
    [[self class] performSelectorInBackground:@selector(confLoader:) withObject:nil];
}

+ (NSString *)docpathForFile:(NSString *)filename
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docdir = [paths objectAtIndex:0];
    return [docdir stringByAppendingPathComponent:filename];
}

+ (id)loadObject:(NSString *)name
{
    NSString *objfile = [self docpathForFile:[name stringByAppendingPathExtension:@"plist"]];
    id obj = [NSKeyedUnarchiver unarchiveObjectWithFile:objfile];
    if (obj) {
        RLOLog(@"Object of class '%@' successfully read from '%@'", [obj class], objfile);
    } else {
        RLOLog(@"Error: Loading object from '%@' failed", objfile);
    }
    return obj;
}

+ (BOOL)saveObject:(NSObject *)obj name:(NSString *)name
{
    NSString *objfile = [self docpathForFile:[name stringByAppendingPathExtension:@"plist"]];
    BOOL success = [NSKeyedArchiver archiveRootObject:obj toFile:objfile];
    if (success) {
        RLOLog(@"Object of class '%@' successfully written to '%@'", [obj class], objfile);
    } else {
        RLOLog(@"Error: Saving object of class '%@' to '%@' failed",  [obj class], objfile);
    }
    return success;
}

#if TARGET_OS_IPHONE

+ (BOOL)uploadUIImage:(UIImage *)image
{
    NSString *filename = [NSString stringWithFormat:@"screenshot_%dx%d_%.3f.png", (int)image.size.width, (int)image.size.height, [self milliseconds]];
    NSData *request_data = UIImagePNGRepresentation(image);
    return [[self class] uploadData:request_data filename:filename];
}

#endif

#if !TARGET_OS_IPHONE

+ (BOOL)uploadNSImage:(NSImage *)image
{
    NSString *filename = [NSString stringWithFormat:@"screenshot_%dx%d.png", (int)image.size.width, (int)image.size.height];
    [image lockFocus];
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, image.size.width, image.size.height)];
    [image unlockFocus];
    return [[self class] uploadData:[bitmapRep representationUsingType:NSPNGFileType properties:@{}] filename:filename];
}

#endif

+ (BOOL)uploadImage:(CGImageRef)image
{
#if TARGET_OS_IPHONE
    return [[self class] uploadUIImage:[[UIImage alloc] initWithCGImage:image]];
#else
    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithCGImage:image];
    NSImage *result = [[NSImage alloc] init];
    [result addRepresentation:imageRep];
    return [[self class] uploadNSImage:result];
#endif
}

+ (NSData *)pngFromCGImage:(CGImageRef)image
{
#if TARGET_OS_IPHONE
    UIImage *img = [[UIImage alloc] initWithCGImage:image];
    return UIImagePNGRepresentation(img);
#else
    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithCGImage:image];
    NSImage *result = [[NSImage alloc] init];
    [result addRepresentation:imageRep];
    [result lockFocus];
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0, 0, result.size.width, result.size.height)];
    [result unlockFocus];
    return [bitmapRep representationUsingType:NSPNGFileType properties:@{}];
#endif
}

#if TARGET_OS_IPHONE

+ (UIImage *)resizeImage:(UIImage *)image width:(CGFloat)resizedWidth height:(CGFloat)resizedHeight
{
    CGImageRef imageRef = [image CGImage];
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmap = CGBitmapContextCreate(NULL, resizedWidth, resizedHeight, 8, 4 * resizedWidth, colorSpace, kCGImageAlphaPremultipliedFirst & kCGBitmapAlphaInfoMask);
    CGContextSetInterpolationQuality(bitmap, kCGInterpolationNone);
    CGContextDrawImage(bitmap, CGRectMake(0, 0, resizedWidth, resizedHeight), imageRef);
    CGImageRef ref = CGBitmapContextCreateImage(bitmap);
    UIImage *result = [UIImage imageWithCGImage:ref];
    
    CGContextRelease(bitmap);
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(ref);
    
    return result;
}

+ (NSData *)resizePNGData:(NSData *)data zoomX:(float)zoomX zoomY:(float)zoomY
{
    UIImage *img = [UIImage imageWithData:data];
    UIImage *result = [self resizeImage:img width:ceilf(img.size.width * zoomX) height:ceilf(img.size.height * zoomY)];
    return [self pngFromCGImage:result.CGImage];
}

#endif

+ (BOOL)uploadContext:(CGContextRef)ctx
{
    CGImageRef img = CGBitmapContextCreateImage(ctx);
    BOOL ret = [[self class] uploadImage:img];
    CGImageRelease(img);
    return ret;
}

#ifdef HAVE_XCADDEDMARKUP

+ (NSString *)imageDefinitionForPNGData:(NSData *)data size:(CGSize)size zoomX:(float)zoomX zoomY:(float)zoomY noaliasZoom:(BOOL)noaliasZoom
{
    if (! data) {
        return nil;
    }
    NSString *imageurl = @"";
    NSString *cachefilename = [NSString stringWithFormat:@"_cachedfile10_%dx%d_%.3f.png", (int)size.width, (int)size.height, [self milliseconds]];
    if (RLOGetInt(@"rlo.serverfilecache", 0)) {
        [self uploadData:data filename:cachefilename];
        NSString *request_string = [self requestURLForDownload:cachefilename];
        if (request_string) {
            imageurl = request_string;
        }
    } else {
        cachefilename = [NSTemporaryDirectory() stringByAppendingPathComponent:cachefilename];
        NSURL *fileurl = [NSURL fileURLWithPath:cachefilename];
        [data writeToURL:fileurl atomically:YES];
        imageurl = fileurl.absoluteString;
    }
    
    NSString *image_def = [NSString stringWithFormat:@"%@!!(%f,%f,%d)@ref=\"%@\"%@", EMBEDDED_IMAGE_START, zoomX, zoomY, !noaliasZoom, imageurl, EMBEDDED_IMAGE_END];
    return DebugLinkWithTitle(imageurl, image_def);
}

+ (NSString *)imageDefinitionForCGImage:(CGImageRef)image zoomX:(float)zoomX zoomY:(float)zoomY noaliasZoom:(BOOL)noaliasZoom
{
    NSData *data = [self pngFromCGImage:image];
    return [self imageDefinitionForPNGData:data size:CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image)) zoomX:zoomX zoomY:zoomY noaliasZoom:(BOOL)noaliasZoom];
}

+ (NSString *)imageDefinitionForContext:(CGContextRef)ctx zoomX:(float)zoomX zoomY:(float)zoomY noaliasZoom:(BOOL)noaliasZoom
{
    CGImageRef img = CGBitmapContextCreateImage(ctx);
    NSString *result = [self imageDefinitionForCGImage:img zoomX:zoomX zoomY:zoomY noaliasZoom:(BOOL)noaliasZoom];
    CGImageRelease(img);
    return result;
}

#if TARGET_OS_IPHONE

+ (NSString *)imageDefinitionForUIImage:(UIImage *)image zoomX:(float)zoomX zoomY:(float)zoomY noaliasZoom:(BOOL)noaliasZoom
{
    NSData *data = UIImagePNGRepresentation(image);
    return [self imageDefinitionForPNGData:data size:image.size zoomX:zoomX zoomY:zoomY noaliasZoom:(BOOL)noaliasZoom];
}

#endif

#endif


// Embedding images by representing the image data as base64 encoded strings
// slows down the in the Xcode console a lot. This might only be useful for very small images.
//
//+ (NSString *)imageDefinitionAsBase64:(NSData *)data zoomX:(float)zoomX zoomY:(float)zoomY
//{
//    NSString *base64_data = base64encode(data, 0);
//    return [NSString stringWithFormat:@"%@(%f,%f)%@%@", EMBEDDED_IMAGE_START, zoomX, zoomY, base64_data, EMBEDDED_IMAGE_END];
//}

+ (double)milliseconds
{
    struct timeval time;
    gettimeofday(&time, NULL);
    double millis = time.tv_sec + (time.tv_usec / 1000000.0);
    return millis;
}

@end

#endif
