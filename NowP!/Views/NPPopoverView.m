//
//  NPPopoverView.m
//  NowP!
//
//  Created by Evgeniy Kratko on 26.06.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import "NPPopoverView.h"
#import "NPiTunesWorker.h"
#import "NPView.h"
#import "NPTextLayer.h"

#import "NSImage+Resize.h"
#import "Utils.h"

#import <Accounts/Accounts.h>

#define kPlaceholderImageViewTag 377

@interface NPPopoverView ()
{
    @private
    id _iTunesStateObserver;
    NSTrackingArea *_trackingArea;
    CGFloat _aLayerHeight;
    CGFloat _tLayerHeight;
}

@property (strong, nonatomic) id preferencesObserver;

@property (weak) IBOutlet NSButton *playButton;
@property (strong, nonatomic) NPTextLayer *artistLayer;
@property (strong, nonatomic) NPTextLayer *titleLayer;
@property (weak) IBOutlet NSView *controlView;

@property (strong, nonatomic) NSColor *aBackColor;
@property (strong, nonatomic) NSColor *aFrontColor;
@property (strong, nonatomic) NSFont *aFont;
@property (assign, nonatomic) NSString *aAlignment;

@property (strong, nonatomic) NSColor *tBackColor;
@property (strong, nonatomic) NSColor *tFrontColor;
@property (strong, nonatomic) NSFont *tFont;
@property (assign, nonatomic) NSString *tAlignment;

- (IBAction)backwardAction:(id)sender;
- (IBAction)forwardAction:(id)sender;
- (IBAction)playPauseAction:(id)sender;
@end

@implementation NPPopoverView

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        __weak typeof(self) weakSelf = self;
        self->_iTunesStateObserver = [[NSDistributedNotificationCenter defaultCenter] addObserverForName:@"com.apple.iTunes.playerInfo" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            [weakSelf fetchPlayPauseIcon];
        }];
        
        [self setTitleLayer:[self textLayer:NO]];
        [self setArtistLayer:[self textLayer:YES]];
        [self applyPreferences];
        
        [self setPreferencesObserver:[[NSNotificationCenter defaultCenter] addObserverForName:kNPPreferencesDidSaveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            [weakSelf applyPreferences];
        }]];
        
        [self.titleLayer bind:@"string" toObject:self withKeyPath:@"title" options:nil];
        [self.artistLayer bind:@"string" toObject:self withKeyPath:@"artist" options:nil];
    }
    return self;
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    [self setWantsLayer:YES];
    [self.artworkView setWantsLayer:YES];
    
    [self layoutLayers];
    [[self.artworkView layer] addSublayer:self.artistLayer];
    [[self.artworkView layer] addSublayer:self.titleLayer];
    
    CAShapeLayer *layer = [CAShapeLayer layer];
    [layer setBackgroundColor:[[NSColor colorWithCalibratedWhite:0 alpha:.75] CGColor]];
    [layer setBounds:[self.controlView bounds]];
    [layer setFrame:CGRectMake(0, 0, CGRectGetWidth(layer.bounds), CGRectGetHeight(layer.bounds))];
    [[self.controlView layer] insertSublayer:layer below:[[[self.controlView subviews] objectAtIndex:0] layer]];
    
    [self fetchPlayPauseIcon];
}

