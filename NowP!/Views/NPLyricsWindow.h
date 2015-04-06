//
//  NPLyicsWindow.h
//  NowP!
//
//  Created by Yevgeniy Kratko on 08.08.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NPLyricsWindow : NSWindow
@property (strong, nonatomic) NSString *text;
@property (strong, nonatomic) NSColor *textColor;
@property (strong, nonatomic) NSFont *font;
@property (strong, nonatomic) NSString *alignment;
@end
