//
//  NPMainHandler.h
//  NowP!
//
//  Created by Евгений Браницкий on 05.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NPMainHandler : NSObject
+ (instancetype)handler;
- (void)iTunesInfoDidUpdate;
- (void)setSocialStatus:(NSDictionary*)info;
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (assign, nonatomic) NSInteger accountsConfiguration;
@end
