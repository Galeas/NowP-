//
//  NPMainHandler.m
//  NowP!
//
//  Created by Evgeniy Kratko on 24.06.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import "NPMainHandler.h"
#import "FbGraph.h"
#import "FbGraphFile.h"
#import "NPStatusItemButton.h"
#import "NPLyricsWindow.h"
#import "NPiTunesWorker.h"
#import "NPPopoverView.h"

#import "NSString+Extra.h"
#import "NSImage+Resize.h"
#import <STTwitterAPI.h>

@interface NPMainHandler () <iTunesWorkerDelegate>
@property (strong, nonatomic) NPLyricsWindow *lyricsWindow;
@property (weak) IBOutlet NSMenu *barMenu;
@property (weak) IBOutlet NSPopover *prefsPopover;
@property (strong, nonatomic) id popoverTransiency;
@property (weak, nonatomic) id popoverObserver;
- (IBAction)showPreferences:(id)sender;
@end

@implementation NPMainHandler

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self makeStatusView];
        [self setLyricsWindow:[[NPLyricsWindow alloc] initWithContentRect:NSZeroRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO]];
        [[NPiTunesWorker worker] setDelegate:self];
    }
    return self;
}

#pragma mark
#pragma mark Status View

- (void)makeStatusView
{    
    NSStatusItem *statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NPStatusItemButton *btn = [[NPStatusItemButton alloc] initWithFrame:NSMakeRect(0, 0, 17, 17)];
    [btn setImagePosition:NSImageOnly];
    [[btn cell] setImageScaling:NSImageScaleProportionallyDown];
    [btn setBordered:NO];
    [btn setButtonType:NSMomentaryChangeButton];
    [btn setImage:[NSImage imageNamed:@"statusIcon"]];
    [btn setTarget:self];
    [btn setAction:@selector(leftClick:)];
    [btn setRightAction:@selector(rightClick:)];
    [statusItem setView:btn];
    [self setStatusItem:statusItem];
}

- (void)leftClick:(id)sender
{
    [self.popover showRelativeToRect:[sender bounds] ofView:sender preferredEdge:NSMinYEdge];
}

- (void)rightClick:(id)sender
{
    [self.statusItem popUpStatusItemMenu:self.barMenu];
}

#pragma mark
#pragma mark Worker Delegate

- (void)worker:(NPiTunesWorker *)worker didUpdateTrack:(iTunesTrack *)track withInfo:(NSDictionary *)info
{
    NSUInteger trackID = [info[kTrackIDKey] unsignedIntegerValue];
    if (getLastTrackID() != trackID) {
        [self updatePopover:info];
        [self updateSocialStatuses:info];
//        SET_LAST_TRACK_ID(trackID);
        setLastTrackID(trackID);
    }
    DLog(@"%s", __PRETTY_FUNCTION__);
}

- (void)worker:(NPiTunesWorker *)worker failedUpdateTrack:(iTunesTrack *)track error:(NSError *)error
{
    
}

- (void)playerStoppedWithWoker:(NPiTunesWorker *)worker
{
    [self updatePopover:nil];
}

- (void)worker:(NPiTunesWorker *)worker startedWithLastTrack:(iTunesTrack *)track info:(NSDictionary *)info
{
    [self updatePopover:info];
}

#pragma mark - Update popover

- (void)updatePopover:(NSDictionary*)info
{
    NPPopoverView *view = (NPPopoverView*)[self.popover.contentViewController view];
    [view setCover:info[kArtworkKey]];
    [view setArtist:info[kArtistKey]];
    [view setTitle:info[kTitleKey]];
    [self.lyricsWindow setText:info[kLyricsKey]];
    [self.lyricsWindow orderFront:self];
}

#pragma mark - Social

- (void)updateSocialStatuses:(NSDictionary*)info
{
    NPAccountMask mask = getAccountMask();
    if (mask & NPMaskVK) {
        [self postVK:info];
    }
    if (mask & NPMaskFB) {
        [self postFB:info];
    }
    if (mask & NPMaskTW) {
        [self postTW:info];
    }
    if (mask & NPMaskLF) {
        [self postLF:info];
    }
}

#pragma mark VKontakte

- (void)postVK:(NSDictionary*)info
{
    NSString *a = [info valueForKey:kArtistKey];
    NSString *artist = [a stringUsingEncoding:NSUTF8StringEncoding];
    NSString *t = [info valueForKey:kTitleKey];
    NSString *title = [t stringUsingEncoding:NSUTF8StringEncoding];
    NSString *token = getVKToken();
    
    NSString *stringURL = [NSString stringWithFormat:@"https://api.vk.com/method/execute.postSongStatus?name=%@&artist=%@&access_token=%@", title, artist, token];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:stringURL]];
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:&error];
        NSArray *items = [[NSJSONSerialization JSONObjectWithData:data options:0 error:&error] valueForKey:@"response"];
        if ([items count] == 0) {
            NSString *statusString = [[weakSelf statusString:a title:t] stringUsingEncoding:NSUTF8StringEncoding];
            NSString *stringURL = [NSString stringWithFormat:@"https://api.vk.com/method/status.set?text=%@&access_token=%@&v=5.0", statusString, token];
            [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:stringURL]] returningResponse:NULL error:&error];
        }
    });
}

#pragma mark Facebook

