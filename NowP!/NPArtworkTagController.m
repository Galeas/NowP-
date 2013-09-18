//
//  NPArtworkTagPopover.m
//  NowP!
//
//  Created by Евгений Браницкий on 28.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NPArtworkTagController.h"
#import "NPArtworkTagger.h"
#import "NPiTunesController.h"
#import "NPStatusItemView.h"
#import "NSString+Extra.h"

@interface NPArtworkViewController : NSViewController
@property (weak) IBOutlet NSScrollView *scrollView;
@property (strong) iTunesTrack *track;
@property (unsafe_unretained) NPArtworkTagController *delegate;
@end

@implementation NPArtworkViewController

- (id)init
{
    self = [super init];
    if (self) {
        [self setView:[[NSView alloc] initWithFrame:NSMakeRect(0, 0, 450, 220)]];
        [self setup];
    }
    return self;
}

- (void)setup
{
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 450, 200)];
    [scroll setAutoresizingMask:NSViewWidthSizable];
    [scroll setBorderType:NSNoBorder];
    [scroll setHasHorizontalScroller:YES];
    [scroll setHasVerticalScroller:NO];
    [scroll setDrawsBackground:NO];
    [scroll setScrollerStyle:[NSScroller preferredScrollerStyle]];
    [[self view] addSubview:scroll];
    [self setScrollView:scroll];
}

- (void)artworkSelected:(id)sender
{
    NSImage *image = [(NSImageView*)[sender superview] image];
    [[[[self.track artworks] objectAtIndex:0] propertyWithCode:'pPCT'] setTo:image];
    [self.delegate.artworkDelegate artworkConfirmed:image forTrack:self.track];
    [self.delegate close];
}

-(void)dealloc
{
    [self setDelegate:nil];
}

@end

@interface NPArtworkView : NSImageView
{
    NSTrackingArea *_area;
    NSImageView *_markerView;
}
@property NSString *sourceType;
@end

@implementation NPArtworkView

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        [self updateTrackingAreas];
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    if (self.image) {
        NSImageRep *rep = [[self.image representations] objectAtIndex:0];
        NSString *str = [NSString stringWithFormat:@"%ldx%ld", [rep pixelsWide], [rep pixelsHigh]];
        NSFont *font = [NSFont fontWithName:@"Lucida Grande Bold" size:14];
        NSSize size = [str sizeForFont:font];
        [str drawInRect:NSMakeRect(2, 2, dirtyRect.size.width, size.height) withAttributes:@{ NSFontAttributeName:font , NSForegroundColorAttributeName:[NSColor colorWithCalibratedWhite:.75 alpha:1] }];
        
        NSImage *sourceMarker = nil;
        if ([self.sourceType isEqualToString:kGoogleImages]) {
            sourceMarker = [NSImage imageNamed:@"google_logo"];
        }
        if ([self.sourceType isEqualToString:kLastFMImages]) {
            sourceMarker = [NSImage imageNamed:@"lastfm"];
        }
        if (sourceMarker) {
//            [sourceMarker drawInRect:NSMakeRect(CGRectGetMaxX(NSRectToCGRect(dirtyRect)) - 2 - sourceMarker.size.width, 2, sourceMarker.size.width, sourceMarker.size.height) fromRect:NSMakeRect(0, 0, sourceMarker.size.width, sourceMarker.size.height) operation:NSCompositeSourceOver fraction:1];
            [sourceMarker drawAtPoint:NSMakePoint(self.bounds.size.width - 2 - sourceMarker.size.width, 2) fromRect:NSMakeRect(0, 0, sourceMarker.size.width, sourceMarker.size.height) operation:NSCompositeSourceOver fraction:1];
        }

//        if (!_markerView) {
//            NSImage *sourceMarker = nil;
//            if ([self.sourceType isEqualToString:kGoogleImages]) {
//                sourceMarker = [NSImage imageNamed:@"google_logo"];
//            }
//            if ([self.sourceType isEqualToString:kLastFMImages]) {
//                sourceMarker = [NSImage imageNamed:@"lastfm"];
//            }
//            if (sourceMarker) {
//                _markerView = [[NSImageView alloc] initWithFrame:NSMakeRect(dirtyRect.size.width - 2 - sourceMarker.size.width, 2, sourceMarker.size.width, sourceMarker.size.height)];
//                [_markerView setImage:sourceMarker];
//                [self addSubview:_markerView];
//            }
//        }
    }
}

