//
//  NPImageView.m
//  NowP!
//
//  Created by Евгений Браницкий on 13.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NPImageView.h"

@implementation NPImageView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    // Drawing code here.
    [NSGraphicsContext saveGraphicsState];
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:dirtyRect xRadius:5 yRadius:5];
    [path addClip];
    [self.image drawAtPoint:NSZeroPoint fromRect:dirtyRect operation:NSCompositeSourceOver fraction: 1.0];
    [path stroke];
    [NSGraphicsContext restoreGraphicsState];
}

@end
