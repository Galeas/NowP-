//
//  NPPreferencesController.m
//  NowP!
//
//  Created by Евгений Браницкий on 21.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NPPreferencesController.h"
#import "NSColor+Hex.h"
//#import "Utils.h"
#import "SSKeychain.h"

#import "NPLoginController.h"
#import "STTwitterAPIWrapper.h"
#import "STTwitterHTML.h"
#import "NPLastFMController.h"
#import "OnOffSwitchControlCell.h"

#import "MASShortcutView.h"
#import "MASShortcutView+UserDefaults.h"
#import "MASShortcut+UserDefaults.h"

#import "NPMainHandler.h"
#import "NPiTunesController.h"

#import "NSObject+DeepMutable.h"

#import <objc/runtime.h>

#define FONT_EXAMPLE_TAG 666
#define BUNDLE_SETTINGS_DICTIONARY [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"settings" ofType:@"plist"]]
#define STORAGE [NSUserDefaults standardUserDefaults]

typedef void (^UsernamePasswordBlock_t)(NSString *username, NSString *password);

static NSString *const kAccountNameKey = @"account_name";
static NSString *const kAccountImageKey = @"account_image";
static NSString *const kAppScopeKey = @"scope";

static NSString *const kShortcutDescription = @"description";
static NSString *const kShortcutValue = @"value";

@interface NPPreferencesController () <VKFBLogin, NSTabViewDelegate, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate>
{
    NSMutableDictionary *_general;
    NSMutableDictionary *_accounts;
    NSArray *_shortcuts;
    NPLoginController *_vkfbLoginController;
    NPLastFMController *_lastFMLoginController;
}

@property (nonatomic, copy) UsernamePasswordBlock_t pinGuessLoginCompletionBlock;

@property (assign, nonatomic) BOOL runAtStartup;
@property (assign, nonatomic) BOOL shareTrack;

@property (weak, nonatomic) NSArray *fontList;
@property (weak, nonatomic) NSString *fontName;
@property (weak, nonatomic) NSColor *fontColor;
@property (assign, nonatomic) NSInteger fontSize;
@property (strong, nonatomic) NSFont *fontExample;

@property (weak, nonatomic) NSString *vkUsername;
@property (weak, nonatomic) NSString *fbUsername;
@property (weak, nonatomic) NSString *twUsername;
@property (weak, nonatomic) NSString *lfUsername;
@property (assign, nonatomic) NSFont *usernameFont;

@property (weak) IBOutlet OnOffSwitchControlCell *vkSwitch;
@property (weak) IBOutlet OnOffSwitchControlCell *twSwitch;
@property (weak) IBOutlet OnOffSwitchControlCell *fbSwitch;
@property (weak) IBOutlet OnOffSwitchControlCell *lfSwitch;
@property (weak) IBOutlet NSSegmentedControl *restorePolicyControl;

@property (assign, nonatomic) BOOL settingsSaved;
@property (assign, nonatomic) BOOL needUpdateTrackAnyway;

- (IBAction)resetFont:(id)sender;
- (IBAction)vkAction:(id)sender;
- (IBAction)fbAction:(id)sender;
- (IBAction)twAction:(id)sender;
- (IBAction)lfAction:(id)sender;

@end

@implementation NPPreferencesController

+ (instancetype)preferences
{
    static NPPreferencesController *prefs = nil;
    static dispatch_once_t predicate;
    dispatch_once( &predicate, ^{
        prefs = [[NPPreferencesController alloc] initWithWindowNibName:@"NPPreferencesController"];
    } );
    return prefs;
}

- (id)initWithWindowNibName:(NSString *)windowNibName
{
    self = [super initWithWindowNibName:windowNibName];
    if (self) {
        [self loadSettingsInfo];
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [self validateFontBox:NO];
    [self setupAccountsTab];
}

- (void)showWindow:(id)sender
{
    [super showWindow:sender];
    [self.window orderFrontRegardless];
}

#pragma mark
#pragma mark Properties Overload

- (BOOL)runAtStartup
{
    NSString * appPath = [[NSBundle mainBundle] bundlePath];
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    BOOL inStartup = [self loginItemExistsWithLoginItemReference:loginItems forPath:appPath];
    BOOL settingsValue = [[_general valueForKey:kRunAtStartup] boolValue];
    if (settingsValue != inStartup){
        [_general setValue:@(inStartup) forKey:kRunAtStartup];
    }
    CFRelease(loginItems);
    return inStartup;
}

- (void)setRunAtStartup:(BOOL)runAtStartup
{
    [_general setValue:@(runAtStartup) forKey:kRunAtStartup];
    
    LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
    if (loginItems) {
        NSString *appPath = [[NSBundle mainBundle] bundlePath];
        if (!self.runAtStartup) {
            CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:appPath];
            LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemLast, NULL, NULL, url, NULL, NULL);
            if (item) {
                CFRelease(item);
            }
        }
        else {
            UInt32 seedValue;
            CFURLRef thePath = NULL;
            // We're going to grab the contents of the shared file list (LSSharedFileListItemRef objects)
            // and pop it in an array so we can iterate through it to find our item.
            CFArrayRef loginItemsArray = LSSharedFileListCopySnapshot(loginItems, &seedValue);
            for (unsigned int i = 0; i < CFArrayGetCount(loginItemsArray); i++) {
                LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)CFArrayGetValueAtIndex(loginItemsArray, i);
                if (LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*)&thePath, NULL) == noErr) {
                    if ([[(__bridge NSURL *)thePath path] hasPrefix:appPath]) {
                        LSSharedFileListItemRemove(loginItems, itemRef); // Deleting the item
                    }
                    if (thePath != NULL) CFRelease(thePath);
                }
            }
            if (loginItemsArray != NULL) CFRelease(loginItemsArray);
        }
    }
    if (loginItems != NULL) CFRelease(loginItems);    
    [self setSettingsSaved:NO];
}

