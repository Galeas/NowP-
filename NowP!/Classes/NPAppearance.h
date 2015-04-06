//
//  NPAppearance.h
//  NowP!
//
//  Created by Yevgeniy Kratko on 26.08.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const kNPApperanceName;
extern NSString *const kNPApperanceForegroundColor;
extern NSString *const kNPApperanceBackgroundColor;
extern NSString *const kNPApperanceFont;
extern NSString *const kNPApperanceAlignment;

@interface NPAppearance : NSObject
@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSString *title;
@property (strong, nonatomic) NSColor *foregroundColor;
@property (strong, nonatomic) NSColor *backgroundColor;
@property (strong, nonatomic) NSFont *font;
@property (assign, nonatomic) NSTextAlignment alignment;
+ (instancetype)appearanceWithInfo:(NSDictionary*)info;
- (NSDictionary*)infoForArchiving;
@end
