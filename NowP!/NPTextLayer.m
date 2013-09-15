//
//  NPTextLayer.m
//  NowP!
//
//  Created by Евгений Браницкий on 16.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NPTextLayer.h"

@interface NPTextLayer()
@property (strong, nonatomic) CATextLayer *textLayer;
@end

@implementation NPTextLayer

+ (id)layer
{
    NPTextLayer *instance = [[self alloc] init];
    if (instance) {
        [instance setTextLayer:[CATextLayer layer]];
        [instance.textLayer bind:@"string" toObject:instance withKeyPath:@"string" options:nil];
        [instance.textLayer setBackgroundColor:[NSColor clearColor].CGColor];
        [instance setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
        [instance addSublayer:instance.textLayer];
    }
    return instance;
}

- (NSArray *)exposedBindings
{
    NSMutableArray *bindings = [[super exposedBindings] mutableCopy];
    [bindings addObject:@"string"];
    return (NSArray*)bindings;
}

- (void)setString:(NSString *)string
{
    _string = string;
    CGSize size = NSSizeToCGSize([self sizeForText:_string forFont:self.font]);
    CGRect rect = self.bounds;
    [self setContentsRect:rect];
    if (size.width <= self.frame.size.width) {
        [self.textLayer removeAllAnimations];
        [self.textLayer setAlignmentMode:self.textAlignmentMode];
        [self.textLayer setFrame:CGRectMake(0, 0, rect.size.width, rect.size.height)];
    }
    else {
        [self.textLayer setAlignmentMode:kCAAlignmentNatural];
        [self.textLayer setFrame:CGRectMake(0, 0, size.width, rect.size.height)];
        [self.textLayer addAnimation:[self pulseAnimation] forKey:@"transform.translation.x"];
    }
}

- (void)setFont:(NSFont *)font
{
    _font = font;
    NSString *fontName = [font fontName];
    CGFloat fontSize = [[[font fontDescriptor] objectForKey:NSFontSizeAttribute] floatValue];
    [self.textLayer setFont:(__bridge CFTypeRef)(fontName)];
    [self.textLayer setFontSize:fontSize];
}

- (void)setTextColor:(NSColor *)textColor
{
    _textColor = textColor;
    [self.textLayer setForegroundColor:_textColor.CGColor];
}

#pragma mark
#pragma mark Helper Methods

- (NSSize)sizeForText:(NSString *)text forFont:(NSFont *)font
{
    NSRect expectedRect = [text boundingRectWithSize:NSMakeSize(10000, self.frame.size.height) options:NSLineBreakByWordWrapping attributes:@{ NSFontAttributeName:font }];
    return expectedRect.size;
}

- (CABasicAnimation*)pulseAnimation
{
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"transform.translation.x"];
    CGFloat diff = self.textLayer.frame.size.width - self.frame.size.width;
    [animation setFromValue:@(10)];
    [animation setToValue:@(-diff - 10)];
    [animation setSpeed:.1];
    [animation setAutoreverses:YES];
    [animation setRepeatCount:CGFLOAT_MAX];
    return animation;
}

- (void)dealloc
{
    [self.textLayer unbind:@"string"];
}

@end
