 //
//  NSString+Extra.m
//  VKAPI
//
//  Created by Евгений Браницкий on 29.03.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NSString+Extra.h"
//#import "Utils.h"

#import <CommonCrypto/CommonDigest.h>

@implementation NSString (Extra)

- (NSString *)stringBetweenString:(NSString *)first andString:(NSString *)second
{
    NSScanner* scanner = [NSScanner scannerWithString:self];
    [scanner setCharactersToBeSkipped:nil];
    [scanner scanUpToString:first intoString:NULL];
    if ([scanner scanString:first intoString:NULL]) {
        NSString* result = nil;
        if ([scanner scanUpToString:second intoString:&result]) {
            return result;
        }
    }
    return nil;
}

- (NSString *)stringByStrippingHTML
{
    NSRange r;
    NSString *s = [self copy];
    while ((r = [s rangeOfString:@"<[^>]+>" options:NSRegularExpressionSearch]).location != NSNotFound)
        s = [s stringByReplacingCharactersInRange:r withString:@""];
    return s;
}

- (NSString *)stringByReplacingOccurrencesOfCharacterSet:(NSCharacterSet *)set
{
    NSRange range;
    NSString *s = [self copy];
    while ((range = [s rangeOfCharacterFromSet:set]).location != NSNotFound) {
        s = [s stringByReplacingCharactersInRange:range withString:@""];
    }
    return s;
}

- (NSSize)sizeForFont:(NSFont *)font
{
    NSRect expectedRect = [self boundingRectWithSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX) options:NSLineBreakByWordWrapping attributes:@{ NSFontAttributeName:font }];
    return expectedRect.size;
}

- (NSString *)stringUsingEncoding:(NSStringEncoding)encoding
{
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                 (CFStringRef)self,
                                                                                 NULL,
                                                                                 (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
                                                                                 CFStringConvertNSStringEncodingToEncoding(encoding)));
}

@end

@implementation NSString (LastFM)

+ (NSString *)stringWithNewUUID
{
    CFUUIDRef uuidObj = CFUUIDCreate(nil);
    NSString *newUUID = (NSString*)CFBridgingRelease(CFUUIDCreateString(nil, uuidObj));
    CFRelease(uuidObj);
    return newUUID;
}

- (NSString *)md5sum
{
    unsigned char digest[CC_MD5_DIGEST_LENGTH], i;
	CC_MD5([self UTF8String], (CC_LONG)[self lengthOfBytesUsingEncoding:NSUTF8StringEncoding], digest);
	NSMutableString *ms = [NSMutableString string];
	for (i=0;i<CC_MD5_DIGEST_LENGTH;i++) {
		[ms appendFormat: @"%02x", (int)(digest[i])];
	}
	return [ms copy];
}

@end
