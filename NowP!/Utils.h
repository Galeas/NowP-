//
//  Utils.h
//  NowP!
//
//  Created by Yevgeniy Kratko on 29.08.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#ifndef NowP__Utils_h
#define NowP__Utils_h

#import "NSObject+DeepMutable.h"
@class STTwitterAPI;

extern NSString *const kDefaultsKey;
extern NSString *const kNPPreferencesDidSaveNotification;

extern NSString *const kAppearanceSection;
extern NSString *const kAccountsSection ;
extern NSString *const kAccountsVK;
extern NSString *const kAccountsFB;
extern NSString *const kAccountsTW;
extern NSString *const kAccountsLF;
extern NSString *const kLyricsTagKey;
extern NSString *const kArtworkTagKey;
extern NSString *const kLastTrackID;

extern NSString *const kVKAppKey;
extern NSString *const kFBAppKey;
extern NSString *const kTWAppKey;
extern NSString *const kLFAppKey;
extern NSString *const kLFSecret;

typedef NS_OPTIONS(NSInteger, NPAccountMask) {
    NPEmptyMask = 0,
    NPMaskVK = (0x1 << 1),
    NPMaskFB = (0x1 << 2),
    NPMaskTW = (0x1 << 3),
    NPMaskLF = (0x1 << 4)
};

typedef NS_ENUM(NSUInteger, NPTaggingType) {
    NPLyricsTagging,
    NPArtworkTagging
};

void setTwitterWrapper(STTwitterAPI *wrapper);
STTwitterAPI* getTwitterWrapper();

#pragma mark - Color

CG_INLINE NSColor* RGBA(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    return [NSColor colorWithCalibratedRed:r/255 green:g/255 blue:b/255 alpha:a];
}

CG_INLINE NSColor* RGB(CGFloat r, CGFloat g, CGFloat b) {
    return RGBA(r,g,b,1);
}

#pragma mark - Sort

CG_INLINE NSInteger sortAlpha(NSString *n1, NSString *n2, void *context) {
    return [n1 caseInsensitiveCompare:n2];
}

#pragma mark - Preferences
#pragma mark Saving

CG_INLINE BOOL saveApplicationPreferences(NSDictionary *prefs) {
    [[NSUserDefaults standardUserDefaults] setObject:prefs forKey:kDefaultsKey];
    return [[NSUserDefaults standardUserDefaults] synchronize];
}

CG_INLINE NSMutableDictionary* applicationPreferences() {
    NSDictionary *saved = [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultsKey];
    return saved != nil ? [saved deepMutableCopy] : [[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"embeddedPreferences" ofType:@"plist"]] deepMutableCopy];
}

#pragma mark Tagging

CG_INLINE BOOL needTaggingForType(NPTaggingType type) {
    NSString *key = type == NPLyricsTagging ? kLyricsTagKey : kArtworkTagKey;
    return [[applicationPreferences() valueForKey:key] boolValue];
}

CG_INLINE void setNeedTaggingForType(NPTaggingType type, BOOL need) {
    NSMutableDictionary *prefs = applicationPreferences();
    NSString *key = type == NPLyricsTagging ? kLyricsTagKey : kArtworkTagKey;
    [prefs setValue:@(need) forKey:key];
    saveApplicationPreferences(prefs);
}

#pragma mark Account Mask

CG_INLINE NPAccountMask getAccountMask() {
    __block NPAccountMask mask = NPEmptyMask;
    NSDictionary *accounts = [applicationPreferences() valueForKey:kAccountsSection];
    [accounts enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *obj, BOOL *stop) {
        BOOL enabled = [[obj valueForKey:@"enabled"] boolValue];
        if (enabled) {
            if ([key isEqualToString:@"1001"]) {
                mask |= NPMaskVK;
            }
            if ([key isEqualToString:@"1002"]) {
                mask |= NPMaskFB;
            }
            if ([key isEqualToString:@"1003"]) {
                mask |= NPMaskTW;
            }
            if ([key isEqualToString:@"1004"]) {
                mask |= NPMaskLF;
            }
        }
    }];
    return mask;
}

#pragma mark Facebook
CG_INLINE NSString* getFBToken() {
    NSString *path = [NSString stringWithFormat:@"%@.%@.token", kAccountsSection, kAccountsFB];
    return [applicationPreferences() valueForKeyPath:path];
}

CG_INLINE void setFBToken(NSString *token) {
    NSMutableDictionary *prefs = applicationPreferences();
    NSString *path = [NSString stringWithFormat:@"%@.%@", kAccountsSection, kAccountsFB];
    NSMutableDictionary *fb = [prefs valueForKeyPath:path];
    if ([token length] == 0) {
        [fb removeObjectForKey:@"token"];
        [fb setValue:@(NO) forKey:@"enabled"];
    }
    else {
        [fb setValue:token forKey:@"token"];
        [fb setValue:@(YES) forKey:@"enabled"];
    }
    saveApplicationPreferences(prefs);
}

