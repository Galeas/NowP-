//
//  NPStatusItemView.m
//  NowP!
//
//  Created by Евгений Браницкий on 13.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NPStatusItemView.h"

@implementation NPStatusItemView

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _progressIndicator = [[NSProgressIndicator alloc] initWithFrame:frameRect];
        [_progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
        [_progressIndicator setDisplayedWhenStopped:NO];
        [self addSubview:_progressIndicator];
    }
    return self;
}

- (void)setHighlightState:(BOOL)state{
    if(self.clicked != state){
        self.clicked = state;
        [self setNeedsDisplay:YES];
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
    // Drawing code here.
    if(self.clicked) {
        [[NSColor selectedMenuItemColor] set];
        NSRectFill(dirtyRect);
        if(self.image && !self.processing){
            [self drawImage:self.image centeredInRect:dirtyRect];
        }
    } else if (self.image && !self.processing) {
        [self drawImage:self.image centeredInRect:dirtyRect];
    }
}

- (void)drawImage:(NSImage *)aImage centeredInRect:(NSRect)aRect{
    NSRect imageRect = NSMakeRect((CGFloat)round(aRect.size.width*0.5f-aImage.size.width*0.5f),
                                  (CGFloat)round(aRect.size.height*0.5f-aImage.size.height*0.5f),
                                  aImage.size.width,
                                  aImage.size.height);
    [aImage drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0f];
}

- (void)mouseDown:(NSEvent *)theEvent
{
    [super mouseDown:theEvent];
    [self setHighlightState:!self.clicked];
    if ([theEvent modifierFlags] & NSCommandKeyMask){
        [self.target performSelectorOnMainThread:self.rightAction withObject:self waitUntilDone:YES];
    } else {
        [self.target performSelectorOnMainThread:self.action withObject:self waitUntilDone:YES];
    }
    [self setHighlightState:NO];
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
    [super rightMouseDown:theEvent];
    [self setHighlightState:!self.clicked];
    [self.target performSelectorOnMainThread:self.rightAction withObject:self waitUntilDone:YES];
    [self setHighlightState:NO];
}

- (void)setLyricsProcessing:(BOOL)lyricsProcessing
{
    _lp = lyricsProcessing;
    [self updateProcessing];
}

- (void)setArtworkProcessing:(BOOL)artworkProcessing
{
    _ap = artworkProcessing;
    [self updateProcessing];
}

- (void)updateProcessing
{
    BOOL needActive = _ap || _lp;
    needActive ? ([_progressIndicator startAnimation:self]) : ([_progressIndicator stopAnimation:self]);
}

- (BOOL)processing
{
    return _lp || _ap;
}

@end
