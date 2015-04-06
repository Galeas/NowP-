//
//  NPTextLayer.h
//  NowP!
//
//  Created by Евгений Браницкий on 16.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@interface NPTextLayer : CALayer

@property (strong, nonatomic) NSString *string;
@property (strong, nonatomic) NSFont *font;
@property (strong, nonatomic) NSColor *textColor;
@property (strong, nonatomic) NSString *textAlignmentMode;

@end
