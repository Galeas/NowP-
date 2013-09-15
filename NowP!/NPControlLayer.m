//
//  NPControlLayer.m
//  NowP!
//
//  Created by Евгений Браницкий on 21.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NPControlLayer.h"

@implementation NPControlLayer

+ (id)layer
{
    NPControlLayer *instance = [super layer];
    if (instance) {
        [instance setBackgroundColor:[[NSColor colorWithCalibratedWhite:0 alpha:.75] CGColor]];
        [instance setHiglighted:NO];
    }
    return instance;
}

- (void)drawInContext:(CGContextRef)ctx
{
    CGRect rect = CGRectInset(self.bounds, 5, 5);
    [self drawContext:ctx inRect:rect];
}

- (void)drawContext:(CGContextRef)ctx inRect:(CGRect)rect
{
    [self drawSegment:kLeftSegment inContext:ctx inRect:rect];
    [self drawSegment:kCenterSegment inContext:ctx inRect:rect];
    [self drawSegment:kRightSegment inContext:ctx inRect:rect];    
}

- (void)drawSegment:(Segment)segment inContext:(CGContextRef)ctx inRect:(CGRect)rect
{
    CGRect segmentRect = [self rectForSegment:segment inRect:rect];    
    switch (segment) {
        case kLeftSegment: {            
            NSBitmapImageRep *imgRep = [NSBitmapImageRep imageRepWithContentsOfFile:[[NSBundle mainBundle] pathForImageResource:@"playfor"]];
            NSImage* img = [[NSImage alloc] initWithSize:NSMakeSize(imgRep.pixelsWide, imgRep.pixelsHigh)];
            [img lockFocus];
            NSAffineTransform* t = [NSAffineTransform transform];
            [t translateXBy:imgRep.pixelsWide yBy:imgRep.pixelsHigh];
            [t scaleXBy:-1 yBy:-1];
            [t concat];
            [imgRep drawInRect:NSMakeRect(0, 0, imgRep.pixelsWide, imgRep.pixelsHigh)];
            [img unlockFocus];
            CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)[img TIFFRepresentation], NULL);
            CGImageRef imgRef =  CGImageSourceCreateImageAtIndex(source, 0, NULL);
            CGContextDrawImage(ctx, segmentRect, imgRef);
            CGImageRelease(imgRef);
            CFRelease(source);
            break;
        }
        case kCenterSegment: {            
            NSImage *img;
            if (self.playing) {
                img = [NSImage imageNamed:@"pauseimg"];
            }
            else {
                img = [NSImage imageNamed:@"playimg"];
            }
            CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)[img TIFFRepresentation], NULL);
            CGImageRef imgRef =  CGImageSourceCreateImageAtIndex(source, 0, NULL);
            CGContextDrawImage(ctx, segmentRect, imgRef);
            CGImageRelease(imgRef);
            CFRelease(source);
            break;
        }
        case kRightSegment: {
            NSImage *img = [NSImage imageNamed:@"playfor"];
            CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)[img TIFFRepresentation], NULL);
            CGImageRef imgRef =  CGImageSourceCreateImageAtIndex(source, 0, NULL);
            CGContextDrawImage(ctx, segmentRect, imgRef);
            CGImageRelease(imgRef);
            CFRelease(source);
            break;
        }
        default:break;
    }    
}

- (CGRect)rectForSegment:(Segment)segment inRect:(CGRect)rect
{
    CGFloat width = rect.size.height;
    CGFloat height = rect.size.height;
    CGFloat y0 = rect.origin.y;
    CGFloat x0;
    switch (segment) {
        case kLeftSegment: {
            x0 = rect.origin.x;
            break;
        }
        case kCenterSegment: {
            x0 = CGRectGetMaxX(rect) / 2 - width / 2 ;
            break;
        }
        case kRightSegment: {
            x0 = CGRectGetMaxX(rect) - width;
            break;
        }
    }
    CGRect resultRect = CGRectMake(x0, y0, width, height);
    return resultRect;
}

- (void)setHiglighted:(BOOL)higlighted
{
    if (higlighted) {
        [self setOpacity:1];
    }
    else {
        [self setOpacity:.1];
    }
}

- (void)setPlaying:(BOOL)playing
{
    _playing = playing;
    [self setNeedsDisplay];
}

@end