#pragma mark VKontakte
CG_INLINE NSString* getVKToken() {
    NSString *path = [NSString stringWithFormat:@"%@.%@.token", kAccountsSection, kAccountsVK];
    return [applicationPreferences() valueForKeyPath:path];
}

CG_INLINE void setVKToken(NSString *token) {
    NSMutableDictionary *prefs = applicationPreferences();
    NSString *path = [NSString stringWithFormat:@"%@.%@", kAccountsSection, kAccountsVK];
    NSMutableDictionary *vk = [prefs valueForKeyPath:path];
    if ([token length] == 0) {
        [vk removeObjectForKey:@"token"];
        [vk setValue:@(NO) forKey:@"enabled"];
    }
    else {
        [vk setValue:token forKey:@"token"];
        [vk setValue:@(YES) forKey:@"enabled"];
    }
    saveApplicationPreferences(prefs);
}

#pragma mark LastFM
CG_INLINE NSString* getLFToken() {
    NSString *path = [NSString stringWithFormat:@"%@.%@.token", kAccountsSection, kAccountsLF];
    return [applicationPreferences() valueForKeyPath:path];
}

CG_INLINE void setLFToken(NSString *token) {
    NSMutableDictionary *prefs = applicationPreferences();
    NSString *path = [NSString stringWithFormat:@"%@.%@", kAccountsSection, kAccountsLF];
    NSMutableDictionary *lf = [prefs valueForKeyPath:path];
    if ([token length] == 0) {
        [lf removeObjectForKey:@"token"];
        [lf setValue:@(NO) forKey:@"enabled"];
    }
    else {
        [lf setValue:token forKey:@"token"];
        [lf setValue:@(YES) forKey:@"enabled"];
    }
    saveApplicationPreferences(prefs);
}

#pragma mark Twitter
CG_INLINE void getTwitterCredentials(NSString *__autoreleasing *accountID, NSString *__autoreleasing *token, NSString *__autoreleasing *secret) {
    NSString *path = [NSString stringWithFormat:@"%@.%@", kAccountsSection, kAccountsTW];
    NSMutableDictionary *prefs = applicationPreferences();
    NSMutableDictionary *twitter = [prefs valueForKeyPath:path];
    *accountID = [twitter valueForKey:@"id"];
    *token = [twitter valueForKey:@"token"];
    *secret = [twitter valueForKey:@"secret"];
}

CG_INLINE void setTwitterSystemAccountID(NSString *accountID) {
    NSString *path = [NSString stringWithFormat:@"%@.%@", kAccountsSection, kAccountsTW];
    NSMutableDictionary *prefs = applicationPreferences();
    NSMutableDictionary *twitter = [prefs valueForKeyPath:path];
    if ([accountID length] == 0) {
        [twitter removeObjectForKey:@"id"];
        [twitter setValue:@(NO) forKey:@"enabled"];
    }
    else {
        [twitter setValue:accountID forKey:@"id"];
        [twitter setValue:@(YES) forKey:@"enabled"];
    }
    saveApplicationPreferences(prefs);
}

CG_INLINE void setTwitterCredentials(NSString *token, NSString *secret) {
    NSString *path = [NSString stringWithFormat:@"%@.%@", kAccountsSection, kAccountsTW];
    NSMutableDictionary *prefs = applicationPreferences();
    NSMutableDictionary *twitter = [prefs valueForKeyPath:path];
    if ([token length] == 0 || [secret length] == 0) {
        [twitter removeObjectForKey:@"token"];
        [twitter removeObjectForKey:@"secret"];
        [twitter setValue:@(NO) forKey:@"enabled"];
    }
    else {
        [twitter setValue:token forKey:@"token"];
        [twitter setValue:secret forKey:@"secret"];
        [twitter setValue:@(YES) forKey:@"enabled"];
    }
    saveApplicationPreferences(prefs);
}

#pragma mark Last Track

CG_INLINE NSUInteger getLastTrackID() {
    return [[applicationPreferences() valueForKey:@"lastTrackID"] unsignedIntegerValue];
}

CG_INLINE void setLastTrackID(NSUInteger trackID) {
    NSMutableDictionary *prefs = applicationPreferences();
    [prefs setValue:@(trackID) forKey:@"lastTrackID"];
    saveApplicationPreferences(prefs);
}

#pragma mark - Common

CG_INLINE NSString* alignmentReformat(NSTextAlignment align)
{
    NSString *alignment = nil;
    switch (align) {
        case NSLeftTextAlignment: {
            alignment = @"left";
            break;
        }
        case NSCenterTextAlignment: {
            alignment = @"center";
            break;
        }
        case NSRightTextAlignment: {
            alignment = @"right";
            break;
        }
        default: {
            alignment = @"left";
            break;
        }
    }
    return alignment;
}

#endif
