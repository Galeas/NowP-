//
//  NPStatusItemView.h
//  NowP!
//
//  Created by Евгений Браницкий on 13.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NPStatusItemView : NSView
{
    NSProgressIndicator *_progressIndicator;
    BOOL _lp;
    BOOL _ap;
}
@property (strong, nonatomic) NSImage *image;
@property (strong, nonatomic) id target;
@property (assign, nonatomic) BOOL clicked;
@property (assign, nonatomic) SEL rightAction;
@property (assign, nonatomic) SEL action;

- (void)setLyricsProcessing:(BOOL)lyricsProcessing;
- (void)setArtworkProcessing:(BOOL)artworkProcessing;
@property (assign, nonatomic, readonly) BOOL processing;
@end
