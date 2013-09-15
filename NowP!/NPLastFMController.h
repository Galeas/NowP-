//
//  NPLastFMController.h
//  NowP!
//
//  Created by Евгений Браницкий on 11.09.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NPLastFMController : NSObject

+ (BOOL)scrobbleArtist:(NSString*)artist title:(NSString*)title sessionKey:(NSString*)sessionKey;
- (void)loginModalForWindow:(NSWindow*)parentWindow completion:(void(^)(NSDictionary*, NSError*))completion;

@end
