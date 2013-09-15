//
//  NPControlLayer.h
//  NowP!
//
//  Created by Евгений Браницкий on 21.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

typedef enum {
    kLeftSegment,
    kCenterSegment,
    kRightSegment
} Segment;

@interface NPControlLayer : CAShapeLayer
@property (assign, nonatomic) BOOL higlighted;
@property (assign, nonatomic) BOOL playing;

- (CGRect)rectForSegment:(Segment)segment inRect:(CGRect)rect;
@end
