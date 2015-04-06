//
//  NPPopoverView.h
//  NowP!
//
//  Created by Evgeniy Kratko on 26.06.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NPPopoverView : NSView
@property (weak) IBOutlet NSImageView *artworkView;
@property (strong, nonatomic) NSString *artist;
@property (strong, nonatomic) NSString *title;
- (void)setCover:(NSImage*)image;
//- (void)setArtist:(NSString*)artist;
//- (void)setTitle:(NSString*)title;
@end
