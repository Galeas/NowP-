//
//  NPAppDelegate.m
//  NowP!
//
//  Created by Evgeniy Kratko on 24.06.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import "NPAppDelegate.h"
#import "NPiTunesWorker.h"
#define kUserAgentKey @"UserAgent"

@implementation NPAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Insert code here to initialize your application
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{ kUserAgentKey : @"Lyrically/3.0.2 (iPad; iOS 7.1.2; Scale/2.00)" }];
    [[NPiTunesWorker worker] fetchCurrentTrackInfo];

#ifdef DEBUG
    NSSetUncaughtExceptionHandler(&uncaughtExceptionHandler);
#endif
}

#ifdef DEBUG
void uncaughtExceptionHandler(NSException *exception) {
    DLog(@"exception:%@", exception.reason);
}
#endif

- (void)applicationWillTerminate:(NSNotification *)notification
{
    NSUInteger last = [[NPiTunesWorker worker] currentTrackID];
    setLastTrackID(last);
}

@end
