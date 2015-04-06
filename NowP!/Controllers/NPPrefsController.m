//
//  NPPrefsController.m
//  NowP!
//
//  Created by Yevgeniy Kratko on 27.08.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import "NPPrefsController.h"
#import "NPAppearance.h"
#import "NSString+Extra.h"
#import "NSObject+DeepMutable.h"
#import "NPLoginController.h"

#import <EDSideBar.h>
#import <QuartzCore/QuartzCore.h>
#import <Accounts/Accounts.h>
#import <STTwitter/STTwitter.h>

#define kTWConsumerSecret @"Zlh7ur0Kx7AjvsrbYiXRs8QCagWH7iPNYRbgKMEqHQo"

typedef NS_ENUM(NSUInteger, NPAccountType) {
    NPAccountVK = 1001,
    NPAccountFB = 1002,
    NPAccountTW = 1003,
    NPAccountLF = 1004
};

@interface NPPrefsController () <NSTabViewDelegate, NSTableViewDelegate, NSPopoverDelegate, VKFBLogin, TWLogin, NSAlertDelegate, LFLogin, EDSideBarDelegate>
@property (weak) IBOutlet NSArrayController *appearanceAC;
@property (weak) IBOutlet NSPopover *loginPopover;

@property (weak) IBOutlet EDSideBar *sidebar;
@property (weak) IBOutlet NSTabView *tabView;
@property (weak) IBOutlet NSTextField *fontPreview;
@property (weak) IBOutlet NSColorWell *fontColorWell;
@property (weak) IBOutlet NSTableView *appearanceTable;
@property (weak) IBOutlet NSColorWell *fontbackColorWell;
@property (weak) IBOutlet NSSegmentedControl *alignmentControl;

@property (weak) IBOutlet NSLayoutConstraint *tableHeight;

@property (strong, nonatomic) NSArray *appearances;

//@property (strong, nonatomic) NSMutableDictionary *preferences;

@property (strong, nonatomic) ACAccountStore *accountsStore;
@property (strong, nonatomic) STTwitterAPI *twitter;
@property (strong, nonatomic) NSArray *osxTwitterAccounts;
@property (strong, nonatomic) ACAccount *selectedTWAccount;
@property (strong, nonatomic) ACAccount *selectedFBAccount;
@property (strong, nonatomic) NSArray *osxFacebookAccounts;
@property (assign, nonatomic) Service currentService;

@property (nonatomic, copy) void (^fbRenewBlock)(BOOL success);

- (IBAction)changeAlignment:(id)sender;
- (IBAction)changeForegroundColor:(id)sender;
- (IBAction)changeBackgroundColor:(id)sender;
- (IBAction)revertToDefaults:(id)sender;
- (IBAction)vkAction:(id)sender;
- (IBAction)fbAction:(id)sender;
- (IBAction)twAction:(id)sender;
- (IBAction)lfAction:(id)sender;
- (IBAction)switchLyricsTagging:(id)sender;
- (IBAction)switchArtworkTagging:(id)sender;
@end

@implementation NPPrefsController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    return self;
}

-(NSImage*)buildSelectionImage
{
    // Create the selection image on the fly, instead of loading from a file resource.
    NSInteger imageWidth=12, imageHeight=22;
    NSImage* destImage = [[NSImage alloc] initWithSize:NSMakeSize(imageWidth,imageHeight)];
    [destImage lockFocus];
    
    // Constructing the path
    NSBezierPath *triangle = [NSBezierPath bezierPath];
    [triangle setLineWidth:1.0];
    [triangle moveToPoint:NSMakePoint(imageWidth+1, 0.0)];
    [triangle lineToPoint:NSMakePoint( 0, imageHeight/2.0)];
    [triangle lineToPoint:NSMakePoint( imageWidth+1, imageHeight)];
    [triangle closePath];
    [[NSColor controlColor] setFill];
    [[NSColor colorWithCalibratedWhite:.2 alpha:1] setStroke];
    [triangle fill];
    [triangle stroke];
    [destImage unlockFocus];
    return destImage;
}

