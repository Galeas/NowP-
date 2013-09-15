//
//  NPPopover.m
//  NowP!
//
//  Created by Евгений Браницкий on 13.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NPPopover.h"
#import "NPPopoverView.h"

@implementation NPPopover

- (id)init
{
    self = [super init];
    if (self) {
        [self setAppearance:NSPopoverAppearanceHUD];
        [self setBehavior:NSPopoverBehaviorTransient];
        [self setContentViewController:[[NPPopoverView alloc] initWithNibName:@"NPPopoverView" bundle:nil]];
    }
    return self;
}

- (void)setArtist:(NSString *)artist
{
    NPPopoverView *ctrl = (NPPopoverView*)self.contentViewController;
    [ctrl setArtist:artist];
}

- (void)setName:(NSString *)name
{
    NPPopoverView *ctrl = (NPPopoverView*)self.contentViewController;
    [ctrl setName:name];
}

- (void)setArtwork:(NSImage *)artwork
{
    NPPopoverView *ctrl = (NPPopoverView*)self.contentViewController;
    [ctrl setArtwork:artwork];
}

- (void)setControlEnabled:(BOOL)enabled
{
    NPPopoverView *ctrl = (NPPopoverView*)self.contentViewController;
    [ctrl setControlEnabled:enabled];
}

@end