#pragma mark

- (void)setShareTrack:(BOOL)shareTrack
{
    [_general setValue:@(shareTrack) forKey:kShouldShareKey];
    [self setSettingsSaved:NO];
}

- (BOOL)shareTrack
{
    return [[_general valueForKey:kShouldShareKey] boolValue];
}

#pragma mark

- (void)setAllowControl:(BOOL)allowControl
{
    [_general setValue:@(allowControl) forKey:kAllowControlKey];
    [self setSettingsSaved:NO];
}

- (BOOL)allowControl
{
    return [[_general valueForKey:kAllowControlKey] boolValue];
}

#pragma mark

- (void)setShowLyrics:(BOOL)showLyrics
{
    [_general setValue:@(showLyrics) forKey:kShouldDisplayLyricsKey];
    [self validateFontBox:NO];
    [self setSettingsSaved:NO];
}

- (BOOL)showLyrics
{
    return [[_general valueForKey:kShouldDisplayLyricsKey] boolValue];
}

#pragma mark

- (NSArray *)fontList
{
    return [[NSFontManager sharedFontManager] availableFontFamilies];
}

#pragma mark

- (NSColor *)fontColor
{
    NSString *hex = [_general valueForKey:kFontColorKey];
    return [NSColor colorWithHex:hex];
}

- (void)setFontColor:(NSColor *)fontColor
{
    NSString *hex = [fontColor hexColor];
    [_general setValue:hex forKey:kFontColorKey];
    [self validateFontBox:YES];
    [self setSettingsSaved:NO];
}

#pragma mark

- (NSInteger)fontSize
{
    return [[_general valueForKey:kFontSizeKey] integerValue];
}

- (void)setFontSize:(NSInteger)fontSize
{
    [_general setValue:@(fontSize) forKey:kFontSizeKey];
    [self setFontExample:[NSFont fontWithName:self.fontName size:fontSize]];
    [self validateFontBox:YES];
    [self setSettingsSaved:NO];
}

#pragma mark

- (NSString *)fontName
{
    return [_general valueForKey:kFontNameKey];
}

- (void)setFontName:(NSString *)fontName
{
    [_general setValue:fontName forKey:kFontNameKey];
    [self setFontExample:[NSFont fontWithName:fontName size:self.fontSize]];
    [self validateFontBox:YES];
    [self setSettingsSaved:NO];
}

#pragma mark

- (NSFont *)usernameFont
{
    return [NSFont fontWithName:@"Lobster" size:22];
}

#pragma mark

- (BOOL)tagLyrics
{
    return [[_general valueForKey:kTagLyricsCurrent] boolValue];
}

- (void)setTagLyrics:(BOOL)tagLyrics
{
    [_general setValue:@(tagLyrics) forKey:kTagLyricsCurrent];
    [self setSettingsSaved:NO];
}

#pragma mark

- (BOOL)tagArtwork
{
    return [[_general valueForKey:kTagArtworkCurrent] boolValue];
}

- (void)setTagArtwork:(BOOL)tagArtwork
{
    [_general setValue:@(tagArtwork) forKey:kTagArtworkCurrent];
    [self setSettingsSaved:NO];
}

#pragma mark

- (VKStatusRestoringPolicy)vkStatusRestorePolicy
{
    return (VKStatusRestoringPolicy)[[_general valueForKey:kVKStatusPolicy] integerValue];
}

- (void)setVkStatusRestorePolicy:(VKStatusRestoringPolicy)vkStatusRestorePolicy
{
    [_general setValue:@(vkStatusRestorePolicy) forKey:kVKStatusPolicy];
    [self setSettingsSaved:NO];
}

#pragma mark

- (BOOL)allowSearchCoversOnLastFM
{
    return [[_general valueForKey:kAllowSearcCoversOnLastFM] boolValue];
}

- (void)setAllowSearchCoversOnLastFM:(BOOL)allowSearchCoversOnLastFM
{
    [_general setValue:@(allowSearchCoversOnLastFM) forKey:kAllowSearcCoversOnLastFM];
    [self setSettingsSaved:NO];
}

#pragma mark

- (void)setSettingsSaved:(BOOL)settingsSaved
{
    _settingsSaved = settingsSaved;
    [self.window setDocumentEdited:!settingsSaved];
}

#pragma mark
#pragma mark Support Methods

