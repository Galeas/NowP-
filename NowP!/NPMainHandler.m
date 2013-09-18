//
//  NPMainHandler.m
//  NowP!
//
//  Created by Евгений Браницкий on 13.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NPMainHandler.h"
#import "NPPreferencesController.h"
#import "NPLastFMController.h"
#import "NPAppDelegate.h"
#import "NPAboutController.h"

#import "NPPopover.h"
#import "NPStatusItemView.h"
#import "NPLyricsWindow.h"

#import "NPLyricsTagger.h"
#import "NPArtworkTagController.h"

#import "STTwitterAPIWrapper.h"
#import "MASShortcut+UserDefaults.h"

#import "NPiTunesController.h"

#import "NSString+Extra.h"
#import "NSColor+Hex.h"

@interface NPMainHandler() <PreferencesDelegate, ArtworkHunter>
{
    BOOL _VKOnly;
    NPAboutController *_about;
}
@property (strong, nonatomic) NPPopover *popover;
@property (strong, nonatomic) NPArtworkTagController *artworkPopover;
@property (strong, nonatomic) NPLyricsWindow *lyricsWindow;
@property (strong, nonatomic) STTwitterAPIWrapper *twitter;

@property (assign, nonatomic) NSInteger currentTrackID;
@property (assign, nonatomic) NSInteger lastSendedTrackID;
@end

@implementation NPMainHandler

+ (instancetype)handler
{
    static NPMainHandler *main = nil;
    static dispatch_once_t predicate;
    dispatch_once( &predicate, ^{
        main = [[NPMainHandler alloc] init];
    } );
    return main;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self setStatusItem:[self createStatusItem]];
        [self setPopover:[[NPPopover alloc] init]];
        [self setArtworkPopover:[[NPArtworkTagController alloc] init]];
        [self.artworkPopover setArtworkDelegate:self];
        
        NPPreferencesController *ctrl = [NPPreferencesController preferences];
        [self setAccountsConfiguration:[ctrl accountsConfiguration]];
        [self setCurrentTrackID:NSNotFound];
        [self setLastSendedTrackID:NSNotFound];
        
        [self connectShortcuts:[[NPPreferencesController preferences] allowControl]];
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(iTunesInfoDidUpdate) name:@"com.apple.iTunes.playerInfo" object:nil];
        [[NPPreferencesController preferences] setDelegate:self];
        
        _about = [[NPAboutController alloc] initWithWindowNibName:@"NPAboutController"];
    }
    return self;
}

#pragma mark
#pragma mark ---- Preferences Delegate ----

- (void)preferencesDidSaved:(NSDictionary *)preferences
{
    [self setCurrentTrackID:NSNotFound];
    [self setAccountsConfiguration:[[NPPreferencesController preferences] accountsConfiguration]];
    
    NSDictionary *general = [preferences copy];
    
    BOOL needLyricsWindow = [[general valueForKey:kShouldDisplayLyricsKey] boolValue];
    if (needLyricsWindow && self.lyricsWindow == nil) {
        [self setLyricsWindow:[self windowForLyrics]];
    }
    else if (!needLyricsWindow) {
        [self.lyricsWindow close];
        [self setLyricsWindow:nil];
    }
    
    if (self.lyricsWindow) {
        CGFloat fontSize = [[general valueForKey:kFontSizeKey] floatValue];
        NSString *fontName = [general valueForKey:kFontNameKey];
        NSFont *font = [NSFont fontWithName:fontName size:fontSize];
        NSColor *fontColor = [NSColor colorWithHex:[general valueForKey:kFontColorKey]];
        [self.lyricsWindow setFont:font];
        [self.lyricsWindow setTextColor:fontColor];
        [self.lyricsWindow orderFront:self];
    }

    BOOL controlEnabled = [[general valueForKey:kAllowControlKey] boolValue];
    [self connectShortcuts:controlEnabled];
    
    if ([[preferences valueForKey:kVKStatusPolicy] integerValue] != kIgnoreStatusRestoring) {
        [[NSApp delegate] cacheVKStatus];
    }
    
    [self iTunesInfoDidUpdate];
}

