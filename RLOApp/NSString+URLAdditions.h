//
//  NSString+URLAdditions.h
//  RLOApp
//
//  Created by michael on 1/30/13.
//
//

#import <Foundation/Foundation.h>

@interface NSString (NSString_Extended)
- (NSString *)urlencode;
@end

@interface NSDictionary (UrlEncoding)
-(NSString*)urlEncodedString;
@end