- (void)setupAccountsTab
{
    NSInteger flag = [self accountsConfiguration];
    
    if (flag & kVKFlag) {
        [self.vkSwitch setState:NSOnState];
        NSString *name = [_accounts valueForKeyPath:[NSString stringWithFormat:@"%@.%@", kVKServiceKey, kUserScreenName]];
        name ? ([self setVkUsername:name]) : ([self setVkUsername:@""]);
        [self.restorePolicyControl setSelectedSegment:self.vkStatusRestorePolicy];
        [self.restorePolicyControl setEnabled:YES];
    }
    else {
        [self.vkSwitch setState:NSOffState];
        [self setVkUsername:@""];
        [self.restorePolicyControl setSelectedSegment:0];
        [self.restorePolicyControl setEnabled:NO];
    }
    
    if (flag & kFBFlag) {
        [self.fbSwitch setState:NSOnState];
        NSString *name = [_accounts valueForKeyPath:[NSString stringWithFormat:@"%@.%@", kFBServiceKey, kUserScreenName]];
        name ? ([self setFbUsername:name]) : ([self setFbUsername:@""]);
        [self.restorePolicyControl setEnabled:NO];
    }
    else {
        [self.fbSwitch setState:NSOffState];
        [self setFbUsername:@""];
    }
    
    if (flag & kTWFlag) {
        [self.twSwitch setState:NSOnState];
        NSString *name = [_accounts valueForKeyPath:[NSString stringWithFormat:@"%@.%@", kTWServiceKey, kUserScreenName]];
        name ? ([self setTwUsername:name]) : ([self setTwUsername:@""]);
    }
    else {
        [self.twSwitch setState:NSOffState];
        [self setTwUsername:@""];
    }
    
    if (flag & kLFFlag) {
        [self.lfSwitch setState:NSOnState];
        NSString *name = [_accounts valueForKeyPath:[NSString stringWithFormat:@"%@.%@", kLFServiceKey, kUserScreenName]];
        name ? ([self setLfUsername:name]) : ([self setLfUsername:@""]);
    }
    else {
        [self.lfSwitch setState:NSOffState];
        [self setLfUsername:@""];
    }
}

- (BOOL)loginItemExistsWithLoginItemReference:(LSSharedFileListRef)theLoginItemsRefs forPath:(NSString *)appPath {
	BOOL found = NO;
	UInt32 seedValue;
	CFURLRef thePath = NULL;
    
	// We're going to grab the contents of the shared file list (LSSharedFileListItemRef objects)
	// and pop it in an array so we can iterate through it to find our item.
	CFArrayRef loginItemsArray = LSSharedFileListCopySnapshot(theLoginItemsRefs, &seedValue);
    for (unsigned int i = 0; i < CFArrayGetCount(loginItemsArray); i++) {
        LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)CFArrayGetValueAtIndex(loginItemsArray, i);
        if (LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*)&thePath, NULL) == noErr) {
            if ([[(__bridge NSURL *)thePath path] hasPrefix:appPath]) {
				found = YES;
                CFRelease(thePath);
				break;
			}
            if (thePath != NULL) CFRelease(thePath);
        }
    }
	if (loginItemsArray != NULL) CFRelease(loginItemsArray);
	return found;
}

- (void)validateFontBox:(BOOL)buttonOnly
{
    int startTag;
    buttonOnly ? (startTag = 205) : (startTag = 201);
    for (int i = startTag; i < 206; i++) {
        NSControl *control = [[self.window contentView] viewWithTag:i];
        if (i < 205) {
            [control setEnabled:self.showLyrics];
        }
        else {
            NSDictionary *defaultsGeneral = [BUNDLE_SETTINGS_DICTIONARY objectForKey:kGeneralKey];
            NSString *fName = [defaultsGeneral valueForKey:kFontNameKey];
            NSInteger fSize = [[defaultsGeneral valueForKey:kFontSizeKey] integerValue];
            NSString *fColor = [defaultsGeneral valueForKey:kFontColorKey];
            
            BOOL sameFont = [fName isEqualToString:self.fontName] && [fColor isEqualToString:[self.fontColor hexColor]] && (fSize == self.fontSize);
            self.showLyrics ? ([control setEnabled:!sameFont]) : ([control setEnabled:NO]);
        }
    }
}

- (void)askForUsernameAndPasswordWithCompletionBlock:(UsernamePasswordBlock_t)completionBlock {
    
    [self setPinGuessLoginCompletionBlock:completionBlock];
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Login"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setMessageText:@"Please enter username and password"];
    [alert setInformativeText:@"NowP! will login on Twitter through the website and parse the HTML to guess the PIN."];
    [alert setAlertStyle:NSInformationalAlertStyle];
    
    NSTextField *usernameTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(0,32, 180, 24)];
    NSSecureTextField *passwordTextField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 180, 24)];
    
    NSView *accessoryView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 64)];
    [accessoryView addSubview:usernameTextField];
    [accessoryView addSubview:passwordTextField];
    
    [alert setAccessoryView:accessoryView];
    
    [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(twAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)loginSheetDidEnd:(NSWindow *)sheet withCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [sheet.windowController close];
    _vkfbLoginController = nil;
}

- (void)twAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(NSDictionary *)contextInfo
{
    if(returnCode != NSAlertFirstButtonReturn) {
        [self.twSwitch setState:NSOffState];
        return;
    }
    
    NSArray *subviews = [alert.accessoryView subviews];
    
    NSTextField *usernameTextField = [subviews objectAtIndex:0];
    NSSecureTextField *passwordTextField = [subviews objectAtIndex:1];
    
    NSString *username = [usernameTextField stringValue];
    NSString *password = [passwordTextField stringValue];
    
    self.pinGuessLoginCompletionBlock(username, password);
}

