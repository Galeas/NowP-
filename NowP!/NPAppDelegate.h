//
//  NPAppDelegate.h
//  NowP!
//
//  Created by Евгений Браницкий on 05.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class NPMainHandler;
@interface NPAppDelegate : NSObject <NSApplicationDelegate>
{
    NPMainHandler *_mainHandler;
    BOOL _canTerminate;
}
@property (strong, nonatomic) NSString *cachedVKStatus;
@property (assign, nonatomic) BOOL needUpdateVKStatus;
- (void)cacheVKStatus;
- (void)restoreVKStatusOnTerminate:(BOOL)terminate;
@end
