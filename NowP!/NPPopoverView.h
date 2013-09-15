//
//  NPPopoverView.h
//  NowP!
//
//  Created by Евгений Браницкий on 13.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class NPTickerView;
@class NPPlayerControlView;
@interface NPPopoverView : NSViewController

@property (strong, nonatomic) NSString *artist;
@property (strong, nonatomic) NSString *name;
@property (strong, nonatomic) NSImage *artwork;

@property (strong, nonatomic) NPPlayerControlView *control;
- (void)setControlEnabled:(BOOL)enabled;
@end
