//
//  NPLyricsWindow.h
//  NowP!
//
//  Created by Евгений Браницкий on 19.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NPLyricsWindow : NSWindow
@property (nonatomic, strong) NSString *text;
@property (nonatomic, strong) NSFont *font;
@property (nonatomic, strong) NSColor *textColor;
@property (nonatomic, strong) NSString *textAlignment;
@end