- (void)closeAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(NSDictionary *)contextInfo
{
    if (returnCode == NSAlertFirstButtonReturn) {
        NSButton *check = [[[alert accessoryView] subviews] objectAtIndex:0];
        BOOL checked = [check state] == NSOnState;
        [_general setValue:@(!checked) forKey:kAskWhenPrefsClose];
        [self saveSettings:self];
    }
    else {
        [self loadSettingsInfo];
        [self setupAccountsTab];      
    }
    [self.window close];
}

#pragma mark
#pragma mark Settings Load/Save

- (void)loadSettingsInfo
{
    [self prepareToChangeSettings];
    self->_general = [[self getGeneralInfo] deepMutableCopy];
    self->_accounts = [[self getAccountsInfo] deepMutableCopy];
    self->_shortcuts = @[kNextTrackHotkey, kPrevTrackHotkey, kPlayPauseHotkey, kVolumeDownHotkey, kVolumeUpHotkey, kMuteHotkey];
    [self setSettingsSaved:YES];
    [self notifySettingsDidChaged];
}

- (NSDictionary*)getAccountsInfo
{
    NSError *error = nil;
    NSString *service = [[NSBundle mainBundle] bundleIdentifier];
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    validateAccountsSettings();
    
    NSData *vkData = [SSKeychain passwordDataForService:service account:kVKServiceKey error:&error];
    if (vkData && !error) {
        NSDictionary *vkDict = [NSUnarchiver unarchiveObjectWithData:vkData];
        [result setObject:vkDict forKey:kVKServiceKey];
    }
    error = nil;
    
    NSData *fbData = [SSKeychain passwordDataForService:service account:kFBServiceKey error:&error];
    if (fbData && !error) {
        NSDictionary *fbDict = [NSUnarchiver unarchiveObjectWithData:fbData];
        [result setObject:fbDict forKey:kFBServiceKey];
    }
    error = nil;
    
    NSData *twData = [SSKeychain passwordDataForService:service account:kTWServiceKey error:&error];
    if (twData && !error) {
        NSDictionary *twDict = [NSUnarchiver unarchiveObjectWithData:twData];
        [result setObject:twDict forKey:kTWServiceKey];
    }
    error = nil;
    
    NSData *lfData = [SSKeychain passwordDataForService:service account:kLFServiceKey error:&error];
    if (lfData && !error) {
        NSDictionary *lfDict = [NSUnarchiver unarchiveObjectWithData:lfData];
        [result setObject:lfDict forKey:kLFServiceKey];
    }
    
    return result;
}

- (NSDictionary*)getGeneralInfo
{
    validateGeneralSettings();
    return [STORAGE objectForKey:kAppDefaultsKey];
}

- (void)prepareToChangeSettings
{
    unsigned int count;
    objc_property_t *propertyList = class_copyPropertyList([self class], &count);
    NSMutableArray *keys = [NSMutableArray arrayWithCapacity:count];
    for (unsigned int i = 0; i < count; i++) {
        objc_property_t property = propertyList[i];
        NSString *name = [NSString stringWithUTF8String:property_getName(property)];
        if (name && name.length > 0) {
            [keys addObject:name];
        }
    }
    free(propertyList);
    
    for (NSString *key in keys) {
        [self willChangeValueForKey:key];
    }
}

- (void)notifySettingsDidChaged
{
    unsigned int count;
    objc_property_t *propertyList = class_copyPropertyList([self class], &count);
    NSMutableArray *keys = [NSMutableArray arrayWithCapacity:count];
    for (unsigned int i = 0; i < count; i++) {
        objc_property_t property = propertyList[i];
        NSString *name = [NSString stringWithUTF8String:property_getName(property)];
        if (name && name.length > 0) {
            [keys addObject:name];
        }
    }
    free(propertyList);
    
    for (NSString *key in keys) {
        [self didChangeValueForKey:key];
    }
}

#pragma mark
#pragma mark VKFBLogin Delegate

