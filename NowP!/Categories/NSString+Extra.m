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

- (NSString *)stringByReplacingOccurrencesOfCharacterSet:(NSCharacterSet *)set withString:(NSString*)replace
{
    NSRange range;
    NSString *s = [self copy];
    while ((range = [s rangeOfCharacterFromSet:set]).location != NSNotFound) {
        s = [s stringByReplacingCharactersInRange:range withString:replace];
    }
    return s;
}

- (NSSize)sizeWithFont:(NSFont *)font constrainedToSize:(NSSize)size
{
    NSMutableAttributedString *str = [[NSMutableAttributedString alloc] initWithString:self];
    [str addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, [self length])];
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    [style setLineBreakMode:NSLineBreakByWordWrapping];
    [style setAlignment:NSLeftTextAlignment];
    [str addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(0, [self length])];
    CTFramesetterRef frm = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)str);
    CGSize suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(frm, CFRangeMake(0, 0), NULL, CGSizeMake(size.width, size.height), NULL);
    return NSSizeFromCGSize(suggestedSize);
}

- (NSString *)stringUsingEncoding:(NSStringEncoding)encoding
{
    return (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                 (CFStringRef)self,
                                                                                 NULL,
                                                                                 (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
                                                                                 CFStringConvertNSStringEncodingToEncoding(encoding)));
}

- (NSString *)stringByDecodingHTML
{
    NSMutableString *results = [NSMutableString string];
    NSScanner *scanner = [NSScanner scannerWithString:self];
    [scanner setCharactersToBeSkipped:nil];
    while (![scanner isAtEnd]) {
        NSString *temp;
        if ([scanner scanUpToString:@"&" intoString:&temp]) {
            [results appendString:temp];
        }
        if ([scanner scanString:@"&" intoString:NULL]) {
            BOOL valid = YES;
            unsigned c = 0;
            NSUInteger savedLocation = [scanner scanLocation];
            if ([scanner scanString:@"#" intoString:NULL]) { // it's a numeric entity
                if ([scanner scanString:@"x" intoString:NULL]) { // hexadecimal
                    unsigned int value;
                    if ([scanner scanHexInt:&value]) {
                        c = value;
                    }
                    else {
                        valid = NO;
                    }
                } else { // decimal
                    int value;
                    if ([scanner scanInt:&value] && value >= 0) {
                        c = value;
                    }
                    else {
                        valid = NO;
                    }
                } if (![scanner scanString:@";" intoString:NULL]) { // not ;-terminated, bail out and emit the whole entity
                    valid = NO;
                }
            }
            else {
                if (![scanner scanUpToString:@";" intoString:&temp]) { // &; is not a valid entity
                    valid = NO;
                }
                else if (![scanner scanString:@";" intoString:NULL]) { // there was no trailing ;
                    valid = NO;
                }
                else if ([temp isEqualToString:@"amp"]) {
                    c = '&';
                }
                else if ([temp isEqualToString:@"quot"]) {
                    c = '"';
                }
                else if ([temp isEqualToString:@"lt"]) {
                    c = '<';
                }
                else if ([temp isEqualToString:@"gt"]) {
                    c = '>';
                }
                else { // unknown entity
                    valid = NO;
                }
            }
            if (!valid) { // we errored, just emit the whole thing raw
                [results appendString:[self substringWithRange:NSMakeRange(savedLocation, [scanner scanLocation]-savedLocation)]];
            }
            else {
                [results appendFormat:@"%C", (unichar)c];
            }
        }
    }
    return results;
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
