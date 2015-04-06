//
//  NPStatusItemButton.m
//  NowP!
//
//  Created by Yevgeniy Kratko on 21.11.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import "NPStatusItemButton.h"

@interface NPStatusItemButton ()
@property (assign, nonatomic) SEL _rightAction;
@end

@implementation NPStatusItemButton

- (void)setRightAction:(SEL)right
{
    [self set_rightAction:right];
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
    NSEvent *newEvent = theEvent;
    BOOL mouseInBounds = NO;
    while (YES)
    {
        mouseInBounds = NSPointInRect([newEvent locationInWindow], [self convertRect:[self frame] fromView:nil]);
        [self highlight:mouseInBounds];
        newEvent = [[self window] nextEventMatchingMask:NSRightMouseDraggedMask | NSRightMouseUpMask];
        if (NSRightMouseUp == [newEvent type])
        {
            break;
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    if (mouseInBounds) [self.target performSelector:self._rightAction withObject:self];
#pragma clang diagnostic pop
}

@end
