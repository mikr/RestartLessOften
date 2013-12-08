#ifdef RLO_ENABLED

//
//  RLOUnbundler.m
//  RLOUnbundler
//
//  Created by michael on 5/31/12.
//  Copyright (c) 2010-2013 Michael Krause ( http://krause-software.com/ ). All rights reserved.
//

#import "RLOUnbundler.h"

@implementation RLOUnbundler

+ (NSString *)cleanFilename:(NSString *)filename
{
    return [[filename componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/:"]] componentsJoinedByString:@""];
}

+ (BOOL)storeDirectory:(NSDictionary *)d root:(NSString *)root
{
    BOOL success;
    
    NSString *name = [d objectForKey:@"_name"];
    NSString *cname = [self cleanFilename:name];
    if (![name isEqualToString:cname] || [name isEqualToString:@"."] || [name isEqualToString:@".."]) {
        NSLog(@"Illegal file name: %@", name);
        return NO;
    }

    NSString *type = [d objectForKey:@"type"];
    NSString *path = [root stringByAppendingPathComponent:name];
    NSValue *permissions = [d objectForKey:@"permissions"];
    NSDictionary *attributes = @{NSFilePosixPermissions: permissions};

    if ([type isEqualToString:@"directory"]) {
        //NSLog(@"Creating dir : %@", path);
        NSError *error = nil;
        BOOL is_dir;
        if (! [[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&is_dir]) {
            success = [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:attributes error:&error];
            if (! success) {
                NSLog(@"Error creating dir: %@ %@", path, error);
                return NO;
            }
        }
        
        NSArray *items = [d objectForKey:@"items"];
        for (NSDictionary *item in items) {
            NSString *subdir = [root stringByAppendingPathComponent:name];
            success = [self storeDirectory:item root:subdir];
            if (! success) {
                return NO;
            }
        }
    } else if ([type isEqualToString:@"file"]) {
        //NSLog(@"Creating file: %@", path);
        NSData *data = [d objectForKey:@"data"];
        success = [[NSFileManager defaultManager] createFileAtPath:path contents:data attributes:attributes];
        if (! success) {
            NSLog(@"Error creating file: %@", path);
            return NO;
        }
    }
    return YES;
}

@end

#endif
