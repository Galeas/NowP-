//
//  NPLoginController.m
//  NowP!
//
//  Created by Yevgeniy Kratko on 09.09.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import "NPLoginController.h"
#import "NSString+Extra.h"
#import <WebKit/WebKit.h>

@interface NPLoginController () <NSPopoverDelegate>
@property (weak) IBOutlet NSTabView *tabView;
@property (weak) IBOutlet WebView *webLoginView;

@property (weak) IBOutlet NSTextField *twUsernameField;
@property (weak) IBOutlet NSSecureTextField *twPasswordField;
@property (weak) IBOutlet NSPopover *myPopover;

@property (weak) IBOutlet NSTextField *lfUsernameField;
@property (weak) IBOutlet NSSecureTextField *lfPasswordField;


- (IBAction)cancelTWLogin:(id)sender;
- (IBAction)signInFBSite:(id)sender;
- (IBAction)connectFB:(id)sender;
- (IBAction)confirmFB:(id)sender;
- (IBAction)signInLF:(id)sender;
- (IBAction)cancelLF:(id)sender;
@end

@implementation NPLoginController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)dealloc
{
    [self setLoginURL:nil];
    [self setVkFbDelegate:nil];
    [self setTwitterDelegate:nil];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    NSString *str = [sender mainFrameURL];
    Service flag = kEmptyFlag;
    if ([[self.loginURL absoluteString] rangeOfString:@"oauth.vk.com"].location != NSNotFound) {
        flag = kVKFlag;
    }
    if ([[self.loginURL absoluteString] rangeOfString:@"facebook.com/dialog/oauth"].location != NSNotFound) {
        flag = kFBFlag;
    }
    BOOL respond = [self.vkFbDelegate respondsToSelector:@selector(getToken:userID:service:)];
    if ([str rangeOfString:@"access_token"].location != NSNotFound) {
        NSString *token = [str stringBetweenString:@"access_token=" andString:@"&"];
        NSString *uidstr = [str stringBetweenString:@"user_id=" andString:@""];
        NSInteger uid = [uidstr integerValue];
        if (respond) {
            [self.vkFbDelegate getToken:token userID:uid service:flag];
        }
    }
    else if ([str rangeOfString:@"error=access_denied"].location != NSNotFound) {
        if (respond) {
            [self.vkFbDelegate getToken:nil userID:NSNotFound service:flag];
        }
    }
}

- (void)signInTwitter
{
    [self.tabView selectTabViewItemAtIndex:1];
}

- (void)signInFacebook
{
    [self.tabView selectTabViewItemAtIndex:2];
}

- (void)signinVK
{
    [self.tabView selectTabViewItemAtIndex:0];
    NSString *loginURLString = [NSString stringWithFormat:@"https://oauth.vk.com/authorize?client_id=%@&scope=66570&redirect_uri=http://oauth.vk.com/blank.html&display=mobile&response_type=token", kVKAppKey];
    [self setLoginURL:[NSURL URLWithString:loginURLString]];
    [self.webLoginView.mainFrame loadRequest:[NSURLRequest requestWithURL:self.loginURL]];
}

- (void)signInLastFM
{
    [self.tabView selectTabViewItemAtIndex:3];
}

#pragma mark - Facebook

- (IBAction)signInFBSite:(id)sender
{
    [self.tabView selectTabViewItemAtIndex:0];
    NSSize size = NSMakeSize(480, 295);
    [self.myPopover setContentSize:size];
    NSString *loginURLString = [NSString stringWithFormat:@"https://www.facebook.com/dialog/oauth?client_id=%@&redirect_uri=https://www.facebook.com/connect/login_success.html&response_type=token&scope=user_status,publish_stream&display=popup", kFBAppKey];
    [self setLoginURL:[NSURL URLWithString:loginURLString]];
    [self.webLoginView.mainFrame loadRequest:[NSURLRequest requestWithURL:self.loginURL]];
}

- (IBAction)connectFB:(id)sender
{
    [[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/InternetAccounts.prefPane"];
}

- (IBAction)confirmFB:(id)sender
{
    if ([self.vkFbDelegate respondsToSelector:@selector(userDidConfirmOSXFacebookAccount)]) {
        [self.vkFbDelegate userDidConfirmOSXFacebookAccount];
    }
}

#pragma mark - LasstFM

- (IBAction)signInLF:(id)sender
{
    NSString *username = [self.lfUsernameField stringValue];
    NSString *password = [self.lfPasswordField stringValue];
    NSString *token = [[NSString stringWithFormat:@"%@%@", username, [password md5sum]] md5sum];
    NSMutableDictionary *requestInfo = [NSMutableDictionary dictionaryWithDictionary:@{ @"username":username, @"authToken":token, @"api_key":kLFAppKey, @"method":@"auth.getMobileSession" }];
    NSString *signature = [self generateSignatureFromDictionary:requestInfo];
    [requestInfo setValue:signature forKey:@"api_sig"];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"http://ws.audioscrobbler.com/2.0/" stringByAppendingString:@"?format=json"]]];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[self generatePOSTBodyFromDictionary:requestInfo]];
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        if (data && !error) {
            NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if ([response objectForKey:@"session"]) {
                NSMutableDictionary *buffer = [NSMutableDictionary dictionaryWithDictionary:[response objectForKey:@"session"]];
                [buffer addEntriesFromDictionary:@{@"screen_name":username, @"password":password}];
                if (weakSelf.lastFMDelegate && [weakSelf.lastFMDelegate respondsToSelector:@selector(lastFMDidSuccessfullLogin:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf.lastFMDelegate lastFMDidSuccessfullLogin:buffer];
                    });
                }
            }
            else {
                NSError *error = [NSError errorWithDomain:@"NowP::Error::LastFM" code:666 userInfo:@{ NSLocalizedDescriptionKey:NSLocalizedString([response valueForKey:@"message"], @"LastFM login error") }];
                if (weakSelf.lastFMDelegate && [weakSelf.lastFMDelegate respondsToSelector:@selector(lastFMDidLoginWithError:)]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf.lastFMDelegate lastFMDidLoginWithError:error];
                    });
                }
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

- (IBAction)cancelLF:(id)sender
{
    if (self.lastFMDelegate && [self.lastFMDelegate respondsToSelector:@selector(userDidCancelLastFMLogin)]) {
        [self.lastFMDelegate userDidCancelLastFMLogin];
    }
}

#pragma - Twitter

- (IBAction)approveTWLogin:(id)sender
{
    NSString *username = [self.twUsernameField stringValue];
    NSString *pass = [self.twPasswordField stringValue];
    if ([username length] > 0 && [pass length] > 0) {
        if (self.twitterDelegate && [self.twitterDelegate respondsToSelector:@selector(twitterUserDidEnterUsername:password:)]) {
            [self.twitterDelegate twitterUserDidEnterUsername:username password:pass];
        }
    }
    else {
        if (self.twitterDelegate && [self.twitterDelegate respondsToSelector:@selector(userDidConfirmOSXTwitterAccount)]) {
            [self.twitterDelegate userDidConfirmOSXTwitterAccount];
        }
    }
}

- (IBAction)cancelTWLogin:(id)sender
{
    if (self.twitterDelegate && [self.twitterDelegate respondsToSelector:@selector(userDidCancelTwitterLogin)]) {
        [self.twitterDelegate userDidCancelTwitterLogin];
    }
}


@end
