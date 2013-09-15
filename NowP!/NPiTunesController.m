//
//  NPiTunesController.m
//  NowP!
//
//  Created by Евгений Браницкий on 29.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NPiTunesController.h"

@interface NPiTunesController()
@property (strong) iTunesApplication *itunesApp;
@end

@implementation NPiTunesController

+ (iTunesApplication *)iTunes
{
    return [[NPiTunesController sharedITunes] itunesApp];
}

+ (instancetype)sharedITunes
{
    static NPiTunesController *instance = nil;
    static dispatch_once_t predicate;
    dispatch_once( &predicate, ^{
        instance = [[NPiTunesController alloc] init];
    } );
    return instance;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self setItunesApp:[SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"]];
    }
    return self;
}

@end