- (void)getToken:(NSString *)token userID:(NSInteger)uid service:(ServiceFlag)service
{
    if (token) {
        [NSApp endSheet:[_vkfbLoginController window] returnCode:NSOKButton];
        NSString *serviceName = [[NSBundle mainBundle] bundleIdentifier];
        switch (service) {
            case kVKFlag: {
                NSMutableDictionary *vk = [_accounts objectForKey:kVKServiceKey];
                [vk setObject:token forKey:kAccessTokenKey];
                [vk setObject:@(uid) forKey:kUserIDKey];
                NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://api.vk.com/method/users.get?user_ids=%@&fields=screen_name&v=5.0", @(uid)]]];
                __weak NPPreferencesController *weakSelf = self;
                [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue currentQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error){
                    if (error) return;
                    NSError *err = nil;
                    NPPreferencesController *strongSelf = weakSelf;
                    if (!strongSelf) return;
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
                    if (!err && ![json valueForKey:@"error"]) {
                        NSString *screenName = [[[json objectForKey:@"response"] objectAtIndex:0] valueForKey:@"screen_name"];
                        if (screenName != nil) {
                            [vk setValue:screenName forKey:kUserScreenName];
                            BOOL deleteOK = [SSKeychain deleteEntryForService:serviceName account:kVKServiceKey];
                            BOOL saveOK = [SSKeychain setPasswordData:[NSArchiver archivedDataWithRootObject:vk] forService:serviceName account:kVKServiceKey error:&err];
#pragma unused (saveOK, deleteOK)
                            [strongSelf setVkUsername:screenName];
                            [weakSelf.restorePolicyControl setEnabled:YES];
                            [[NPMainHandler handler] setAccountsConfiguration:[strongSelf accountsConfiguration]];
                        }
                    }
                }];
                break;
            }
            case kFBFlag: {
                NSMutableDictionary *fb = [_accounts objectForKey:kFBServiceKey];
                NSNumber *uid = nil;
                NSError *error = nil;
                NSData *validationData = [NSData dataWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/debug_token?input_token=%@&access_token=%@", token, token]]];
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:validationData options:0 error:&error];
                if (!error && [[dict allKeys] containsObject:@"data"]) {
                    if ([[dict valueForKeyPath:@"data.is_valid"] boolValue]) {
                        uid = [dict valueForKeyPath:@"data.user_id"];
                    }
                }
                if (uid) {
                    [fb setObject:token forKey:kAccessTokenKey];
                    [fb setObject:uid forKey:kUserIDKey];
                    [fb setObject:[NSDate dateWithTimeIntervalSince1970:[[dict valueForKeyPath:@"data.expires_at"] doubleValue]] forKey:kTokenExpiresAt];
                    __weak NPPreferencesController *weakSelf = self;
                    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/%@?fields=username", uid]]] queue:[NSOperationQueue currentQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error){
                        if (error) return;
                        NSError *err = nil;
                        NPPreferencesController *strongSelf = weakSelf;
                        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
                        NSString *username = [json valueForKey:@"username"];
                        if (username != nil) {
                            [fb setValue:username forKey:kUserScreenName];
                            [strongSelf setFbUsername:username];
                            BOOL deleteOK = [SSKeychain deleteEntryForService:serviceName account:kFBServiceKey];
                            BOOL saveOK = [SSKeychain setPasswordData:[NSArchiver archivedDataWithRootObject:fb] forService:serviceName account:kFBServiceKey error:&err];
#pragma unused (saveOK, deleteOK)
                            [[NPMainHandler handler] setAccountsConfiguration:[strongSelf accountsConfiguration]];
                        }
                    }];
                }
                break;
            }
            case kTWFlag:
            case kEmptyFlag:
            default:break;
        }
        [self setNeedUpdateTrackAnyway:YES];
    }
    else {
        switch (service) {
            case kVKFlag: {
                [self.vkSwitch setState:NSOffState];
                break;
            }
            case kFBFlag: {
                [self.fbSwitch setState:NSOffState];
                break;
            }
            case kTWFlag:
            case kEmptyFlag:
            default:break;
        }
        [NSApp endSheet:[_vkfbLoginController window] returnCode:NSCancelButton];
    }
}

#pragma mark
#pragma mark TabView Delegate

- (BOOL)tabView:(NSTabView *)tabView shouldSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    if ([[tabViewItem identifier] isEqualToString:@"2"] && !self.shareTrack) {
        return NO;
    }
    if ([[tabViewItem identifier] isEqualToString:@"3"] && !self.allowControl) {
        return NO;
    }
    return YES;
}

#pragma mark
#pragma mark WindowDelegate

- (BOOL)windowShouldClose:(id)sender
{
    BOOL ask = [[_general valueForKey:kAskWhenPrefsClose] boolValue];
    if (ask && !self.settingsSaved) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Yes"];
        [alert addButtonWithTitle:@"No"];
        [alert setAlertStyle:NSInformationalAlertStyle];
        
        [alert setMessageText:@"Do you want to apply changes?"];
        [alert setInformativeText:@"You can select checkbox and press \"Yes\" for never ask again and apply changes by default"];
        NSButton *check = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, 150, 18)];
        [check setAllowsMixedState:NO];
        [check setButtonType:NSSwitchButton];
        [check setBezelStyle:NSRoundedBezelStyle];
        [check setTitle:@"Never ask again"];
        
        NSView *accessoryView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 150, 20)];
        [accessoryView addSubview:check];
        [alert setAccessoryView:accessoryView];
        
        [alert beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:@selector(closeAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
        return NO;
    }
    else if (self.needUpdateTrackAnyway) {
        [self setNeedUpdateTrackAnyway:NO];
        [[NPMainHandler handler] iTunesInfoDidUpdate];
    }
    return YES;
}

#pragma mark
#pragma mark TableView Delegate && DataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [_shortcuts count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    NSView *view = nil;
    NSString *key = [_shortcuts objectAtIndex:row];
    
    if ([[tableColumn identifier] isEqualToString:kShortcutDescription]) {
        NSTableCellView *cellView = [tableView makeViewWithIdentifier:kShortcutDescription owner:self];
        [cellView.textField setStringValue:keyTransformerForShortcut(key)];
        view = cellView;
    }
    else if ([[tableColumn identifier] isEqualToString:kShortcutValue]) {
        MASShortcutView *shortcutView = [tableView makeViewWithIdentifier:kShortcutValue owner:self];
        [shortcutView setAssociatedUserDefaultsKey:key];
        __weak NPPreferencesController *weakSelf = self;
        [shortcutView setShortcutValueChange:^(MASShortcutView *sender){
            [weakSelf setSettingsSaved:NO];
        }];
        view = shortcutView;
    }
    return view;
}

