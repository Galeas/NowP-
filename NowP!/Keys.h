//
//  Keys.h
//  NowP!
//
//  Created by Евгений Браницкий on 20.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#ifndef NowP__Keys_h
#define NowP__Keys_h

typedef enum {
    kEmptyFlag = 0,
    kVKFlag = (0x1 << 1),
    kFBFlag = (0x1 << 2),
    kTWFlag = (0x1 << 3),
    kLFFlag = (0x1 << 4)
} ServiceFlag;

typedef enum {
    kAccountsSection,
    kGeneralSection,
} SettingsSection;

typedef enum {
    kIgnoreStatusRestoring,
    kRestoreOnPause,
    kRestoreOnAppExit
} VKStatusRestoringPolicy;

static NSString *const kAppDefaultsKey = @"com.akki.nowp";
static NSString *const kAppIDKey = @"appID";
static NSString *const kUserScreenName = @"screen_name";
static NSString *const kTokenExpiresAt = @"expires_at";

static NSString *const kGeneralKey = @"General";
static NSString *const kFontNameKey = @"font_name";
static NSString *const kFontSizeKey = @"font_size";
static NSString *const kShouldDisplayLyricsKey = @"need_lyrics";
static NSString *const kShouldShareKey = @"need_share";
static NSString *const kFontColorKey = @"font_color";
static NSString *const kAskWhenPrefsClose = @"ask_when_prefs_close";
static NSString *const kAllowControlKey = @"allow_control";
static NSString *const kRunAtStartup = @"run_at_startup";
static NSString *const kVKStatusPolicy = @"vk_status_policy";
static NSString *const kAllowSearcCoversOnLastFM = @"lf_allow_search_covers";

static NSString *const kAccountsKey = @"Accounts";
static NSString *const kVKServiceKey = @"VK";
static NSString *const kFBServiceKey = @"Facebook";
static NSString *const kTWServiceKey = @"Twitter";
static NSString *const kLFServiceKey = @"LastFM";

static NSString *const kAccessTokenKey = @"access_token";
static NSString *const kUserIDKey = @"user_id";
static NSString *const kTwitterOAuthToken = @"oat";
static NSString *const kTwitterOAuthTokenSecret = @"oats";
static NSString *const kLastFMSignature = @"api_sig";
static NSString *const kLastFMSessionKey = @"sk";

static NSString *const kPlayPauseHotkey = @"nowp.playpause.hotkey";
static NSString *const kPrevTrackHotkey = @"nowp.prevtrack.hotkey";
static NSString *const kNextTrackHotkey = @"nowp.nexttrack.hotkey";
static NSString *const kVolumeUpHotkey = @"nowp.volumeup.hotkey";
static NSString *const kVolumeDownHotkey = @"nowp.volumedown.hotkey";
static NSString *const kMuteHotkey = @"now.mute.hotkey";

static NSString *const kTagLyricsCurrent = @"tag_lyrics_current";
static NSString *const kTagArtworkCurrent = @"tag_artwork_current";

#endif
