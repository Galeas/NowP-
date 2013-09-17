//
//  NPAppDelegate.m
//  NowP!
//
//  Created by Евгений Браницкий on 05.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NPAppDelegate.h"
#import "NPMainHandler.h"
#import "NPPreferencesController.h"
#import "NSString+Extra.h"
#import "NSObject+DeepMutable.h"
#import "SSKeychain.h"

@implementation NPAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
//    cleanAppSettings();
    NSString *currentVersion = settingsVersion();
    NSString *bundleVersion = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleShortVersionString"];
    if (![currentVersion isEqualToString:bundleVersion]) {
        updateAppSettingForNewVersion();
    }
    
    [self cacheVKStatus];
    
    _mainHandler = [NPMainHandler handler];
    [_mainHandler iTunesInfoDidUpdate];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    NPPreferencesController *prefs = [NPPreferencesController preferences];
    VKStatusRestoringPolicy policy = prefs.vkStatusRestorePolicy;
    if (policy == kIgnoreStatusRestoring || policy == kRestoreOnPause || !(prefs.accountsConfiguration & kVKFlag)) {
        return NSTerminateNow;
    }
    else if (!_canTerminate) {
        [self restoreVKStatusOnTerminate:YES];
        return NSTerminateCancel;
    }
    return NSTerminateNow;
}

- (void)cacheVKStatus
{
    NPPreferencesController *prefs = [NPPreferencesController preferences];
    if ([prefs vkStatusRestorePolicy] == kIgnoreStatusRestoring || !(prefs.accountsConfiguration & kVKFlag)) return;
    
    NSDictionary *vk = [[[NPPreferencesController preferences] accountsSettings] objectForKey:kVKServiceKey];
    NSString *accessToken = [vk valueForKey:kAccessTokenKey];
    NSString *stringURL = [NSString stringWithFormat:@"https://api.vk.com/method/status.get?access_token=%@&v=5.0", accessToken];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:stringURL]];
    
    dispatch_queue_t requestQueue = dispatch_queue_create("getStatus", NULL);
    __weak NPAppDelegate *weakSelf = self;
    dispatch_async(requestQueue, ^{
        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        if (data && !error) {
            NSDictionary *rawInfo = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (!error) {
                NSDictionary *responseInfo = [rawInfo objectForKey:@"response"];
                if (responseInfo) {
                    NSDictionary *audio = [responseInfo objectForKey:@"audio"];
                    NPAppDelegate *strongSelf = weakSelf;
                    if (strongSelf == nil) return;
                    if (audio) {
                        NSString *audio_id = [[audio valueForKey:@"id"] stringValue];
                        NSString *owner_id = [[audio valueForKey:@"owner_id"] stringValue];
                        NSString *toCache = [owner_id stringByAppendingFormat:@"_%@", audio_id];
                        [strongSelf setCachedVKStatus:toCache];
                    }
                    else {
                        NSString *toCache = [[responseInfo valueForKey:@"text"] stringByReplacingOccurrencesOfString:@"&ndash" withString:@"-"];
                        [strongSelf setCachedVKStatus:toCache];
                    }
                }
            }
        }
    });
    dispatch_release(requestQueue);
}

- (void)restoreVKStatusOnTerminate:(BOOL)terminate
{
    NPPreferencesController *prefs = [NPPreferencesController preferences];
    if (!self.cachedVKStatus || self.cachedVKStatus.length == 0 || ![prefs accountsConfiguration] & kVKFlag) {
        if (terminate) {
            _canTerminate = YES;
            [NSApp terminate:self];
        }
        return;
    }
    
    BOOL isBroadcast = NO;
    NSArray *parts = [self.cachedVKStatus componentsSeparatedByString:@"_"];
    if ([parts count] == 2) {
        if ([[parts objectAtIndex:0] integerValue] != NSNotFound && [[parts objectAtIndex:1] integerValue] != NSNotFound)
            isBroadcast = YES;
    }
    NSDictionary *vk = [[prefs accountsSettings] objectForKey:kVKServiceKey];
    NSString *accessToken = [vk valueForKey:kAccessTokenKey];
    NSString *stringURL = nil;
    if (isBroadcast) {
        stringURL = [NSString stringWithFormat:@"https://api.vk.com/method/audio.setBroadcast?audio=%@&access_token=%@&v=5.0", self.cachedVKStatus, accessToken];
    }
    else {
        stringURL = [NSString stringWithFormat:@"https://api.vk.com/method/status.set?text=%@&access_token=%@&v=5.0", [self.cachedVKStatus stringUsingEncoding:NSUTF8StringEncoding], accessToken];
    }
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:stringURL]];
    dispatch_queue_t requestQueue = dispatch_queue_create("restoreStatus", NULL);
    __weak NPAppDelegate *weakSelf = self;
    dispatch_async(requestQueue, ^{
        NSError *error = nil;
        NSURLResponse *response = nil;//
        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        if (!error) {
            NPAppDelegate *strongSelf = weakSelf;
            if (!strongSelf) return;
            if (terminate) {
                strongSelf->_canTerminate = YES;
                [NSApp terminate:strongSelf];
            }
        }
    });
    dispatch_release(requestQueue);
}

#pragma mark
#pragma mark Functions

NSString* settingsVersion()
{
    NSUserDefaults *storage = [NSUserDefaults standardUserDefaults];
    NSDictionary *res = [storage objectForKey:kAppDefaultsKey];
    if (res == nil) {
        res = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"settings" ofType:@"plist"]];
        NSMutableDictionary *general = [[res objectForKey:kGeneralKey] mutableCopy];
        [general setValue:[res valueForKey:@"v"] forKey:@"v"];
        [storage setObject:general forKey:kAppDefaultsKey];
        [storage synchronize];
    }
    return [res objectForKey:@"v"];
}

void updateAppSettingForNewVersion()
{
    NSUserDefaults *storage = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *existedSettings = [[storage objectForKey:kAppDefaultsKey] deepMutableCopy];
    NSDictionary *bundleSettings = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"settings" ofType:@"plist"]];
    
    NSDictionary *bundleGeneral = [bundleSettings objectForKey:kGeneralKey];
    for (NSString *key in [bundleGeneral allKeys]) {
        if (![existedSettings valueForKey:key]) {
            [existedSettings setValue:[bundleGeneral valueForKey:key] forKey:key];
        }
    }    
    [existedSettings setValue:[bundleSettings valueForKey:@"v"] forKey:@"v"];
    
    [storage removeObjectForKey:kAppDefaultsKey];
    [storage setObject:existedSettings forKey:kAppDefaultsKey];
    [storage synchronize];
}

void cleanAppSettings()
{
    NSUserDefaults *storage = [NSUserDefaults standardUserDefaults];
    [storage removeObjectForKey:kAppDefaultsKey];
    NSArray *keys = @[@"nowp.nexttrack.hotkey", @"nowp.prevtrack.hotkey", @"nowp.playpause.hotkey"];
    for (NSString *key in keys) {
        [storage removeObjectForKey:key];
    }
    [storage synchronize];
    
    NSString *serviceName = [[NSBundle mainBundle] bundleIdentifier];
    [SSKeychain deleteEntryForService:serviceName account:kVKServiceKey];
    [SSKeychain deleteEntryForService:serviceName account:kFBServiceKey];
    [SSKeychain deleteEntryForService:serviceName account:kTWServiceKey];
    [SSKeychain deleteEntryForService:serviceName account:kLFServiceKey];
}

@end
