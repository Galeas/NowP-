//
//  NPColoredTCell.m
//  NowP!
//
//  Created by Yevgeniy Kratko on 26.08.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import "NPColoredTCell.h"

@implementation NPColoredTCell

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    if (self.backgroundColor) {
        [self.backgroundColor setFill];
        NSRectFill(dirtyRect);
    }
    [super drawRect:dirtyRect];
}

- (NSArray *)exposedBindings
{
    NSMutableArray *b = [[super exposedBindings] mutableCopy];
    [b addObject:@"backgroundColor"];
    return b;
}

- (void)setObjectValue:(id)objectValue
{
    @try {
        [self unbind:@"backgroundColor"];
        [self.textField unbind:@"alignment"];
    }
    @catch (NSException *exception) {}
    if (objectValue) {
        [self bind:@"backgroundColor" toObject:objectValue withKeyPath:@"backgroundColor" options:nil];
        [self.textField bind:@"alignment" toObject:objectValue withKeyPath:@"alignment" options:nil];
    }
    
    [super setObjectValue:objectValue];
}

@end
