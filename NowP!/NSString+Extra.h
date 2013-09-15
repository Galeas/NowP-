//
//  NSString+Extra.h
//  VKAPI
//
//  Created by Евгений Браницкий on 29.03.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (Extra)

- (NSString *)stringBetweenString:(NSString *)first andString:(NSString *)second;
- (NSString*)stringByStrippingHTML;
- (NSString*)stringByReplacingOccurrencesOfCharacterSet:(NSCharacterSet*)set;
- (NSString*)stringUsingEncoding:(NSStringEncoding)encoding;
- (NSSize)sizeForFont:(NSFont*)font;

@end

@interface NSString (LastFM)
+ (NSString *)stringWithNewUUID;
- (NSString *)md5sum;
@end