- (void)applyPreferences
{
    NSDictionary *preferences = applicationPreferences();
    if (preferences) {
        NSDictionary *aAppearance = [[(NSArray*)[preferences valueForKey:kAppearanceSection] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name == %@", @"artist"]] firstObject];
        [self setAFrontColor:[NSUnarchiver unarchiveObjectWithData:[aAppearance valueForKey:@"foregroundColor"]]];
        [self setABackColor:[NSUnarchiver unarchiveObjectWithData:[aAppearance valueForKey:@"backgroundColor"]]];
        [self setAFont:[NSUnarchiver unarchiveObjectWithData:[aAppearance valueForKey:@"font"]]];
        [self setAAlignment:alignmentReformat([[aAppearance valueForKey:@"alignment"] unsignedIntegerValue])];
        
        NSDictionary *tAppearance = [[(NSArray*)[preferences valueForKey:kAppearanceSection] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name == %@", @"title"]] firstObject];
        [self setTFrontColor:[NSUnarchiver unarchiveObjectWithData:[tAppearance valueForKey:@"foregroundColor"]]];
        [self setTBackColor:[NSUnarchiver unarchiveObjectWithData:[tAppearance valueForKey:@"backgroundColor"]]];
        [self setTFont:[NSUnarchiver unarchiveObjectWithData:[tAppearance valueForKey:@"font"]]];
        [self setTAlignment:alignmentReformat([[tAppearance valueForKey:@"alignment"] unsignedIntegerValue])];
    }
    else {
        [self setAFrontColor:[NSColor colorWithCalibratedWhite:.8 alpha:1]];
        [self setABackColor:[NSColor colorWithCalibratedWhite:0 alpha:.75]];
        [self setAFont:[NSFont fontWithName:@"Lucida Grande Bold" size:14]];
        [self setAAlignment:kCAAlignmentCenter];
        
        [self setTFrontColor:[NSColor colorWithCalibratedWhite:.8 alpha:1]];
        [self setTBackColor:[NSColor colorWithCalibratedWhite:0 alpha:.75]];
        [self setTFont:[NSFont fontWithName:@"Lucida Grande Bold" size:14]];
        [self setTAlignment:kCAAlignmentCenter];
    }
    
    NPTextLayer *layer = nil;
    if (self.artistLayer) {
        layer = self.artistLayer;
        [layer setFont:self.aFont];
        [layer setBackgroundColor:[self.aBackColor CGColor]];
        [layer setTextColor:self.aFrontColor];
        [layer setTextAlignmentMode:self.aAlignment];
        _aLayerHeight = [self sizeForText:@"Test nyarrgh!" forFont:self.aFont].height;
    }
    if (self.titleLayer) {
        layer = self.titleLayer;
        [layer setFont:self.tFont];
        [layer setBackgroundColor:[self.tBackColor CGColor]];
        [layer setTextColor:self.tFrontColor];
        [layer setTextAlignmentMode:self.tAlignment];
        _tLayerHeight = [self sizeForText:@"Test nyarrgh!" forFont:self.tFont].height;
    }
}

- (void)layoutLayers
{
    [self.titleLayer setFrame:CGRectMake(0, 8, [self bounds].size.width, _tLayerHeight)];
    [self.artistLayer setFrame:CGRectMake(0, 8+_tLayerHeight, [self bounds].size.width, _aLayerHeight)];
}

- (void)viewDidMoveToWindow
{
    // Dirty hack
    [self.artistLayer setString:self.artistLayer.string];
    [self.titleLayer setString:self.titleLayer.string];
}

- (void)updateTrackingAreas
{
    if(_trackingArea != nil) {
        [self removeTrackingArea:_trackingArea];
        _trackingArea = nil;
    }
    int opts = (NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways);
    _trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds] options:opts owner:self userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

- (void)mouseEntered:(NSEvent *)theEvent
{
    [[self.controlView animator] setAlphaValue:1.0f];
}

- (void)mouseExited:(NSEvent *)theEvent
{
    [[self.controlView animator] setAlphaValue:.1f];
}

- (NPTextLayer*)textLayer:(BOOL)isArtist
{
    NPTextLayer *layer = [NPTextLayer layer];
    return layer;
}

- (NSSize)sizeForText:(NSString *)text forFont:(NSFont *)font
{
    NSRect expectedRect = [text boundingRectWithSize:NSMakeSize(10000, self.frame.size.height) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{ NSFontAttributeName:font }];
    return expectedRect.size;
}

- (IBAction)backwardAction:(id)sender
{
    [[NPiTunesWorker worker] backTrack];
}

- (IBAction)forwardAction:(id)sender
{
    [[NPiTunesWorker worker] nextTrack];
}

- (IBAction)playPauseAction:(id)sender
{
    [[NPiTunesWorker worker] playPause];
}

- (void)fetchPlayPauseIcon
{
    __weak typeof(self) weakSelf = self;
    iTunesState state = [[NPiTunesWorker worker] playerState];
    if (state == iTunesPaused || state == iTunesStopped) {
        [weakSelf.playButton setImage:[NSImage imageNamed:@"playIcon"]];
    }
    else {
        [weakSelf.playButton setImage:[NSImage imageNamed:@"pauseIcon"]];
    }
}

- (void)setCover:(NSImage *)image
{
    if (image){
        [[self viewWithTag:kPlaceholderImageViewTag] removeFromSuperview];
        [self.artworkView setImage:image];
    }
    else {
        NSImageView *gif = [[NSImageView alloc] initWithFrame:[self.artworkView frame]];
        [gif setTag:kPlaceholderImageViewTag];
        gif.animates = YES;
        gif.image = [NSImage imageNamed:@"giphy"];
        gif.canDrawSubviewsIntoLayer = YES;
        [gif setWantsLayer:YES];
        
        NPTextLayer *text = [self textLayer:NO];
        [text setFont:[NSFont fontWithName:@"Lucida Grande Bold" size:20]];
        [text setTextColor:[NSColor colorWithCalibratedWhite:.8 alpha:1]];
        [text setBackgroundColor:[NSColor colorWithCalibratedWhite:.25 alpha:.75].CGColor];
        [text setTextAlignmentMode:kCAAlignmentCenter];
        CGFloat height = [self sizeForText:@"Test nyarrgh!" forFont:text.font].height * 2;
        [text setFrame:CGRectMake(0, CGRectGetHeight(gif.frame)/2 - height/2, CGRectGetWidth(gif.frame), height)];
        [text setString:@"Player stopped\nClick to play"];
        [gif.layer addSublayer:text];
        
        NSButton *btn = [[NSButton alloc] initWithFrame:[gif bounds]];
        [btn setTarget:self];
        [btn setAction:@selector(playPauseAction:)];
        [btn setAlphaValue:0];
        [gif addSubview:btn];
        
        [self addSubview:gif];
    }
}

- (void)dealloc
{
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:_iTunesStateObserver];
    [self.artistLayer unbind:@"artist"];
    [self.titleLayer unbind:@"title"];
}

- (void)setArtist:(NSString *)artist
{
    [self willChangeValueForKey:@"artist"];
    _artist = artist;
    [self.artistLayer setHidden:[artist length] == 0];
    [self didChangeValueForKey:@"artist"];
}

- (void)setTitle:(NSString *)title
{
    [self willChangeValueForKey:@"title"];
    _title = title;
    [self.titleLayer setHidden:[title length] == 0];
    [self didChangeValueForKey:@"title"];
}

@end
