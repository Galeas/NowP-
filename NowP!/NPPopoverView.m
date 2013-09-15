//
//  NPPopoverView.m
//  NowP!
//
//  Created by Евгений Браницкий on 13.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NPPopoverView.h"
#import "NSImage+Resize.h"
#import "NPTextLayer.h"
#import "NPPlayerControlView.h"

#import "NPPreferencesController.h"

#import <QuartzCore/QuartzCore.h>


@interface NPPopoverView ()
{
    CGFloat _layerHeight;
    NSTrackingArea *_area;
    BOOL _viewLoaded;
}

@property (strong, nonatomic) NPTextLayer *artistLayer;
@property (strong, nonatomic) NPTextLayer *nameLayer;

@end

@implementation NPPopoverView

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self->_layerHeight = 0;
        self->_viewLoaded = NO;
        // Initialization code here.
    }
    
    return self;
}

- (void)loadView
{
    [super loadView];
    [self updateTrackingAreas];
    _viewLoaded = YES;
    
    [[self view] setWantsLayer:YES];
    
    [self setControlEnabled:[[NPPreferencesController preferences] allowControl]];
    
    [self setNameLayer:[self textLayer]];
    [self.nameLayer setFrame:CGRectMake(0, 8, [[self view] bounds].size.width, _layerHeight)];
    
    [self setArtistLayer:[self textLayer]];
    [self.artistLayer setFrame:CGRectMake(0, 8+_layerHeight, [[self view] bounds].size.width, _layerHeight)];
    
    [[[self view] layer] addSublayer:self.artistLayer];
    [[[self view] layer] addSublayer:self.nameLayer];
    
    [self.nameLayer bind:@"string" toObject:self withKeyPath:@"name" options:nil];
    [self.artistLayer bind:@"string" toObject:self withKeyPath:@"artist" options:nil];
}

- (void)setControlEnabled:(BOOL)enabled
{
    if (_viewLoaded) {
        if (enabled) {
            if (!self.control) {
                [self setControl:[[NPPlayerControlView alloc] initWithFrame:NSMakeRect(0, self.view.bounds.size.height/2 - 25, self.view.bounds.size.width, 50)]];
                [self.view addSubview:self.control];
            }
        }
        else if (!enabled) {
            [self.control removeFromSuperview];
            [self setControl:nil];
        }
    }
}

- (NPTextLayer*)textLayer
{
    NPTextLayer *layer = [NPTextLayer layer];
    NSFont *font = [NSFont fontWithName:@"Lucida Grande Bold" size:14];
    [layer setFont:font];
    [layer setBackgroundColor:[NSColor colorWithCalibratedWhite:0 alpha:.75].CGColor];
    [layer setTextColor:[NSColor colorWithCalibratedWhite:.8 alpha:1]];
    [layer setTextAlignmentMode:kCAAlignmentCenter];
    if (_layerHeight == 0) {
        _layerHeight = [self sizeForText:@"Test nyarrgh!" forFont:font].height;
    }
    return layer;
} 

- (NSSize)sizeForText:(NSString *)text forFont:(NSFont *)font
{
    NSRect expectedRect = [text boundingRectWithSize:NSMakeSize(10000, self.view.frame.size.height) options:NSLineBreakByWordWrapping attributes:@{ NSFontAttributeName:font }];
    return expectedRect.size;
}

- (void)mouseEntered:(NSEvent *)theEvent
{
    [self.control setHighlighted:YES];
}

- (void)mouseExited:(NSEvent *)theEvent
{
    [self.control setHighlighted:NO];
}

-(void)updateTrackingAreas
{
    if(_area != nil) {
        [self.view removeTrackingArea:_area];
        _area = nil;
    }
    int opts = (NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways);
    _area = [ [NSTrackingArea alloc] initWithRect:[self.view bounds]
                                                 options:opts
                                                   owner:self
                                                userInfo:nil];
    [self.view addTrackingArea:_area];
}

- (void)setArtwork:(NSImage *)artwork
{
    _artwork = nil;
    _artwork = [artwork imageByScalingProportionallyToSize:NSMakeSize(200, 200)];
}

- (void)dealloc
{
    [self.artistLayer unbind:@"artist"];
    [self.nameLayer unbind:@"name"];
}

@end