NSString* keyTransformerForShortcut(NSString *key)
{
    if ([key isEqualToString:kPrevTrackHotkey]) {
        return @"Previous Track";
    }
    if ([key isEqualToString:kPlayPauseHotkey]) {
        return @"Play / Pause";
    }
    if ([key isEqualToString:kNextTrackHotkey]) {
        return @"Next Track";
    }
    if ([key isEqualToString:kVolumeUpHotkey]) {
        return @"Volume Up";
    }
    if ([key isEqualToString:kVolumeDownHotkey]) {
        return @"Volume Down";
    }
    if ([key isEqualToString:kMuteHotkey]) {
        return @"Mute";
    }
    return nil;
}

#pragma mark
#pragma mark Public Methods

- (NSDictionary *)accountsSettings
{
    return [NSDictionary dictionaryWithDictionary:_accounts];
}

- (NSDictionary *)generalSettings
{
    return [NSDictionary dictionaryWithDictionary:_general];
}

- (NSInteger)accountsConfiguration
{
    if ([_accounts count] == 0) {
        return kEmptyFlag;
    }
    
    NSInteger currentFlag = kEmptyFlag;
    
    for (NSString *key in _accounts) {
        NSDictionary *settings = [_accounts objectForKey:key];
        if ([key isEqualToString:kVKServiceKey]) {
            if ([settings valueForKey:kAccessTokenKey] != nil && self.shareTrack) {
                currentFlag |= kVKFlag;
            }
        }
        if ([key isEqualToString:kFBServiceKey]) {
            if ([settings valueForKey:kAccessTokenKey] != nil && self.shareTrack) {
                currentFlag |= kFBFlag;
            }
        }
        if ([key isEqualToString:kTWServiceKey]) {
            if (([settings valueForKey:kTwitterOAuthToken] != nil) && ([settings valueForKey:kTwitterOAuthTokenSecret] != nil) && self.shareTrack) {
                currentFlag |= kTWFlag;
            }
        }
        if ([key isEqualToString:kLFServiceKey]) {
            if ([settings valueForKey:kLastFMSessionKey] != nil && self.shareTrack) {
                currentFlag |= kLFFlag;
            }
        }
    }
    return currentFlag;
}

- (IBAction)defaultSettings:(id)sender
{
    [self.vkSwitch setState:NSOffState];
    [self setVkUsername:@""];
    [self.restorePolicyControl setEnabled:NO];
    [self.fbSwitch setState:NSOffState];
    [self setFbUsername:@""];
    [self.twSwitch setState:NSOffState];
    [self setTwUsername:@""];
    [self.lfSwitch setState:NSOffState];
    [self setLfUsername:@""];
    
    NSDictionary *bundleDict = BUNDLE_SETTINGS_DICTIONARY;
    [self prepareToChangeSettings];
    _general = [[bundleDict objectForKey:kGeneralKey] deepMutableCopy];
    _accounts = [[bundleDict objectForKey:kAccountsKey] deepMutableCopy];
    [self notifySettingsDidChaged];
    
    [self setSettingsSaved:NO];
}

- (IBAction)saveSettings:(id)sender
{
    saveGeneralSettings(_general);    
    if (self.delegate) {
        [self.delegate preferencesDidSaved:_general];
    }
    [self setSettingsSaved:YES];
}

#pragma mark
#pragma mark IBActions

- (IBAction)resetFont:(id)sender
{
    NSDictionary *defaultsGeneral = [BUNDLE_SETTINGS_DICTIONARY objectForKey:kGeneralKey];
    NSString *fName = [defaultsGeneral valueForKey:kFontNameKey];
    NSInteger fSize = [[defaultsGeneral valueForKey:kFontSizeKey] integerValue];
    NSColor *fColor = [NSColor colorWithHex:[defaultsGeneral valueForKey:kFontColorKey]];
    [self setFontName:fName];
    [self setFontSize:fSize];
    [self setFontColor:fColor];
}

- (IBAction)vkAction:(id)sender
{
    NSMutableDictionary *vk = [_accounts objectForKey:kVKServiceKey];
    NSString *appID = [vk valueForKey:kAppIDKey];
    if ([sender state] == NSOnState) {
        NSString *scope = [vk valueForKey:kAppScopeKey];
        if (!_vkfbLoginController) {
            _vkfbLoginController = [[NPLoginController alloc] initWithWindowNibName:@"NPLoginController"];
            [_vkfbLoginController setDelegate:self];
        }
        NSString *loginURLString = [NSString stringWithFormat:@"https://oauth.vk.com/authorize?client_id=%@&scope=%@&redirect_uri=http://oauth.vk.com/blank.html&display=mobile&response_type=token", appID, scope];
        [_vkfbLoginController setLoginURL:[NSURL URLWithString:loginURLString]];
        [NSApp beginSheet:[_vkfbLoginController window] modalForWindow:self.window modalDelegate:self didEndSelector:@selector(loginSheetDidEnd:withCode:contextInfo:) contextInfo:NULL];
    }
    else {
        NSString *logoutURLString = [NSString stringWithFormat:@"https://api.vk.com/oauth/logout?client_id=%@", appID];
        NSError *error = nil;
        NSURLResponse *response = nil;
        [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:logoutURLString]] returningResponse:&response error:&error];
        if (!error) {
            [vk removeObjectsForKeys:@[kAccessTokenKey, kUserScreenName, kUserIDKey]];
            [self setVkUsername:@""];
            BOOL deleteOk = [SSKeychain deleteEntryForService:[[NSBundle mainBundle] bundleIdentifier] account:kVKServiceKey];
            BOOL writeOk = [SSKeychain setPasswordData:[NSArchiver archivedDataWithRootObject:vk] forService:[[NSBundle mainBundle] bundleIdentifier] account:kVKServiceKey];
#pragma unused (deleteOk, writeOk)
            [self.restorePolicyControl setEnabled:NO];
            [self setNeedUpdateTrackAnyway:YES];
            [[NPMainHandler handler] setAccountsConfiguration:[self accountsConfiguration]];
        }
    }
}

