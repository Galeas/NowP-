//
//  NPView.m
//  NowP!
//
//  Created by Evgeniy Kratko on 27.06.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import "NPView.h"

@implementation NPView

- (void)drawRect:(NSRect)dirtyRect
{
    if (self.backgroundColor) {
        [self.backgroundColor setFill];
        NSRectFill(dirtyRect);
    }
    [super drawRect:dirtyRect];
}

@end
