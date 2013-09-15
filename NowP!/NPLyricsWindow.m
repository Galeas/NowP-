//
//  NPLyricsWindow.m
//  NowP!
//
//  Created by Евгений Браницкий on 19.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NPLyricsWindow.h"
#import <QuartzCore/QuartzCore.h>

@interface NPLyricsWindow()
@property (nonatomic, strong) CATextLayer *textLayer;
@end

@implementation NPLyricsWindow

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
    self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag];
    if(self)
    {
        [self setLevel:kCGDesktopWindowLevel - 1];
//        [self setLevel:kCGMainMenuWindowLevel];
        [self setCollectionBehavior:(NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary | NSWindowCollectionBehaviorIgnoresCycle)];
        [self setBackgroundColor:[NSColor clearColor]];
        [self setOpaque:NO];
        [self.contentView setWantsLayer:YES];
        
        CATextLayer *layer = [self tLayer];
        [self setTextLayer:layer];
        [[self.contentView layer] addSublayer:self.textLayer];
    }
    return self;
}

- (BOOL)canBecomeMainWindow
{
    return NO;
}

- (BOOL)canBecomeKeyWindow
{
    return NO;
}

- (BOOL)hasShadow
{
    return NO;
}

- (CATextLayer*)tLayer
{
    if (self.textLayer)
        return self.textLayer;
    CATextLayer *layer = [CATextLayer layer];
    if (self.font) {
        [layer setFont:(__bridge CFTypeRef)([self.font fontName])];
        [layer setFontSize:[[[self.font fontDescriptor] objectForKey:NSFontSizeAttribute] floatValue]];
    }
    else {
        [layer setFont:@"Futura"];
        [layer setFontSize:13];
    }
    if (self.textColor) {
        [layer setForegroundColor:[self.textColor CGColor]];
    }
    else {
        [layer setForegroundColor:[[NSColor whiteColor] CGColor]];
    }
    [layer bind:@"string" toObject:self withKeyPath:@"text" options:nil];
    [layer setBackgroundColor:[[NSColor clearColor] CGColor]];
    [layer setAlignmentMode:self.textAlignment];
    [layer setAutoresizingMask:kCALayerWidthSizable|kCALayerHeightSizable];
    [layer setAnchorPoint:CGPointMake(0, 1)];

    return layer;
}

- (void)setText:(NSString *)text
{
    _text = text;
    NSRect screenRect = [self screenRect];
    NSRect expectedRect = [text boundingRectWithSize:NSMakeSize(CGFLOAT_MAX, screenRect.size.height) options:NSLineBreakByWordWrapping | NSStringDrawingUsesLineFragmentOrigin attributes:@{ NSFontAttributeName:self.font }];
    CGFloat height = MIN(screenRect.size.height, expectedRect.size.height);
    
    [CATransaction begin];
    [CATransaction setValue: (id) kCFBooleanTrue forKey: kCATransactionDisableActions];
    if (expectedRect.size.height > height) {
        CGFloat ratio = MAX(height / expectedRect.size.height, .5f);
        [self.textLayer setTransform:CATransform3DMakeScale(ratio, ratio, 1)];
    }
    else {
        [self.textLayer setTransform:CATransform3DMakeScale(1, 1, 1)];
    }
    [self setFrame:NSMakeRect(20, screenRect.size.height - height + screenRect.origin.y - 20, expectedRect.size.width, height) display:YES];
    [CATransaction commit];
}

- (void)setTextAlignment:(NSString *)textAlignment
{
    _textAlignment = textAlignment;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [self.textLayer setAlignmentMode:_textAlignment];
    [CATransaction commit];
}

- (void)setTextColor:(NSColor *)textColor
{
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
    [self.textLayer setFont:(__bridge CFTypeRef)([self.font fontName])];
    [self.textLayer setFontSize:[[[self.font fontDescriptor] objectForKey:NSFontSizeAttribute] floatValue]];
    [CATransaction commit];
    [self setText:self.text];
}

#pragma mark
#pragma mark Helper Methods

- (NSRect)screenRect
{
    NSRect screenRect;
    NSArray *screenArray = [NSScreen screens];
    NSUInteger screenCount = [screenArray count];
    for (unsigned int index = 0; index < screenCount; index++)
    {
        NSScreen *bufferScreen = [screenArray objectAtIndex: index];
        screenRect = [bufferScreen visibleFrame];
    }
    return screenRect;
}

- (void)dealloc
{
    [self.textLayer unbind:@"string"];
}
@end
