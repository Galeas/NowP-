//
//  NPPrefsController.h
//  NowP!
//
//  Created by Yevgeniy Kratko on 27.08.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class STTwitterAPI;
@interface NPPrefsController : NSViewController
- (void)renewFBCredentials:(void(^)(BOOL success))completion;
@end