#pragma mark
#pragma mark Properties Overload

- (void)setAccountsConfiguration:(NSInteger)accountsConfiguration
{
    _accountsConfiguration = accountsConfiguration;
    if (_accountsConfiguration == kEmptyFlag) {
        [self setTwitter:nil];
    }
    else {
        if (_accountsConfiguration & kTWFlag) {
            if (self.twitter == nil)
                [self setTwitter:[self twitterWrapper]];
        }
        else {
            [self setTwitter:nil];
        }
    }
}

- (NPLyricsWindow*)windowForLyrics
{
    NPLyricsWindow *window = [[NPLyricsWindow alloc] initWithContentRect:NSMakeRect(0, 0, 0, 0) styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
    NSDictionary *general = [[NPPreferencesController preferences] generalSettings];
    CGFloat fontSize = [[general valueForKey:kFontSizeKey] floatValue];
    NSString *fontName = [general valueForKey:kFontNameKey];
    NSFont *font = [NSFont fontWithName:fontName size:fontSize];
    NSColor *fontColor = [NSColor colorWithHex:[general valueForKey:kFontColorKey]];
    [window setFont:font];
    [window setTextColor:fontColor];
    return window;
}

#pragma mark
#pragma mark ---- Status Item && Status Menu ----

- (NSStatusItem*)createStatusItem
{
    NPStatusItemView *view = [[NPStatusItemView alloc] initWithFrame:NSMakeRect(0, 0, 21, 21)];
    [view setTarget:self];
    [view setAction:@selector(leftClickItem:)];
    [view setRightAction:@selector(rightClickItem:)];
    NSImage *image = [[NSImage alloc] initByReferencingFile:[[NSBundle mainBundle] pathForImageResource:@"status_icon"]];
    [view setImage:image];
    
    NSStatusItem *item = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [item setView:view];
    return item;
}

#pragma mark Status Item Actions

- (void)leftClickItem:(id)sender
{
    [self.popover showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMinYEdge];
}

- (void)rightClickItem:(id)sender
{
    if ([(NPStatusItemView*)sender clicked]) {
        [self.statusItem popUpStatusItemMenu:[self statusItemMenu]];
    }
}

- (NSMenu*)statusItemMenu
{
    NSMenu *menu = [[NSMenu alloc] init];
    NSMenuItem *propsItem = [[NSMenuItem alloc] initWithTitle:@"Preferences" action:@selector(showWindow:) keyEquivalent:@""];
    [propsItem setTarget:[NPPreferencesController preferences]];
    [menu addItem:propsItem];
    [menu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *coverScoutItem = [[NSMenuItem alloc] initWithTitle:@"Search current song artwork" action:@selector(searchForCovers) keyEquivalent:@""];
    [coverScoutItem setTarget:self];
    [menu addItem:coverScoutItem];
    [menu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *aboutItem = [[NSMenuItem alloc] init];
    [aboutItem setTitle:@"About..."];
    [aboutItem setTarget:_about];
    [aboutItem setAction:@selector(showWindow:)];
    [menu addItem:aboutItem];
    [menu addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@""];
    return menu;
}

- (void)searchForCovers
{
    if ([self.artworkPopover.track isEqualTo:[[NPiTunesController iTunes] currentTrack]] && [self.artworkPopover.trackArtworks count] > 0) {
        [self.artworkPopover showRelativeToRect:self.statusItem.view.frame  ofView:self.statusItem.view preferredEdge:NSMinYEdge];
    }
    else {
        [self.artworkPopover getArtwork:[[NPiTunesController iTunes] currentTrack] sender:self.statusItem.view lastFMAllowed:YES];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if ([menuItem action] == @selector(searchForCovers)) {
        iTunesTrack *track = [[NPiTunesController iTunes] currentTrack];
        if ([[[track get] className] isEqualToString:@"ITunesURLTrack"]) {
            return NO;
        }
        if ([self.artworkPopover.track isEqualTo:track] && [self.artworkPopover.trackArtworks count] > 0) {
            [menuItem setTitle:@"Show current song artworks"];
        }
        else {
            [menuItem setTitle:@"Search current song artwork"];
        }
    }
    return YES;
}

#pragma mark
#pragma mark ---- iTunes Info Handling ----

- (void)iTunesInfoDidUpdate
{
    iTunesApplication *itunes = [NPiTunesController iTunes];
    if ([itunes isRunning]) {
        iTunesEPlS state = itunes.playerState;
        if (state == iTunesEPlSPaused || state == iTunesEPlSPlaying || state == iTunesEPlSStopped) {
            iTunesTrack *currentTrack = itunes.currentTrack;
            [self updateInfoForTrack:currentTrack state:state];
        }
    }
}

- (NSImage*)artworkFromTrack:(iTunesTrack*)track isDummy:(BOOL*)isDummy
{
    BOOL dummy = YES;
    iTunesArtwork *artwork = [[track artworks] objectAtIndex:0];
    NSImage *image = nil;
    id possibleImage = [artwork data];
    if (possibleImage) {
        if (![possibleImage isKindOfClass:[NSImage class]]) {
            NSAppleEventDescriptor *descriptor = (NSAppleEventDescriptor*)possibleImage;
            image = [[NSImage alloc] initWithData:[descriptor data]];
        }
        else {
            image = possibleImage;
        }
        dummy = NO;
    }
    *isDummy = dummy;
    if (!image) image = [NSImage imageNamed:@"artwork_dummy"];
    return image;
}

#pragma mark
#pragma mark ---- Status Handling ----

- (void)updateInfoForTrack:(iTunesTrack*)track state:(iTunesEPlS)state
{
    BOOL isRadio = [[[track get] className] isEqualToString:@"ITunesURLTrack"];
    NSString *artist = nil;
    NSString *name = nil;
    NSInteger trackID = [track databaseID];
    
    if (isRadio) {
        iTunesApplication *itunes = [NPiTunesController iTunes];
        NSString *description = [itunes currentStreamTitle];
        if (description) {
            NSArray *components = [description componentsSeparatedByString:@" - "];
            if ([components count] == 2) {
                artist = [components objectAtIndex:0];
                name = [components objectAtIndex:1];
            }
            else {
                name = description;
                artist = @"";
            }
        }
        else {
            iTunesURLTrack *urlTrack = [track get];
            artist = @"Online radiostation";
            name = [urlTrack address];
        }
    }
    else {
        artist = track.artist;
        name = track.name;
        if (artist.length == 0) {
            NSArray *components = [name componentsSeparatedByString:@" - "];
            if ([components count] == 2) {
                artist = [components objectAtIndex:0];
                name = [components objectAtIndex:1];
            }
        }
    }
    
    if (!artist && !name && trackID == 0) return;
    
    if (trackID != self.currentTrackID) {
        
        if ([self.artworkPopover isShown]) {
            [self.artworkPopover close];
        }
        [self.artworkPopover setTrack:nil];
        
        [self.popover setArtist:artist];
//        if (!isRadio)
        [self.popover setName:name];
        NSString *tooltip = [artist stringByAppendingFormat:@" - %@", name];
        [self.statusItem.view setToolTip:tooltip];
        
        NPPreferencesController *prefs = [NPPreferencesController preferences];
        // Apply artwork and search, if needed
        BOOL isDummy;
        NSImage *artwork = [self artworkFromTrack:track isDummy:&isDummy];
        [self.popover setArtwork:artwork];
        if (isDummy && prefs.tagArtwork && !isRadio) {
            [self.artworkPopover getArtwork:track sender:self.statusItem.view lastFMAllowed:prefs.allowSearchCoversOnLastFM];
        }
        
        if ([prefs showLyrics] && !isRadio) {
            if (self.lyricsWindow == nil) {
                [self setLyricsWindow:[self windowForLyrics]];
                [self.lyricsWindow orderFront:self];
            }
            NSString *lyrics = track.lyrics;
            if (!lyrics || lyrics.length == 0) {
                lyrics = @"";
                if (prefs.tagLyrics) {
                    NPLyricsTagger *tagger = [[NPLyricsTagger alloc] initWithTrack:track];
                    __weak NPMainHandler *weakSelf = self;
                    
                    [tagger runFromSender:self.statusItem.view completion:^(NSString *lyr, iTunesTrack *taggedTrack){
                        NPMainHandler *stronSelf = weakSelf;
                        iTunesApplication *itunes = [NPiTunesController iTunes];
                        if ([itunes.currentTrack isEqualTo:taggedTrack])
                        [stronSelf.lyricsWindow setText:lyr];
                    }];
                }
            }
            [self.lyricsWindow setText:lyrics];
        }
        [self setCurrentTrackID:trackID];
    }
    
    NSDictionary *info = @{@"artist":artist, @"name":name, @"id":@(trackID), @"state":@(state), @"isRadio":@(isRadio)};
    [self setSocialStatus:info];
}

- (NSString*)statusUpdateArtist:(NSString*)artist title:(NSString*)title
{
    NSString *statusUpdate = nil;
    if (artist.length > 0 && title.length > 0) {
        statusUpdate = [NSString stringWithFormat:@"%@ - %@", artist, title];
    }
    else {
        if (artist.length > 0 && title.length == 0) {
            statusUpdate = artist;
        }
        else {
            statusUpdate = title;
        }
    }
    return statusUpdate;
}

- (void)setSocialStatus:(NSDictionary*)info
{
    if (!info) {
        iTunesApplication *itunes = [NPiTunesController iTunes];
        if ([itunes isRunning]) {
            iTunesEPlS cState = [itunes playerState];
            iTunesTrack *cTrack = [itunes currentTrack];
            if (!cTrack.artist && !cTrack.name && cTrack.databaseID == 0) return;
            info = @{ @"artist":cTrack.artist, @"name":cTrack.name, @"id":@(cTrack.databaseID), @"state":@(cState) };
        }
    }
    
    iTunesEPlS state = [[info valueForKey:@"state"] doubleValue];
    NSUInteger trackID = [[info valueForKey:@"id"] integerValue];
    if (state == iTunesEPlSPaused && [[NPPreferencesController preferences] vkStatusRestorePolicy] == kRestoreOnPause) {
        [[NSApp delegate] restoreVKStatusOnTerminate:NO];
        [self setLastSendedTrackID:NSNotFound];
        _VKOnly = YES;
    }
    BOOL isRadio = [[info valueForKey:@"isRadio"] boolValue];
    if ((state == iTunesEPlSPlaying && trackID != self.lastSendedTrackID) || (state == iTunesEPlSPlaying && isRadio)) {
        NSInteger config = self.accountsConfiguration;
        if (config & kTWFlag && !_VKOnly) {
            [self setTwitterStatus:info];
        }
        else {
            __weak NPMainHandler *weakSelf = self;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NPMainHandler *strongSelf = weakSelf;
                if (!strongSelf) return;
                BOOL vkOnly = strongSelf->_VKOnly;
                if (config & kVKFlag) {
                    [weakSelf setVKFBStatus:info social:kVKFlag sender:weakSelf];
                }
                if (config & kFBFlag && !vkOnly) {
                    [weakSelf setVKFBStatus:info social:kFBFlag sender:weakSelf];
                }
                if (config & kLFFlag && !vkOnly) {
                    if (!isRadio)
                        [weakSelf lastFMScrobble:info];
                }
                if (vkOnly)
                    strongSelf->_VKOnly = NO;
            });
        }
    }
}

- (void)setTwitterStatus:(NSDictionary*)info
{
    NSString *artist = [info valueForKey:@"artist"];
    NSString *name = [info valueForKey:@"name"];
    NSInteger trackID = [[info valueForKey:@"id"] integerValue];
    
    if (!_twitter) return;
    __weak NPMainHandler *weakSelf = self;
    NSString *statusUpdate = [self statusUpdateArtist:artist title:name];
    [_twitter postStatusUpdate:statusUpdate inReplyToStatusID:nil latitude:nil longitude:nil placeID:nil displayCoordinates:@(NO) trimUser:nil successBlock:^(NSDictionary *response){
        [weakSelf setLastSendedTrackID:trackID];
        [[NSApp delegate] setNeedUpdateVKStatus:NO];
    } errorBlock:^(NSError *error) {
        NSLog(@"%@", error);
    }];
}

- (void)setVKFBStatus:(NSDictionary*)info social:(ServiceFlag)social sender:(id)sender
{
    NSString *artist = [info valueForKey:@"artist"];
    NSString *name = [info valueForKey:@"name"];
    
    NSURLRequest *request = nil;
    
    switch (social) {
        case kVKFlag: {
            NSDictionary *vk = [[[NPPreferencesController preferences] accountsSettings] objectForKey:kVKServiceKey];
            NSString *accessToken = [vk valueForKey:kAccessTokenKey];
            NSString *nameF = [name stringUsingEncoding:NSUTF8StringEncoding];
            NSString *artistF = [artist stringUsingEncoding:NSUTF8StringEncoding];
            NSString *stringURL = [NSString stringWithFormat:@"https://api.vk.com/method/execute.postSongStatus?name=%@&artist=%@&access_token=%@", nameF, artistF, accessToken];
            request = [NSURLRequest requestWithURL:[NSURL URLWithString:stringURL]];
            break;
        }
        case kFBFlag: {
            NSDictionary *fb = [[[NPPreferencesController preferences] accountsSettings] objectForKey:kFBServiceKey];
            NSString *accessToken = [fb valueForKeyPath:kAccessTokenKey];
            NSMutableURLRequest *fbrequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/me/feed?access_token=%@", accessToken]]];
            [fbrequest setHTTPMethod:@"POST"];
            NSString *statusUpdate = [self statusUpdateArtist:artist title:name];
            [fbrequest setHTTPBody:[[@"message=" stringByAppendingString:[statusUpdate stringUsingEncoding:NSUTF8StringEncoding]] dataUsingEncoding:NSUTF8StringEncoding]];
            request = fbrequest;
            break;
        }
        case kEmptyFlag:
        case kTWFlag:
        default:break;
    }
    
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:&error];
    if (!error) {
        if (social == kVKFlag) {
            NSArray *items = [[NSJSONSerialization JSONObjectWithData:data options:0 error:&error] valueForKey:@"response"];
            if ([items count] == 0) {
                NSString *accessToken = [[[[NPPreferencesController preferences] accountsSettings] objectForKey:kVKServiceKey] valueForKey:kAccessTokenKey];
                NSString *statusUpdate = [self statusUpdateArtist:artist title:name];
                NSString *text = [[NSString stringWithFormat:@"%@ [ by NowP! app ]", statusUpdate] stringUsingEncoding:NSUTF8StringEncoding];
                NSString *stringURL = [NSString stringWithFormat:@"https://api.vk.com/method/status.set?text=%@&access_token=%@&v=5.0", text, accessToken];
                [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:stringURL]] returningResponse:NULL error:&error];
                [[NSApp delegate] setNeedUpdateVKStatus:NO];
                if (error) return;
            }
        }
        NSInteger trackID = [[info valueForKey:@"id"] integerValue];
        [sender setLastSendedTrackID:trackID];
    }
}

