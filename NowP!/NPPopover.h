//
//  NPPopover.h
//  NowP!
//
//  Created by Евгений Браницкий on 13.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@interface NPPopover : NSPopover
@property (weak, nonatomic) NSString *artist;
@property (weak, nonatomic) NSString *name;
@property (weak, nonatomic) NSImage *artwork;

- (void)setControlEnabled:(BOOL)enabled;

@end
