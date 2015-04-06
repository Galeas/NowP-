//
//  NPAppearance.m
//  NowP!
//
//  Created by Yevgeniy Kratko on 26.08.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import "NPAppearance.h"

NSString *const kNPApperanceName = @"name";
NSString *const kNPApperanceForegroundColor = @"foregroundColor";
NSString *const kNPApperanceBackgroundColor = @"backgroundColor";
NSString *const kNPApperanceFont = @"font";
NSString *const kNPAppearanceTitle = @"title";
NSString *const kNPApperanceAlignment = @"alignment";

@implementation NPAppearance

+ (instancetype)appearanceWithInfo:(NSDictionary *)info
{
    NPAppearance *instance = [[self alloc] init];
    [info enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        if ([obj isKindOfClass:[NSData class]]) {
            [instance setValue:[NSUnarchiver unarchiveObjectWithData:obj] forKey:key];
        }
        else {
            [instance setValue:obj forKey:key];
        }
    }];
    return instance;
}

- (NSDictionary *)infoForArchiving
{
    return @{kNPApperanceName:self.name,
             kNPAppearanceTitle:self.title,
             kNPApperanceForegroundColor:[NSArchiver archivedDataWithRootObject:self.foregroundColor],
             kNPApperanceBackgroundColor:[NSArchiver archivedDataWithRootObject:self.backgroundColor],
             kNPApperanceFont:[NSArchiver archivedDataWithRootObject:self.font],
             kNPApperanceAlignment:@(self.alignment)};
}

@end