- (void)lastFMScrobble:(NSDictionary*)info
{
    NSString *artist = [info valueForKey:@"artist"];
    NSString *title = [info valueForKey:@"name"];
    NSInteger trackID = [[info valueForKey:@"id"] integerValue];
    NSDictionary *lf = [[[NPPreferencesController preferences] accountsSettings] objectForKey:kLFServiceKey];
    NSString *sk = [lf valueForKey:kLastFMSessionKey];
    BOOL ok = [NPLastFMController scrobbleArtist:artist title:title sessionKey:sk];
    if (ok) {
        [self setLastSendedTrackID:trackID];
    }
}

- (void)artworkConfirmed:(NSImage *)artwork forTrack:(iTunesTrack *)track
{
    iTunesTrack *currentTrack = [[NPiTunesController iTunes] currentTrack];
    if (currentTrack.databaseID == track.databaseID) {
        [self.popover setArtwork:artwork];
    }
}

#pragma mark
#pragma mark ---- Support ----

- (STTwitterAPIWrapper*)twitterWrapper
{
    NSDictionary *tw = [[[NPPreferencesController preferences] accountsSettings] objectForKey:kTWServiceKey];
    if (!tw) return nil;
    NSString *token = [tw valueForKey:kTwitterOAuthToken];
    NSString *secret = [tw valueForKey:kTwitterOAuthTokenSecret];
    NSString *key = [tw valueForKey:kAppIDKey];
    if (token && secret) {
#warning Twitter Secret
        STTwitterAPIWrapper *twitterWrapper = [STTwitterAPIWrapper twitterAPIWithOAuthConsumerName:nil consumerKey:key consumerSecret:@"TWITTER_SECRET" oauthToken:token oauthTokenSecret:secret];
        return twitterWrapper;
    }
    return nil;
}

