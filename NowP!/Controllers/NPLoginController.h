//
//  NPLoginController.h
//  NowP!
//
//  Created by Yevgeniy Kratko on 09.09.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum {
    kEmptyFlag = 0,
    kVKFlag = (0x1 << 1),
    kFBFlag = (0x1 << 2),
    kTWFlag = (0x1 << 3),
    kLFFlag = (0x1 << 4)
} Service;
typedef Service Service;

@protocol VKFBLogin <NSObject>
- (void)getToken:(NSString*)token userID:(NSInteger)uid service:(Service)service;
- (void)userDidConfirmOSXFacebookAccount;
@end

@protocol TWLogin <NSObject>
- (void)twitterUserDidEnterUsername:(NSString*)username password:(NSString*)password;
- (void)userDidConfirmOSXTwitterAccount;
- (void)userDidCancelTwitterLogin;
@end

@protocol LFLogin <NSObject>
- (void)lastFMDidSuccessfullLogin:(NSDictionary*)info;
- (void)lastFMDidLoginWithError:(NSError*)error;
- (void)lastFMUserDidEnterUsername:(NSString*)username password:(NSString *)password;
- (void)userDidCancelLastFMLogin;
@end

@class WebView;
@interface NPLoginController : NSViewController
@property (strong, nonatomic) NSURL *loginURL;
@property (weak, nonatomic) NSObject<VKFBLogin> *vkFbDelegate;
@property (weak, nonatomic) NSObject<TWLogin> *twitterDelegate;
@property (weak, nonatomic) NSObject<LFLogin> *lastFMDelegate;
- (void)signinVK;
- (void)signInTwitter;
- (void)signInFacebook;
- (void)signInLastFM;
@end