- (void)postFB:(NSDictionary*)info
{
//#error Handle image attachments
    NSString *artist = [info valueForKey:kArtistKey];
    NSString *title = [info valueForKey:kTitleKey];
    NSString *statusUpdate = [self statusString:artist title:title];
    FbGraph *api = [[FbGraph alloc] initWithFbClientID:kFBAppKey];
    [api setAccessToken:getFBToken()];
    NSImage *image = [info valueForKey:kArtworkKey];
    NSDictionary *params = nil;
    NSString *method = nil;
    __weak typeof(self) weakSelf = self;
    if (image) {
        FbGraphFile *attachment = [[FbGraphFile alloc] initWithImage:image];
        method = @"me/photos";
        params = @{@"file":attachment, @"message":statusUpdate, @"description":@"Now playing with my iTunes"};
    }
    else {
        method = @"me/feed";
        params = @{@"message":statusUpdate, @"description":@"Now playing with my iTunes"};
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        FbGraphResponse *response = [api doGraphPost:method withPostVars:params];
        NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:[response.htmlResponse dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
        if ([[responseDict valueForKeyPath:@"error.code"] integerValue] == 190) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
            [weakSelf.prefsPopover.contentViewController performSelector:@selector(renewFBCredentials:) withObject:^(BOOL success){
                [weakSelf postFB:info];
            }];
#pragma clang diagnotic pop
        }
    });
}

#pragma mark Twitter

- (void)postTW:(NSDictionary*)info
{
    NSString *artist = [info valueForKey:kArtistKey];
    NSString *name = [info valueForKey:kTitleKey];
    
    STTwitterAPI *wrapper = getTwitterWrapper();
    if (!wrapper) return;
    NSString *statusUpdate = [[@"#NowPlaying " stringByAppendingString:[self statusString:artist title:name]] stringByAppendingString:@" #NowP_App"];
    NSImage *image = [info valueForKey:kArtworkKey];
    NSData *data = [image PNGRepresentation];
    NSString* tempPath = NSTemporaryDirectory();
    NSString* tempFile = [[tempPath stringByAppendingPathComponent:name] stringByAppendingPathExtension:@"png"];;
    NSURL* URL = [NSURL fileURLWithPath:tempFile];
    [data writeToURL:URL atomically:NO];
    [wrapper postStatusUpdate:statusUpdate inReplyToStatusID:nil mediaURL:URL placeID:nil latitude:nil longitude:nil uploadProgressBlock:nil successBlock:^(NSDictionary *status) {
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtURL:URL error:&error];
    } errorBlock:^(NSError *error) {
        DLog(@"%@", error);
    }];
}

#pragma mark LastFM

- (void)postLF:(NSDictionary*)info
{
    NSString *artist = [info valueForKey:kArtistKey];
    NSString *title = [info valueForKey:kTitleKey];
    
    NSInteger timestamp = [[NSDate date] timeIntervalSince1970];
    NSMutableDictionary *requestInfo = [NSMutableDictionary dictionaryWithDictionary:@{@"artist[0]":artist, @"track[0]":title, @"api_key":kLFAppKey, @"sk":getLFToken(), @"method":@"track.scrobble", @"timestamp[0]":@(timestamp)}];
    NSString *signature = [self generateSignatureFromDictionary:requestInfo];
    [requestInfo setValue:signature forKey:@"api_sig"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"http://ws.audioscrobbler.com/2.0/" stringByAppendingString:@"?format=json"]] cachePolicy:NSURLCacheStorageAllowedInMemoryOnly timeoutInterval:5];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[self generatePOSTBodyFromDictionary:requestInfo]];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        if (data && !error) {
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if ([dict valueForKey:@"error"]) {
                DLog(@"Error:%@", [dict valueForKey:@"error"]);
            }
        }
    });
}

- (NSString *)generateSignatureFromDictionary:(NSDictionary *)dict {
    NSMutableArray *aMutableArray = [[NSMutableArray alloc] initWithArray:[dict allKeys]];
    NSMutableString *rawSignature = [[NSMutableString alloc] init];
    [aMutableArray sortUsingFunction:sortAlpha context:(__bridge void *)(self)];
    
    for(NSString *key in aMutableArray) {
        [rawSignature appendString:[NSString stringWithFormat:@"%@%@", key, [dict objectForKey:key]]];
    }
    
    [rawSignature appendString:kLFSecret];
    
    NSString *signature = [rawSignature md5sum];
    return signature;
}

- (NSData *)generatePOSTBodyFromDictionary:(NSDictionary *)dict {
    NSMutableString *rawBody = [[NSMutableString alloc] init];
    NSMutableArray *aMutableArray = [[NSMutableArray alloc] initWithArray:[dict allKeys]];
    [aMutableArray sortUsingFunction:sortAlpha context:(__bridge void *)(self)];
    
    for(NSString *key in aMutableArray) {
        [rawBody appendString:[NSString stringWithFormat:@"&%@=%@", key, [dict objectForKey:key]]];
    }
    NSString *body = [NSString stringWithString:rawBody];
    return [body dataUsingEncoding:NSUTF8StringEncoding];
}

#pragma mark - Common

- (NSString*)statusString:(NSString*)artist title:(NSString*)title
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

- (IBAction)showPreferences:(id)sender
{
    NSView *view = [self.statusItem view];
//    [self.prefsPopover setAppearance:(NSPopoverAppearance)[NSAppearance appearanceNamed:NSAppearanceNameAqua]];
    [self.prefsPopover showRelativeToRect:[view bounds] ofView:view preferredEdge:NSMinYEdge];
}
@end