- (void)awakeFromNib
{
    __weak typeof(self) weakSelf = self;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [weakSelf readPreferences];
        
        [[NSFontManager sharedFontManager] setDelegate:weakSelf];
        [[NSFontManager sharedFontManager] setTarget:weakSelf];
        
        [weakSelf.sidebar addButtonWithTitle:@"Appearance" image:[NSImage imageNamed:@"appearanceIcon"]];
        [weakSelf.sidebar addButtonWithTitle:@"Tagging" image:[NSImage imageNamed:@"tagIcon"]];
        [weakSelf.sidebar addButtonWithTitle:@"Accounts" image:[NSImage imageNamed:@"profilesIcon"]];
        [weakSelf.sidebar setLayoutMode:ECSideBarLayoutTop];
        [weakSelf.sidebar setSidebarDelegate:weakSelf];
        [weakSelf.sidebar selectButtonAtRow:0];
        [weakSelf.sidebar setSelectionImage:[weakSelf buildSelectionImage]];
        [weakSelf.sidebar setAnimateSelection:YES];
        
        [weakSelf layoutTableView];
        [weakSelf applyAccountsSettings];
        NPLoginController *lc = (NPLoginController*)weakSelf.loginPopover.contentViewController;
        [lc setVkFbDelegate:weakSelf];
        [lc setTwitterDelegate:weakSelf];
        [lc setLastFMDelegate:weakSelf];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:ACAccountStoreDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            if ([[note object] isEqualTo:weakSelf.accountsStore]) {
                ACAccountType *type = [weakSelf.accountsStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
                NSArray *fbAccounts = [weakSelf.accountsStore accountsWithAccountType:type];
                [weakSelf setOsxFacebookAccounts:fbAccounts];
                [weakSelf setSelectedFBAccount:[fbAccounts lastObject]];
            }
        }];
    });
}

