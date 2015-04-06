//
//  NPMainHandler.h
//  NowP!
//
//  Created by Evgeniy Kratko on 24.06.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import <Foundation/Foundation.h>
@class NPStatusItemView;
@interface NPMainHandler : NSObject
//+ (instancetype)handler;
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) IBOutlet NSPopover *popover;
@end
