//
//  Utils.m
//  NowP!
//
//  Created by Yevgeniy Kratko on 03.12.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import "Utils.h"
#import <STTwitterAPI.h>

NSString *const kDefaultsKey = @"NowPPreferences";
NSString *const kNPPreferencesDidSaveNotification = @"NowP:PreferencesDidSave";

NSString *const kAppearanceSection = @"appearance";
NSString *const kAccountsSection = @"accounts";
NSString *const kAccountsVK = @"1001";
NSString *const kAccountsFB = @"1002";
NSString *const kAccountsTW = @"1003";
NSString *const kAccountsLF = @"1004";
NSString *const kLyricsTagKey = @"tag_lyrics";
NSString *const kArtworkTagKey = @"tag_artwork";
NSString *const kLastTrackID = @"last_track_id";

NSString *const kVKAppKey = @"3806400";
NSString *const kFBAppKey = @"349274525203295";
NSString *const kTWAppKey = @"OuPD9mLkC38QbIf2DSVw";
NSString *const kLFAppKey = @"842f9a0390954bf47248f25a44adfba9";
NSString *const kLFSecret = @"a7a945d061f0d68acac6d420a2747ddb";

static STTwitterAPI *twitterWrapper = nil;

inline void setTwitterWrapper(STTwitterAPI *wrapper) {
    if (!wrapper) {
        NSString *path = [NSString stringWithFormat:@"%@.%@", kAccountsSection, kAccountsTW];
        NSMutableDictionary *prefs = applicationPreferences();
        NSMutableDictionary *twitter = [prefs valueForKeyPath:path];
        [twitter removeObjectsForKeys:@[@"id", @"token", @"secret"]];
        [twitter setValue:@(NO) forKey:@"enabled"];
        saveApplicationPreferences(prefs);
    }
    twitterWrapper = wrapper;
};

STTwitterAPI* getTwitterWrapper(){
    return twitterWrapper;
};