- (void)readPreferences
{
//    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDefaultsKey];
//    [[NSUserDefaults standardUserDefaults] synchronize];
    
//    NSDictionary *saved = applicationPreferences();
//    if (saved) {
//        [self setPreferences:[saved deepMutableCopy]];
//    }
//    else {
//        [self setPreferences:[[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"embeddedPreferences" ofType:@"plist"]] deepMutableCopy]];
//    }
    
//    [self setPreferences:applicationPreferences()];
    NSDictionary *preferences = applicationPreferences();
    
//    NSUInteger last = [[preferences valueForKey:kLastTrackID] unsignedIntegerValue];
//    setLastTrackID(last);
    
    NSMutableArray *appearances = [NSMutableArray array];
    [[preferences valueForKey:kAppearanceSection] enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
        NPAppearance *app = [NPAppearance appearanceWithInfo:obj];
        [appearances addObject:app];
    }];
    [self setAppearances:appearances];
    
    NSDictionary *accounts = [preferences valueForKey:kAccountsSection];
    __block NPAccountMask mask = NPEmptyMask;
    [accounts enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *obj, BOOL *stop) {
        BOOL enabled = [[obj valueForKey:@"enabled"] boolValue];
        if (enabled) {
            NSString *token = [obj valueForKey:@"token"];
            switch ((NPAccountType)[key integerValue]) {
                case NPAccountVK: {
                    mask |= NPMaskVK;
//                    setVKToken(token);
                    //SET_VK_TOKEN(token);
                    break;
                }
                case NPAccountFB: {
                    mask |= NPMaskFB;
//                    setFBToken(token);
//                    SET_FB_TOKEN(token);
                    break;
                }
                case NPAccountLF: {
                    mask |= NPMaskLF;
//                    setLFToken(token);
//                    SET_LF_TOKEN(token);
                    break;
                }
                case NPAccountTW: {
                    NSString *identifier = [obj valueForKey:@"id"];
                    if (identifier) {
                        if (!self.accountsStore) {
                            ACAccountStore *store = [[ACAccountStore alloc] init];
                            [self setAccountsStore:store];
                        }
                        ACAccountType *type = [self.accountsStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
                        __weak typeof(self) weakSelf = self;
                        [self.accountsStore requestAccessToAccountsWithType:type options:nil completion:^(BOOL granted, NSError *error) {
                            if (granted) {
                                NSArray *accounts = [weakSelf.accountsStore accountsWithAccountType:type];
                                [weakSelf setOsxTwitterAccounts:accounts];
                                ACAccount *acc = [[accounts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.identifier==%@", identifier]] firstObject];
                                if (acc) {
                                    STTwitterAPI *wrapper = [STTwitterAPI twitterAPIOSWithAccount:acc];
                                    mask |= NPMaskTW;
                                    setTwitterWrapper(wrapper);
//                                    SET_TW_WRAPPER(wrapper);
                                }
                            }
                            else {
                                if ([error code] == ACErrorAccountNotFound) {
                                    [weakSelf setOsxTwitterAccounts:nil];
                                    [weakSelf setSelectedTWAccount:nil];
                                }
                            }
                        }];
                    }
                    else {
                        NSString *secret = [obj valueForKey:@"secret"];
                        STTwitterAPI *wrapper = [STTwitterAPI twitterAPIWithOAuthConsumerKey:kTWAppKey consumerSecret:kTWConsumerSecret oauthToken:token oauthTokenSecret:secret];
                        mask |= NPMaskTW;
                        setTwitterWrapper(wrapper);
//                        SET_TW_WRAPPER(wrapper);
                    }
                    break;
                }
                default:break;
            }
        }
    }];
//    SET_SOCIAL_MASK(mask);
}

#pragma mark - Tabs Delegate
#pragma mark Tab View

//- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
//{
//    DLog(@"%s", __PRETTY_FUNCTION__);
//    [self.sidebar selectButtonAtRow:[tabView indexOfTabViewItem:tabViewItem]];
//}

#pragma mark Side View

- (void)sideBar:(EDSideBar *)tabBar didSelectButton:(NSInteger)index
{
    DLog(@"%s", __PRETTY_FUNCTION__);
    [self.tabView selectTabViewItemAtIndex:index];
}

#pragma mark - TableView Delegate

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    NSTableView *tableView = [notification object];
    NSInteger selectedRow = [tableView selectedRow];
    NPAppearance *appearance = [[self.appearanceAC arrangedObjects] objectAtIndex:selectedRow];
    [self.fontPreview setStringValue:[NSString stringWithFormat:@"%@ - %1.1f", [appearance.font fontName], [appearance.font pointSize]]];
    [self.fontColorWell setColor:[appearance foregroundColor]];
    [self.fontbackColorWell setColor:[appearance backgroundColor]];
    [self.alignmentControl selectSegmentWithTag:appearance.alignment + 1000];
    [self.alignmentControl setEnabled:!([appearance.name isEqualToString:@"artist"] || [appearance.name isEqualToString:@"title"])];
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
    NPAppearance *appearance = [[self.appearanceAC arrangedObjects] objectAtIndex:row];
    NSSize size = [@"Nyargh" sizeWithFont:appearance.font constrainedToSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
    return size.height + 8;
}

#pragma mark - Popover

- (void)popoverWillShow:(NSNotification *)notification
{
    if ([notification.object isEqualTo:self.loginPopover]) {
        NPLoginController *lc = (NPLoginController*)self.loginPopover.contentViewController;
        switch (self.currentService) {
            case kVKFlag: {
                [lc signinVK];
                break;
            }
            case kFBFlag: {
                [lc signInFacebook];
                break;
            }
            case kTWFlag: {
                [lc signInTwitter];
                break;
            }
            case kLFFlag: {
                [lc signInLastFM];
                break;
            }
            default:break;
        }
    }
}

- (void)popoverWillClose:(NSNotification *)notification
{
    if (![[notification object] isEqualTo:self.loginPopover]) {
        NSMutableArray *appearances = [NSMutableArray array];
        [[self.appearanceAC arrangedObjects] enumerateObjectsUsingBlock:^(NPAppearance *obj, NSUInteger idx, BOOL *stop) {
            NSDictionary *dict = [obj infoForArchiving];
            [appearances addObject:dict];
        }];
        NSMutableDictionary *prefs = applicationPreferences();
        [prefs setObject:appearances forKey:kAppearanceSection];
        if (saveApplicationPreferences(prefs)) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kNPPreferencesDidSaveNotification object:nil userInfo:prefs];
        }
    }
}

#pragma mark - Appearance Tab

- (void)changeFont:(NSFontManager*)sender
{
    NSFont *selectedFont = [sender convertFont:[NSFont fontWithName:@"Helvetica" size:12]];
    NSInteger selectedRow = [self.appearanceTable selectedRow];
    NPAppearance *appearance = [[self.appearanceAC arrangedObjects] objectAtIndex:selectedRow];
    [self.appearanceAC willChangeValueForKey:@"arrangedObjects"];
    [appearance setFont:selectedFont];
    [self.appearanceAC didChangeValueForKey:@"arrangedObjects"];
    
    [self layoutTableView];
}