- (IBAction)fbAction:(id)sender
{
    NSMutableDictionary *fb = [_accounts objectForKey:kFBServiceKey];
    if ([sender state] == NSOnState) {
        NSString *appID = [fb valueForKey:kAppIDKey];
        NSString *scope = [fb valueForKey:kAppScopeKey];
        
        if (!_vkfbLoginController) {
            _vkfbLoginController = [[NPLoginController alloc] initWithWindowNibName:@"NPLoginController"];
            [_vkfbLoginController setDelegate:self];
        }
        
        NSString *loginURLString = [NSString stringWithFormat:@"https://www.facebook.com/dialog/oauth?client_id=%@&redirect_uri=https://www.facebook.com/connect/login_success.html&response_type=token&scope=%@&display=touch", appID, scope];
        [_vkfbLoginController setLoginURL:[NSURL URLWithString:loginURLString]];
        [NSApp beginSheet:[_vkfbLoginController window] modalForWindow:self.window modalDelegate:self didEndSelector:@selector(loginSheetDidEnd:withCode:contextInfo:) contextInfo:NULL];
    }
    else {
        id uid = [fb valueForKeyPath:kUserIDKey];
        NSString *token = [fb valueForKey:kAccessTokenKey];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/%@/permissions?access_token=%@", uid,token]]];
        [request setHTTPMethod:@"DELETE"];
        NSError *error = nil;
        [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:&error];
        if (!error) {
            [fb removeObjectsForKeys:@[kAccessTokenKey, kUserIDKey, kTokenExpiresAt, kUserScreenName]];
            [self setFbUsername:@""];
            BOOL deleteOk = [SSKeychain deleteEntryForService:[[NSBundle mainBundle] bundleIdentifier] account:kFBServiceKey];
            BOOL writeOk = [SSKeychain setPasswordData:[NSArchiver archivedDataWithRootObject:fb] forService:[[NSBundle mainBundle] bundleIdentifier] account:kFBServiceKey];
#pragma unused (deleteOk, writeOk)
            [self setNeedUpdateTrackAnyway:YES];
            [[NPMainHandler handler] setAccountsConfiguration:[self accountsConfiguration]];
        }
    }
}

- (IBAction)twAction:(id)sender
{
    NSMutableDictionary *tw = [_accounts objectForKey:kTWServiceKey];
    NSString *serviceName = [[NSBundle mainBundle] bundleIdentifier];
    
    if ([sender state] == NSOnState) {
        NSString *appID = [tw valueForKey:kAppIDKey];
#warning Twitter Secret
        STTwitterAPIWrapper *twitter = [STTwitterAPIWrapper twitterAPIWithOAuthConsumerName:nil consumerKey:appID consumerSecret:@"TWITTER_SECRET"];
        STTwitterHTML *twitterHTML = [[STTwitterHTML alloc] init];
        __weak NPPreferencesController *weakSelf = self;
        [twitter postTokenRequest:^(NSURL *url, NSString *oauthToken){
            [twitterHTML getLoginForm:^(NSString *authToken){
                [weakSelf askForUsernameAndPasswordWithCompletionBlock:^(NSString *username, NSString *pass){
                    [twitterHTML postLoginFormWithUsername:username password:pass authenticityToken:authToken successBlock:^{
                        [twitterHTML getAuthorizeFormAtURL:url successBlock:^(NSString *newAuthenticityToken, NSString *newOAuthToken){
                            [twitterHTML postAuthorizeFormResultsAtURL:url authenticityToken:newAuthenticityToken oauthToken:newAuthenticityToken successBlock:^(NSString *PIN){
                                [twitter postAccessTokenRequestWithPIN:PIN successBlock:^(NSString *oauthToken, NSString *oauthTokenSecret, NSString *userID, NSString *screenName){
                                    NPPreferencesController *strongSelf = weakSelf;
                                    if (strongSelf) {
                                        NSMutableDictionary *settings = strongSelf -> _accounts;
                                        NSMutableDictionary *tw = [settings objectForKey:kTWServiceKey];
                                        [tw setValue:oauthToken forKey:kTwitterOAuthToken];
                                        [tw setValue:oauthTokenSecret forKey:kTwitterOAuthTokenSecret];
                                        [tw setValue:userID forKey:kUserIDKey];
                                        [tw setValue:screenName forKey:kUserScreenName];
                                        [strongSelf setTwUsername:screenName];
                                        BOOL deleteOk = [SSKeychain deleteEntryForService:serviceName account:kTWServiceKey];
                                        BOOL writeOk = [SSKeychain setPasswordData:[NSArchiver archivedDataWithRootObject:tw] forService:serviceName account:kTWServiceKey];
#pragma unused (deleteOk, writeOk)
                                        [self setNeedUpdateTrackAnyway:YES];
                                        [[NPMainHandler handler] setAccountsConfiguration:[strongSelf accountsConfiguration]];
                                    }
                                    [tw setValue:userID forKey:kUserIDKey];
                                    
                                } errorBlock:^(NSError *err4){
                                    NSLog(@"%@", [err4 description]);
                                }];
                            } errorBlock:^(NSError *err3) {
                                NSLog(@"%@", [err3 description]);
                            }];
                        } errorBlock:^(NSError *err2){
                            NSLog(@"%@", [err2 description]);
                        }];
                    } errorBlock:^(NSError *err1){
                        NSLog(@"%@", [err1 description]);
                    }];
                }];
            } errorBlock:^(NSError *err){
                NSLog(@"%@", [err description]);
            }];
        } oauthCallback:nil errorBlock:^(NSError *error){
            NSLog(@"%@", [error description]);
        }];
    }
    
    else {
        [tw removeObjectsForKeys:@[kTwitterOAuthToken, kTwitterOAuthTokenSecret, kUserIDKey, kUserScreenName]];
        [self setTwUsername:@""];
        BOOL deleteOk = [SSKeychain deleteEntryForService:serviceName account:kTWServiceKey];
        BOOL writeOk = [SSKeychain setPasswordData:[NSArchiver archivedDataWithRootObject:tw] forService:serviceName account:kTWServiceKey];
#pragma unused (deleteOk, writeOk)
        [self setNeedUpdateTrackAnyway:YES];
        [[NPMainHandler handler] setAccountsConfiguration:[self accountsConfiguration]];
    }
}

