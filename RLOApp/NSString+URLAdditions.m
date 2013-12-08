//
//  NSString+URLAdditions.m
//  RLOApp
//
//

#import "NSString+URLAdditions.h"

@implementation NSString (NSString_Extended)

// From http://stackoverflow.com/questions/3423545/objective-c-iphone-percent-encode-a-string/3426140#3426140

- (NSString *)urlencode
{
    NSMutableString *output = [NSMutableString string];
    const unsigned char *source = (const unsigned char *)[self UTF8String];
    size_t sourceLen = strlen((const char *)source);
    for (size_t i = 0; i < sourceLen; ++i) {
        const unsigned char thisChar = source[i];
        if (thisChar == ' '){
            [output appendString:@"+"];
        } else if (thisChar == '.' || thisChar == '-' || thisChar == '_' || thisChar == '~' ||
                   (thisChar >= 'a' && thisChar <= 'z') ||
                   (thisChar >= 'A' && thisChar <= 'Z') ||
                   (thisChar >= '0' && thisChar <= '9')) {
            [output appendFormat:@"%c", thisChar];
        } else {
            [output appendFormat:@"%%%02X", thisChar];
        }
    }
    return output;
}

@end

@implementation NSDictionary (UrlEncoding)

-(NSString*)urlEncodedString
{
    NSMutableArray *parts = [NSMutableArray array];
    for (id key in self) {
        id value = [self objectForKey:key];
        if ([value isKindOfClass:[NSString class]]) {
            value = [value urlencode];
        }
        NSString *part = [NSString stringWithFormat: @"%@=%@", [key urlencode], value];
        [parts addObject: part];
    }
    return [parts componentsJoinedByString: @"&"];
}

@end
