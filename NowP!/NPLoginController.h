//
//  VKDesktopLoginController.h
//  VKAPI
//
//  Created by Евгений Браницкий on 01.07.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Keys.h"

@protocol VKFBLogin
- (void)getToken:(NSString*)token userID:(NSInteger)uid service:(ServiceFlag)service;
@end

@class WebView;
@interface NPLoginController : NSWindowController
@property (strong) NSURL *loginURL;
@property (weak) IBOutlet WebView *loginView;
@property (assign, nonatomic) NSObject<VKFBLogin> *delegate;
@end
