//
//  NPLyicsWindow.m
//  NowP!
//
//  Created by Yevgeniy Kratko on 08.08.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import "NPLyricsWindow.h"
#import <QuartzCore/QuartzCore.h>

#import "NSString+Extra.h"
#import "NPiTunesWorker.h"
#import "Utils.h"

@interface NPLyricsWindow () <iTunesStateDelegate>
@property (strong, nonatomic) CATextLayer *textLayer;
@property (strong, nonatomic) id preferencesObserver;
@property (assign, nonatomic) CGFloat currentPosition;
@end

@implementation NPLyricsWindow

- (BOOL)canBecomeKeyWindow
{
    return NO;
}

- (BOOL)canBecomeMainWindow
{
    return NO;
}

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
    self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag];
    if (self) {
        [self setLevel:kCGDesktopWindowLevel - 1];
        [self setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorIgnoresCycle | NSWindowCollectionBehaviorStationary];
        
        [self setTextLayer:[self makeTextLayer]];
        [[self contentView] setWantsLayer:YES];
        [[[self contentView] layer] addSublayer:self.textLayer];
        
        NSDictionary *settings = applicationPreferences();
        [self applySettings:settings];
        [self setOpaque:NO];
        [self setHasShadow:NO];
        
        [[NPiTunesWorker worker] setStateDelegate:self];
        
        __weak typeof(self) weakSelf = self;
        [self setPreferencesObserver:[[NSNotificationCenter defaultCenter] addObserverForName:kNPPreferencesDidSaveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            NSDictionary *preferences = [note userInfo];
            [weakSelf applySettings:preferences];
            [weakSelf layoutText];
        }]];
    }
    return self;
}

- (void)applySettings:(NSDictionary*)dict
{
    NSColor *backColor = nil;
    NSFont *font = nil;
    NSString *align = nil;
    NSColor *foreColor = nil;
    if (dict) {
        NSDictionary *lyrics = [[(NSArray*)[dict valueForKey:kAppearanceSection] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name == %@", @"lyrics"]] firstObject];
        foreColor = [NSUnarchiver unarchiveObjectWithData:[lyrics valueForKey:@"foregroundColor"]];
        backColor = [NSUnarchiver unarchiveObjectWithData:[lyrics valueForKey:@"backgroundColor"]];
        font = [NSUnarchiver unarchiveObjectWithData:[lyrics valueForKey:@"font"]];
        align = alignmentReformat([[lyrics valueForKey:@"alignment"] unsignedIntegerValue]);
    }
    else {
        backColor = [NSColor clearColor];
        font = [NSFont fontWithName:@"Futura" size:14];
        foreColor = [NSColor colorWithCalibratedWhite:.9 alpha:1];
    }
    [self setTextColor:foreColor];
    [self setFont:font];
    [self setAlignment:align];
    [self setBackgroundColor:backColor];
    
    if (self.textLayer) {
        CATextLayer *layer = self.textLayer;
        [layer setFont:(__bridge CFTypeRef)([self.font fontName])];
        [layer setFontSize:[[[self.font fontDescriptor] objectForKey:NSFontSizeAttribute] floatValue]];
        [layer setForegroundColor:[self.textColor CGColor]];
        [layer setAlignmentMode:self.alignment];
    }
}

- (CATextLayer*)makeTextLayer
{
    if (self.textLayer) {
        return self.textLayer;
    }
    CATextLayer *layer = [CATextLayer layer];
    [layer setBackgroundColor:[[NSColor clearColor] CGColor]];
    [layer setAutoresizingMask:kCALayerWidthSizable];
    [layer setAnchorPoint:CGPointMake(0, 1)];
    return layer;
}

- (NSRect)screenRect
{
    return [(NSScreen*)[[NSScreen screens] objectAtIndex:0] visibleFrame];
}

- (void)setAlignment:(NSString *)alignment
{
    _alignment = alignment;
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [self.textLayer setAlignmentMode:alignment];
    [CATransaction commit];
}

- (void)setTextColor:(NSColor *)textColor
{
    _textColor = textColor;
    
    _textColor = textColor;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [self.textLayer setForegroundColor:[textColor CGColor]];
    [CATransaction commit];
}

- (void)setFont:(NSFont *)font
{
    _font = font;
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [self.textLayer setFont:(__bridge CFTypeRef)([font fontName])];
    [self.textLayer setFontSize:[font pointSize]];
    [CATransaction commit];
    [self layoutText];
}

- (void)setText:(NSString *)text
{
    _text = text;
    [self layoutText];
}

- (void)layoutText
{
    [self.textLayer removeAllAnimations];
    if ([self.text length] == 0) {
        [self.textLayer setString:nil];
        
    }
    else {
        NSRect rect = [self screenRect];
        NSSize expectedSize = [self.text sizeWithFont:self.font constrainedToSize:CGSizeMake(rect.size.width, CGFLOAT_MAX)];
        CGFloat height = MIN(rect.size.height, expectedSize.height);
        [self setFrame:NSMakeRect(20, rect.size.height - height + rect.origin.y - 20, expectedSize.width, height) display:YES animate:NO];
        
        NSTimeInterval duration = [[NPiTunesWorker worker] currentTrackDuration];
        NSTimeInterval position = [[NPiTunesWorker worker] currentTrackPosition];
        CGFloat ratio = position/duration;
        CGFloat y = height - expectedSize.height;
        CGFloat trueY = y - y*ratio;
        
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        CGRect currentFrame = self.textLayer.frame;
        currentFrame.size.height = expectedSize.height;
        currentFrame.origin.y = trueY;
        [self.textLayer setFrame:currentFrame];
        [self.textLayer setString:self.text];
        [CATransaction commit];
        
        if (expectedSize.height > height && [[NPiTunesWorker worker] playerState] != iTunesPaused) {
            [CATransaction setDisableActions:YES];
            self.textLayer.position = CGPointMake(0, CGRectGetHeight(self.textLayer.frame));
            CABasicAnimation *a1 = [CABasicAnimation animationWithKeyPath:@"position"];
            a1.duration = duration - position;
            [self.textLayer addAnimation:a1 forKey:@"position"];
        }
    }
}

- (void)playerStateDidChange:(iTunesState)state
{
    switch (state) {
        case iTunesPaused:
            [self pauseScrolling];
            break;
        case iTunesPlaying:
            [self resumeScrolling];
            break;
        case iTunesStopped:
            [self setText:nil];
            break;
        default:
            break;
    }
}

- (void)pauseScrolling
{
    CALayer *layer = self.textLayer;
    CFTimeInterval pausedTime = [layer convertTime:CACurrentMediaTime() fromLayer:nil];
    layer.speed = 0.0;
    layer.timeOffset = pausedTime;
}

-(void)resumeScrolling
{
    CALayer *layer = self.textLayer;
    CFTimeInterval pausedTime = [layer timeOffset];
    layer.speed = 1.0;
    layer.timeOffset = 0.0;
    layer.beginTime = 0.0;
    CFTimeInterval timeSincePause = [layer convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
    layer.beginTime = timeSincePause;
}

@end