- (void)layoutTableView
{
    __block CGFloat height = 0;
    __weak typeof(self) weakSelf = self;
    [[self.appearanceAC arrangedObjects] enumerateObjectsUsingBlock:^(NPAppearance *obj, NSUInteger idx, BOOL *stop) {
        CGFloat rowHeight = [weakSelf tableView:weakSelf.appearanceTable heightOfRow:idx];
        height += rowHeight;
    }];
    [self.tableHeight setConstant:(MIN(height, 225) + 3*([[self.appearanceAC arrangedObjects] count] - 1))];
}

- (IBAction)changeAlignment:(NSSegmentedControl*)sender
{
    NSInteger selectedRow = [self.appearanceTable selectedRow];
    NPAppearance *appearance = [[self.appearanceAC arrangedObjects] objectAtIndex:selectedRow];
    NSTextAlignment a = [[sender cell] tagForSegment:[sender selectedSegment]] - 1000;
    [self.appearanceAC willChangeValueForKey:@"arrangedObjects"];
    [appearance setAlignment:a];
    [self.appearanceAC didChangeValueForKey:@"arrangedObjects"];
}

- (IBAction)changeForegroundColor:(id)sender
{
    NSInteger selectedRow = [self.appearanceTable selectedRow];
    NPAppearance *appearance = [[self.appearanceAC arrangedObjects] objectAtIndex:selectedRow];
    [self.appearanceAC willChangeValueForKey:@"arrangedObjects"];
    [appearance setForegroundColor:[sender color]];
    [self.appearanceAC didChangeValueForKey:@"arrangedObjects"];
}

- (IBAction)changeBackgroundColor:(id)sender
{
    NSInteger selectedRow = [self.appearanceTable selectedRow];
    NPAppearance *appearance = [[self.appearanceAC arrangedObjects] objectAtIndex:selectedRow];
    [self.appearanceAC willChangeValueForKey:@"arrangedObjects"];
    [appearance setBackgroundColor:[sender color]];
    [self.appearanceAC didChangeValueForKey:@"arrangedObjects"];
}

- (IBAction)revertToDefaults:(id)sender
{
    NSMutableDictionary *defaults = [[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"embeddedPreferences" ofType:@"plist"]] deepMutableCopy];
    saveApplicationPreferences(defaults);
    //    [self setPreferences:[[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"embeddedPreferences" ofType:@"plist"]] deepMutableCopy]];
    NSMutableArray *appearances = [NSMutableArray array];
    [[defaults valueForKey:kAppearanceSection] enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
        NPAppearance *app = [NPAppearance appearanceWithInfo:obj];
        [appearances addObject:app];
    }];
    [self.appearanceAC willChangeValueForKey:@"arrangedObjects"];
    [self setAppearances:appearances];
    [self.appearanceAC didChangeValueForKey:@"arrangedObjects"];
}

#pragma mark - Accounts tab

- (void)applyAccountsSettings
{
    NSDictionary *accSettings = [applicationPreferences() valueForKey:kAccountsSection];
    NSView *accountsView = [[self.tabView tabViewItemAtIndex:2] view];
    __weak typeof(self) weakSelf = self;
    [accSettings enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *obj, BOOL *stop) {
        NSUInteger tag = [key integerValue];
        NSButton *accButton = [accountsView viewWithTag:tag];
        BOOL isEnabled = [[obj valueForKey:@"enabled"] boolValue];
        [weakSelf socialButton:accButton enabled:isEnabled];
    }];
}

- (IBAction)vkAction:(id)sender
{
    if ([self.loginPopover isShown]) {
        [self.loginPopover close];
    }
    
    [self setCurrentService:kVKFlag];
    NSDictionary *vkSettings = [[applicationPreferences() valueForKey:kAccountsSection] valueForKey:kAccountsVK];
    BOOL isEnabled = [[vkSettings valueForKey:@"enabled"] boolValue];
    if (isEnabled) {
        setVKToken(nil);
        [self socialButton:sender enabled:NO];
    }
    else {
        [self openLoginDialog:sender];
        [[sender layer] addAnimation:[self waitingAnimation] forKey:@"opacity"];
    }
}