-(void)updateTrackingAreas
{
    if(_area != nil) {
        [self removeTrackingArea:_area];
        _area = nil;
    }
    int opts = (NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways);
    _area = [ [NSTrackingArea alloc] initWithRect:[self bounds]
                                          options:opts
                                            owner:self
                                         userInfo:nil];
    [self addTrackingArea:_area];
}

- (void)mouseEntered:(NSEvent *)theEvent
{
    [[[[self subviews] objectAtIndex:0] animator] setAlphaValue:1];
}

- (void)mouseExited:(NSEvent *)theEvent
{
    [[[[self subviews] objectAtIndex:0] animator] setAlphaValue:.3];
}

@end

@interface NPArtworkTagController()
{
    NSView *_sender;
}
@end

@implementation NPArtworkTagController

- (id)init
{
    self = [super init];
    if (self) {
        [self setAppearance:NSPopoverAppearanceHUD];
        [self setBehavior:NSPopoverBehaviorTransient];
        NPArtworkViewController *ctrl = [[NPArtworkViewController alloc] init];
        [ctrl setDelegate:self];
        [self setContentViewController:ctrl];
    }
    return self;
}

- (void)getArtwork:(iTunesTrack *)track sender:(NSView*)senderView lastFMAllowed:(BOOL)lfAllowed
{
    NPArtworkTagger *tagger = [[NPArtworkTagger alloc] initWithTrack:track];
    [tagger setGoogleImages:YES];
    [tagger setLastFM:lfAllowed];
    [[(NPArtworkViewController*)self.contentViewController scrollView] setDocumentView:nil];
    _sender = senderView;
    [self setTrack:track];
    
    [(NPStatusItemView*)_sender setArtworkProcessing:YES];
    __weak NPArtworkTagController *weakSelf = self;
    [tagger runWithCompletion:^(NSDictionary *images){
        NPArtworkTagController *strongSelf = weakSelf;
        if (!strongSelf) return;
        if ([images count] > 0) {
            [strongSelf setTrackArtworks:images];
            NSView *imagesContainer = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 0, 190)];
            CGFloat currentX = 5;
            for (NSString *key in images) {
                NSArray *source = [images objectForKey:key];
                @autoreleasepool {
                    for (NSImage *image in source) {
                        NPArtworkView *imgView = [[NPArtworkView alloc] initWithFrame:NSMakeRect(currentX, 5, 190, 190)];
                        [imgView setSourceType:key];
                        [imgView setImageScaling:NSImageScaleProportionallyUpOrDown];
                        [imgView setImageAlignment:NSImageAlignCenter];
                        [imgView setImage:image];
                        
                        NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(190/2 - 60.5, 190/2 - 13, 121, 26)];
                        [btn setTarget:strongSelf.contentViewController];
                        [btn setAction:@selector(artworkSelected:)];
                        [btn setAlphaValue:.3];
                        [btn setImage:[NSImage imageNamed:@"use_artwork_bg"]];
                        [[btn cell] setHighlightsBy:NSContentsCellMask];
                        [btn setButtonType:NSMomentaryChangeButton];
                        [btn setBordered:NO];
                        [btn setTitle:@""];
                        [btn setImagePosition:NSImageOnly];
                        [imgView addSubview:btn];
                        
                        [imagesContainer addSubview:imgView];
                        currentX += 195;
                    }
                }
            }
            NPArtworkViewController *viewController = (NPArtworkViewController*)weakSelf.contentViewController;
            [imagesContainer setFrameSize:NSMakeSize(currentX, 190)];
            if (imagesContainer.frame.size.width < 450) {
                [viewController.view setFrameSize:NSMakeSize(imagesContainer.frame.size.width, 215)];
                [viewController.scrollView setHasHorizontalScroller:NO];
            }
            else {
                [viewController.view setFrameSize:NSMakeSize(450, 215)];
                [viewController.scrollView setHasHorizontalScroller:YES];
            }
            [strongSelf setContentSize:viewController.view.frame.size];
            
            [viewController setTrack:track];
            [[viewController scrollView] setDocumentView:imagesContainer];
            [strongSelf showRelativeToRect:[strongSelf->_sender frame] ofView:strongSelf->_sender preferredEdge:NSMinYEdge];
        }
        [(NPStatusItemView*)strongSelf->_sender setArtworkProcessing:NO];
    }];
}

- (void)setTrack:(iTunesTrack *)track
{
    _track = track;
    if (!track) {
        [[(NPArtworkViewController*)self.contentViewController scrollView] setDocumentView:nil];
        [self setTrackArtworks:nil];
    }
}

- (void)dealloc
{
    [self setArtworkDelegate:nil];
}

@end