- (IBAction)lfAction:(id)sender
{
    NSMutableDictionary *lf = [_accounts objectForKey:kLFServiceKey];
    NSString *serviceName = [[NSBundle mainBundle] bundleIdentifier];
    if ([sender state] == NSOnState) {
        if (!_lastFMLoginController) {
            _lastFMLoginController = [[NPLastFMController alloc] init];
        }
        __weak NPPreferencesController *weakSelf = self;
        [_lastFMLoginController loginModalForWindow:[self window] completion:^(NSDictionary *response, NSError *error){
            if (response && !error) {
                [lf setValue:[response valueForKey:@"name"] forKey:kUserScreenName];
                [lf setValue:[response valueForKey:@"key"] forKey:kLastFMSessionKey];
                [weakSelf setLfUsername:[response valueForKey:@"name"]];
            }
            else {
                [lf removeObjectsForKeys:@[kUserScreenName, kLastFMSessionKey]];
                [weakSelf setLfUsername:@""];
                [sender setState:NSOffState];
            }
            BOOL deleteOk = [SSKeychain deleteEntryForService:serviceName account:kLFServiceKey];
            BOOL writeOk = [SSKeychain setPasswordData:[NSArchiver archivedDataWithRootObject:lf] forService:serviceName account:kLFServiceKey];
#pragma unused (deleteOk, writeOk)
            [self setNeedUpdateTrackAnyway:YES];
            [[NPMainHandler handler] setAccountsConfiguration:[weakSelf accountsConfiguration]];
        }];
    }
    else {
        [lf removeObjectsForKeys:@[kUserScreenName, kLastFMSessionKey]];
        [self setLfUsername:@""];
        [sender setState:NSOffState];
        BOOL deleteOk = [SSKeychain deleteEntryForService:serviceName account:kLFServiceKey];
        BOOL writeOk = [SSKeychain setPasswordData:[NSArchiver archivedDataWithRootObject:lf] forService:serviceName account:kLFServiceKey];
#pragma unused (deleteOk, writeOk)
        [self setNeedUpdateTrackAnyway:YES];
        [[NPMainHandler handler] setAccountsConfiguration:[self accountsConfiguration]];
    }
}

#pragma mark
#pragma mark Functions

void validateAccountsSettings()
{
    NSString *service = [[NSBundle mainBundle] bundleIdentifier];
    NSArray *storedAccounts = [SSKeychain accountsForService:service];
    NSDictionary *accounts = [BUNDLE_SETTINGS_DICTIONARY objectForKey:kAccountsKey];
    if ([storedAccounts count] != [accounts count]) {
        for (NSString *key in accounts) {
            NSPredicate *searchPredicate = [NSPredicate predicateWithFormat:@"acct LIKE %@", key];
            NSArray *filtered = [storedAccounts filteredArrayUsingPredicate:searchPredicate];
            if ([filtered count] == 0) {
                NSDictionary *account = [accounts objectForKey:key];
                BOOL saveOK = [SSKeychain setPasswordData:[NSArchiver archivedDataWithRootObject:account] forService:service account:key];
#pragma unused (saveOK)
            }
        }
    }
}

void validateGeneralSettings()
{
    NSUserDefaults *storage = STORAGE;
    NSDictionary *general = [storage objectForKey:kAppDefaultsKey];
    if (general == nil) {
        general = [BUNDLE_SETTINGS_DICTIONARY objectForKey:kGeneralKey];;
        [storage setObject:general forKey:kAppDefaultsKey];
        [storage synchronize];
    }
}

void saveGeneralSettings(NSDictionary *settings)
{
    NSUserDefaults *storage = STORAGE;
    [storage removeObjectForKey:kAppDefaultsKey];
    [storage setObject:[NSDictionary dictionaryWithDictionary:settings] forKey:kAppDefaultsKey];
    [storage synchronize];
}

#pragma mark
#pragma mark Memory

- (void)dealloc
{
    [self setDelegate:nil];
}

@end