- (void)connectShortcuts:(BOOL)enabled
{
    if (enabled) {
        [MASShortcut unregisterGlobalShortcutWithUserDefaultsKey:kPlayPauseHotkey];
        [MASShortcut unregisterGlobalShortcutWithUserDefaultsKey:kPrevTrackHotkey];
        [MASShortcut unregisterGlobalShortcutWithUserDefaultsKey:kNextTrackHotkey];
        
        iTunesApplication *itunes = [NPiTunesController iTunes];
        [MASShortcut registerGlobalShortcutWithUserDefaultsKey:kPlayPauseHotkey handler:^{
            [itunes playpause];
        }];
        [MASShortcut registerGlobalShortcutWithUserDefaultsKey:kPrevTrackHotkey handler:^{
            [itunes backTrack];
        }];
        [MASShortcut registerGlobalShortcutWithUserDefaultsKey:kNextTrackHotkey handler:^{
            [itunes nextTrack];
        }];
        [MASShortcut registerGlobalShortcutWithUserDefaultsKey:kVolumeUpHotkey handler:^{
            NSInteger currentVolume = itunes.soundVolume;
            [itunes setSoundVolume:MIN(currentVolume+10, 100)];
        }];
        [MASShortcut registerGlobalShortcutWithUserDefaultsKey:kVolumeDownHotkey handler:^{
            NSInteger currentVolume = itunes.soundVolume;
            [itunes setSoundVolume:MAX(0, currentVolume-10)];
        }];
        [MASShortcut registerGlobalShortcutWithUserDefaultsKey:kMuteHotkey handler:^{
            BOOL isMute = itunes.mute;
            [itunes setMute:!isMute];
        }];
    }
    else {
        [MASShortcut unregisterGlobalShortcutWithUserDefaultsKey:kPlayPauseHotkey];
        [MASShortcut unregisterGlobalShortcutWithUserDefaultsKey:kPrevTrackHotkey];
        [MASShortcut unregisterGlobalShortcutWithUserDefaultsKey:kNextTrackHotkey];
    }
    [self.popover setControlEnabled:enabled];
}

#pragma mark
#pragma mark Memory

- (void)dealloc
{
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self];
}

@end
