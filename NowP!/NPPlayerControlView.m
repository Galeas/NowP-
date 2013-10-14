//
//  NPPlayerControlView.m
//  NowP!
//
//  Created by Евгений Браницкий on 23.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NPPlayerControlView.h"
#import "NPControlLayer.h"
#import "NPiTunesController.h"

#import <QuartzCore/QuartzCore.h>

@interface NPPlayerControlView()
@property (strong, nonatomic) NPControlLayer *controlLayer;
@property (strong, nonatomic) NSButton *revButton;
@property (strong, nonatomic) NSButton *playButton;
@property (strong, nonatomic) NSButton *forwardButton;
@end

@implementation NPPlayerControlView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        [self setWantsLayer:YES];
        [self setControlLayer:[NPControlLayer layer]];
        [self.controlLayer setFrame:NSRectToCGRect(self.bounds)];
        [self.layer addSublayer:self.controlLayer];
        [self.controlLayer setNeedsDisplay];
        
        [self setRevButton:[self controlButtonForSegment:kLeftSegment]];
        [self setPlayButton:[self controlButtonForSegment:kCenterSegment]];
        [self setForwardButton:[self controlButtonForSegment:kRightSegment]];
        [self addSubview:self.revButton];
        [self addSubview:self.playButton];
        [self addSubview:self.forwardButton];
        
        [self iTunesDidChangeState:nil];
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(iTunesDidChangeState:) name:@"com.apple.iTunes.playerInfo" object:nil];
    }
    return self;
}

- (NSButton*)controlButtonForSegment:(Segment)segment
{
    NSRect rect = NSRectFromCGRect([self.controlLayer rectForSegment:segment inRect:self.controlLayer.frame]);
    NSButton *btn = [[NSButton alloc] initWithFrame:rect];
    [btn setTarget:[NPiTunesController iTunes]];
    [btn setAlphaValue:0];
    [btn setEnabled:YES];
    
    switch (segment) {
        case kLeftSegment: {
            [btn setAction:@selector(backTrack)];
            break;
        }
        case kCenterSegment: {
            [btn setAction:@selector(playpause)];
            break;
        }
        case kRightSegment: {
            [btn setAction:@selector(nextTrack)];
            break;
        }
    }
    
    return btn;
}

- (void)iTunesDidChangeState:(NSNotification*)note
{
    iTunesEPlS state = [self iTunesState];
    if (state == iTunesEPlSPaused || state == iTunesEPlSStopped) {
        [self.controlLayer setPlaying:NO];
    }
    else {
        [self.controlLayer setPlaying:YES];
    }
}

- (iTunesEPlS)iTunesState
{
    iTunesApplication *itunes = [NPiTunesController iTunes];
    if ([itunes isRunning]) {
        iTunesEPlS state = [NPiTunesController iTunes].playerState;
        return state;
    }
    return iTunesEPlSStopped;
}

- (void)setHighlighted:(BOOL)highlighted
{
    _highlighted = highlighted;
    [self.controlLayer setHiglighted:_highlighted];
}

- (void)dealloc
{
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

@end