- (IBAction)fbAction:(id)sender
{
    if ([self.loginPopover isShown]) {
        [self.loginPopover close];
    }
    
    NSMutableDictionary *fbSettings = [[applicationPreferences() valueForKey:kAccountsSection] valueForKey:kAccountsFB];
    BOOL isEnabled = [[fbSettings valueForKey:@"enabled"] boolValue];
    if (!isEnabled) {
        [[sender layer] addAnimation:[self waitingAnimation] forKey:@"opacity"];
        [self setCurrentService:kFBFlag];
        if (!self.accountsStore) {
            ACAccountStore *store = [[ACAccountStore alloc] init];
            [self setAccountsStore:store];
        }
        ACAccountType *type = [self.accountsStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
        NSDictionary *permissions = @{ACFacebookAppIdKey:kFBAppKey, ACFacebookPermissionsKey:@[@"email"], ACFacebookAudienceKey:ACFacebookAudienceEveryone};
        __weak typeof(self) weakSelf = self;
        [self.accountsStore requestAccessToAccountsWithType:type options:permissions completion:^(BOOL granted, NSError *error) {
            if (granted) {
                NSDictionary *additional = @{ACFacebookAppIdKey:kFBAppKey, ACFacebookPermissionsKey:@[@"status_update", @"user_status", @"publish_stream"], ACFacebookAudienceKey:ACFacebookAudienceEveryone};
                [weakSelf.accountsStore requestAccessToAccountsWithType:type options:additional completion:^(BOOL deepGranted, NSError *deepError) {
                    if (deepGranted) {
                        NSArray *accounts = [weakSelf.accountsStore accountsWithAccountType:type];
                        [weakSelf setOsxFacebookAccounts:accounts];
                        [weakSelf setSelectedFBAccount:[accounts firstObject]];
                        [weakSelf openLoginDialog:sender];
                    }
                    else {
                        DLog(@"%@", deepError);
                    }
                }];
            }
            else {
                if ([error code] == ACErrorAccountNotFound) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSString *loginURLString = [NSString stringWithFormat:@"https://www.facebook.com/dialog/oauth?client_id=%@&redirect_uri=https://www.facebook.com/connect/login_success.html&response_type=token&scope=user_status,publish_stream&display=popup", kFBAppKey];
                        [(NPLoginController*)weakSelf.loginPopover.contentViewController setLoginURL:[NSURL URLWithString:loginURLString]];
                        NSRect insetrect = NSInsetRect([sender bounds], 0, 15);
                        [weakSelf.loginPopover showRelativeToRect:insetrect ofView:sender preferredEdge:NSMinYEdge];
                    });
                }
            }
        }];
    }
    else {
        setFBToken(nil);
        [self socialButton:sender enabled:NO];
    }
}

