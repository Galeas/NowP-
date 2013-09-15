//
//  VKDesktopLoginController.m
//  VKAPI
//
//  Created by Евгений Браницкий on 01.07.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NPLoginController.h"
#import "NSString+Extra.h"
#import <WebKit/WebKit.h>

@interface NPLoginController()
{
    __unsafe_unretained NSObject<VKFBLogin> *_loginDelegate;
}
@end

@implementation NPLoginController
@synthesize delegate = _loginDelegate;

- (void)windowDidLoad
{
    [super windowDidLoad];
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    [self.loginView.mainFrame loadRequest:[NSURLRequest requestWithURL:self.loginURL]];
}

- (void)dealloc
{
    [self setLoginURL:nil];
    [self setDelegate:nil];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    NSString *str = [sender mainFrameURL];
    ServiceFlag flag = kEmptyFlag;
    if ([[self.loginURL absoluteString] rangeOfString:@"oauth.vk.com"].location != NSNotFound) {
        flag = kVKFlag;
    }
    if ([[self.loginURL absoluteString] rangeOfString:@"facebook.com/dialog/oauth"].location != NSNotFound) {
        flag = kFBFlag;
    }
    if ([str rangeOfString:@"access_token"].location != NSNotFound) {
        NSString *token = [str stringBetweenString:@"access_token=" andString:@"&"];
        NSString *uidstr = [str stringBetweenString:@"user_id=" andString:@""];
        NSInteger uid = [uidstr integerValue];
        [self.delegate getToken:token userID:uid service:flag];
    }
    if ([str rangeOfString:@"error=access_denied"].location != NSNotFound) {
        [self.delegate getToken:nil userID:NSNotFound service:flag];
    }
}

@end