- (IBAction)twAction:(id)sender
{
    if ([self.loginPopover isShown]) {
        [self.loginPopover close];
    }
    NSMutableDictionary *tw = [applicationPreferences() valueForKeyPath:[NSString stringWithFormat:@"%@.%@", kAccountsSection, kAccountsTW]];
    BOOL enabled = [[tw valueForKey:@"enabled"] boolValue];
    if (!enabled) {
        [self setCurrentService:kTWFlag];
        if (!self.accountsStore) {
            ACAccountStore *store = [[ACAccountStore alloc] init];
            [self setAccountsStore:store];
        }
        ACAccountType *type = [self.accountsStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
        __weak typeof(self) weakSelf = self;
        [self.accountsStore requestAccessToAccountsWithType:type options:nil completion:^(BOOL granted, NSError *error) {
            if (granted) {
                NSArray *accounts = [weakSelf.accountsStore accountsWithAccountType:type];
                [weakSelf setOsxTwitterAccounts:accounts];
                [weakSelf setSelectedTWAccount:[accounts firstObject]];
                [weakSelf openLoginDialog:sender];
            }
            else {
                if ([error code] == ACErrorAccountNotFound) {
                    [weakSelf setOsxTwitterAccounts:nil];
                    [weakSelf setSelectedTWAccount:nil];
                }
            }
        }];
    }
    else {
        setTwitterWrapper(nil);
        [self socialButton:sender enabled:NO];
    }
}

- (IBAction)lfAction:(id)sender
{
    if ([self.loginPopover isShown]) {
        [self.loginPopover close];
    }
    NSMutableDictionary *lfSettings = [applicationPreferences() valueForKeyPath:[NSString stringWithFormat:@"%@.%@", kAccountsSection, kAccountsLF]];//[[self.preferences valueForKey:kAccountsSection] valueForKey:kAccountsVK];
    BOOL isEnabled = [[lfSettings valueForKey:@"enabled"] boolValue];
    if (!isEnabled) {
        [self setCurrentService:kLFFlag];
        [self openLoginDialog:sender];
        [[sender layer] addAnimation:[self waitingAnimation] forKey:@"opacity"];
    }
    else {
        setLFToken(nil);
        [self socialButton:sender enabled:NO];
    }
}

- (IBAction)switchLyricsTagging:(id)sender
{
    BOOL enable = [sender state] == NSOnState;
    setNeedTaggingForType(NPLyricsTagging, enable);
//    [self.preferences setValue:@(enable) forKey:kLyricsTagKey];
}

- (IBAction)switchArtworkTagging:(id)sender
{
    BOOL enable = [sender state] == NSOnState;
    setNeedTaggingForType(NPArtworkTagging, enable);
//    [self.preferences setValue:@(enable) forKey:kArtworkTagKey];
}

- (void)openLoginDialog:(id)sender
{
//    NSRect insetrect = NSInsetRect([sender bounds], 0, 15);
    [self.loginPopover showRelativeToRect:[sender bounds]/*insetrect*/ ofView:sender preferredEdge:NSMinYEdge];
}

#pragma mark VK & FB

- (void)getToken:(NSString *)token userID:(NSInteger)uid service:(Service)service
{
    if (token && uid != NSNotFound) {
        DLog(@"VK or FB ok");
//        NSMutableDictionary *account = nil;
        NSButton *btn = nil;
        NSView *accountsView = [[self.tabView tabViewItemAtIndex:2] view];
        if (service == kVKFlag) {
//            account = [[self.preferences valueForKey:kAccountsSection] valueForKey:kAccountsVK];
//            SET_VK_TOKEN(token);
            setVKToken(token);
            btn = [accountsView viewWithTag:[kAccountsVK integerValue]];
        }
        else if (service == kFBFlag) {
//            account = [[self.preferences valueForKey:kAccountsSection] valueForKey:kAccountsFB];
//            SET_FB_TOKEN(token);
            setFBToken(token);
            btn = [accountsView viewWithTag:[kAccountsFB integerValue]];
        }
//        [account setValue:token forKey:@"token"];
//        [account setValue:@(uid) forKey:@"uid"];
//        [account setValue:@(YES) forKey:@"enabled"];
        
        [self socialButton:btn enabled:YES];
    }
    else {
        DLog(@"VK or FB fail");
    }
    [self.loginPopover close];
}

- (void)userDidConfirmOSXFacebookAccount
{
    NSButton *fbButton = [[[self.tabView tabViewItemAtIndex:2] view] viewWithTag:[kAccountsFB integerValue]];
    [self socialButton:fbButton enabled:YES];
//    SET_FB_TOKEN(self.selectedFBAccount.credential.oauthToken);
    setFBToken(self.selectedFBAccount.credential.oauthToken);
//    [[[self.preferences valueForKey:kAccountsSection] valueForKey:kAccountsFB] setValue:@(YES) forKey:@"enabled"];
//    [[[self.preferences valueForKey:kAccountsSection] valueForKey:kAccountsFB] setValue:getFBToken() forKey:@"token"];
    [self.loginPopover close];
}

- (void)renewFBCredentials:(void (^)(BOOL))completion
{
    [self setFbRenewBlock:completion];
    if (!self.accountsStore) {
        ACAccountStore *store = [[ACAccountStore alloc] init];
        [self setAccountsStore:store];
        ACAccountType *type = [self.accountsStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
        NSDictionary *permissions = @{ACFacebookAppIdKey:kFBAppKey, ACFacebookPermissionsKey:@[@"email"], ACFacebookAudienceKey:ACFacebookAudienceEveryone};
        __weak typeof(self) weakSelf = self;
        [self.accountsStore requestAccessToAccountsWithType:type options:permissions completion:^(BOOL granted, NSError *error) {
            if (granted) {
                NSDictionary *additional = @{ACFacebookAppIdKey:kFBAppKey, ACFacebookPermissionsKey:@[@"status_update", @"user_status", @"publish_stream"], ACFacebookAudienceKey:ACFacebookAudienceEveryone};
                [weakSelf.accountsStore requestAccessToAccountsWithType:type options:additional completion:^(BOOL deepGranted, NSError *deepError) {
                    if (deepGranted) {
                        NSArray *accounts = [weakSelf.accountsStore accountsWithAccountType:type];
                        [weakSelf setOsxFacebookAccounts:accounts];
                        [weakSelf setSelectedFBAccount:[accounts firstObject]];
                        [weakSelf renewFBCredentials];
                    }
                    else {
                        DLog(@"%@", deepError);
                    }
                }];
            }
        }];
    }
    else {
        [self renewFBCredentials];
    }
}

- (void)renewFBCredentials
{
    __weak typeof(self) weakSelf = self;
    [self.accountsStore renewCredentialsForAccount:weakSelf.selectedFBAccount completion:^(ACAccountCredentialRenewResult renewResult, NSError *error) {
        if (renewResult == ACAccountCredentialRenewResultRenewed) {
//            SET_FB_TOKEN(weakSelf.selectedFBAccount.credential.oauthToken);
            setFBToken(weakSelf.selectedFBAccount.credential.oauthToken);
//            [[[weakSelf.preferences valueForKey:kAccountsSection] valueForKey:kAccountsFB] setValue:getFBToken() forKey:@"token"];
//            [[NSUserDefaults standardUserDefaults] setObject:weakSelf.preferences forKey:kDefaultsKey];
//            [[NSUserDefaults standardUserDefaults] synchronize];
            weakSelf.fbRenewBlock(YES);
        }
        else {
            weakSelf.fbRenewBlock(NO);
        }
    }];
}

#pragma mark Twitter

- (void)twitterLogin:(id)sender account:(ACAccount*)account
{
    if (account) {
        STTwitterAPI *wrapper = [STTwitterAPI twitterAPIOSWithAccount:account];
        [self setTwitter:wrapper];
        [[sender layer] addAnimation:[self waitingAnimation] forKey:@"opacity"];
        __weak typeof(self) weakSelf = self;
        [wrapper verifyCredentialsWithSuccessBlock:^(NSString *username) {
//            SET_TW_WRAPPER(wrapper);
            setTwitterWrapper(wrapper);
            [weakSelf socialButton:sender enabled:YES];
            setTwitterSystemAccountID([wrapper valueForKeyPath:@"oauth.account.identifier"]);
            setTwitterWrapper(wrapper);
//            NSMutableDictionary *tw = [[weakSelf.preferences valueForKey:kAccountsSection] valueForKey:kAccountsTW];
//            [tw setValue:@(YES) forKey:@"enabled"];
//            [tw setValue:[wrapper valueForKeyPath:@"oauth.account.identifier"] forKey:@"id"];
            [weakSelf.loginPopover close];
        } errorBlock:^(NSError *error) {
            DLog(@"%@", error);
            [weakSelf socialButton:sender enabled:NO];
        }];
    }
}

- (void)guessPin:(NSString*)login pass:(NSString*)pass
{
    STTwitterAPI *wrapper = [STTwitterAPI twitterAPIWithOAuthConsumerKey:kTWAppKey consumerSecret:kTWConsumerSecret];
    [self setTwitter:wrapper];
    
    STTwitterHTML *html = [[STTwitterHTML alloc] init];
    __weak typeof(self) weakSelf = self;
    
    NSButton *twitterButton = [[[self.tabView tabViewItemAtIndex:2] view] viewWithTag:[kAccountsTW integerValue]];
    [[twitterButton layer] addAnimation:[self waitingAnimation] forKey:@"opacity"];
    
    [wrapper postTokenRequest:^(NSURL *url, NSString *oauthToken) {
        [html getLoginForm:^(NSString *authenticityToken) {
            [html postLoginFormWithUsername:login password:pass authenticityToken:authenticityToken successBlock:^(NSString *body) {
                [html getAuthorizeFormAtURL:url successBlock:^(NSString *authenticityToken, NSString *oauthToken) {
                    [html postAuthorizeFormResultsAtURL:url authenticityToken:authenticityToken oauthToken:oauthToken successBlock:^(NSString *PIN) {
                        [wrapper postAccessTokenRequestWithPIN:PIN successBlock:^(NSString *oauthToken, NSString *oauthTokenSecret, NSString *userID, NSString *screenName) {
//                            NSMutableDictionary *twitterSettings = [[weakSelf.preferences valueForKey:kAccountsSection] valueForKey:kAccountsTW];
                            setTwitterCredentials(oauthToken, oauthTokenSecret);
//                            [twitterSettings setValue:@(YES) forKey:@"enabled"];
//                            [twitterSettings setValue:oauthToken forKey:@"token"];
//                            [twitterSettings setValue:oauthTokenSecret forKey:@"secret"];
                            [weakSelf socialButton:twitterButton enabled:YES];
                            
                            STTwitterAPI *twitter = [STTwitterAPI twitterAPIWithOAuthConsumerKey:kTWAppKey consumerSecret:kTWConsumerSecret oauthToken:oauthToken oauthTokenSecret:oauthTokenSecret];
//                            SET_TW_WRAPPER(twitter);
                            setTwitterWrapper(twitter);
                            
                        } errorBlock:^(NSError *error) {
                            DLog(@"%@", error);
                            [weakSelf socialButton:twitterButton enabled:NO];
                        }];
                    } errorBlock:^(NSError *error) {
                        DLog(@"%@", error);
                        [weakSelf socialButton:twitterButton enabled:NO];
                    }];
                } errorBlock:^(NSError *error) {
                    DLog(@"%@", error);
                    [weakSelf socialButton:twitterButton enabled:NO];
                }];
            } errorBlock:^(NSError *error) {
                DLog(@"%@", error);
                [weakSelf socialButton:twitterButton enabled:NO];
            }];
        } errorBlock:^(NSError *error) {
            DLog(@"%@", error);
            [weakSelf socialButton:twitterButton enabled:NO];
        }];
    } oauthCallback:nil errorBlock:^(NSError *error) {
        DLog(@"%@", error);
        [weakSelf socialButton:twitterButton enabled:NO];
    }];
}

- (void)userDidCancelTwitterLogin
{
    [self.loginPopover close];
}

- (void)twitterUserDidEnterUsername:(NSString *)username password:(NSString *)password
{
    [self userDidCancelTwitterLogin];
    [self guessPin:username pass:password];
}

- (void)userDidConfirmOSXTwitterAccount
{
    [self twitterLogin:nil account:self.selectedTWAccount];
}

- (STTwitterAPI *)twitterWrapper
{
    return self.twitter;
}

#pragma mark - LastFM

- (void)lastFMUserDidEnterUsername:(NSString *)username password:(NSString *)password
{
    
}

- (void)lastFMDidSuccessfullLogin:(NSDictionary *)info
{
//    NSMutableDictionary *lfSettings = [[self.preferences valueForKey:kAccountsSection] valueForKey:kAccountsLF];
//    [lfSettings setValue:@(YES) forKey:@"enabled"];
//    [lfSettings setValue:[info valueForKey:@"name"] forKey:@"name"];
//    [lfSettings setValue:[info valueForKey:@"key"] forKey:@"token"];
//    SET_LF_TOKEN([info valueForKey:@"key"]);
    setLFToken([info valueForKey:@"key"]);
    
    NSButton *lfButton = [[[self.tabView tabViewItemAtIndex:2] view] viewWithTag:[kAccountsLF integerValue]];
    [self socialButton:lfButton enabled:YES];
    
    [self.loginPopover close];
}

- (void)lastFMDidLoginWithError:(NSError *)error
{
    DLog(@"%@", error);
    [self userDidCancelLastFMLogin];
    [[NSAlert alertWithError:error] runModal];
}

- (void)userDidCancelLastFMLogin
{
    [self.loginPopover close];
    NSButton *lfButton = [[[self.tabView tabViewItemAtIndex:2] view] viewWithTag:[kAccountsLF integerValue]];
    [self socialButton:lfButton enabled:NO];
}

#pragma mark Change social service state

- (void)socialButton:(NSButton*)button enabled:(BOOL)enabled
{
    if ([button respondsToSelector:@selector(layerUsesCoreImageFilters)]) {
        if (![button layerUsesCoreImageFilters]) {
            [button setLayerUsesCoreImageFilters:YES];
        }
        [button setWantsLayer:YES];
    }
    if (enabled) {
        [[button layer] setFilters:nil];
    }
    else {
        CIFilter *filter = [CIFilter filterWithName:@"CIMinimumComponent"];
        [filter setDefaults];
        [[button layer] setFilters:@[filter]];
    }
    [[button layer] removeAnimationForKey:@"opacity"];
}

- (CAAnimation*)waitingAnimation
{
    CABasicAnimation *theAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    theAnimation.duration=1.0;
    theAnimation.repeatCount=HUGE_VALF;
    theAnimation.autoreverses=YES;
    theAnimation.fromValue=[NSNumber numberWithFloat:1.0];
    theAnimation.toValue=[NSNumber numberWithFloat:0.0];
    return theAnimation;
}

@end
