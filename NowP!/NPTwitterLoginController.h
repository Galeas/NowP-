//
//  NPTwitterLoginController.h
//  NowP!
//
//  Created by Евгений Браницкий on 08.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol TwitterLogin <NSObject>
- (void)twitterDidConfirmScreenName:(NSString*)name;
@end

@interface NPTwitterLoginController : NSWindowController
- (IBAction)nameConfirmation:(id)sender;
- (IBAction)close:(id)sender;
@property (assign, nonatomic) NSObject<TwitterLogin> *delegate;
@end
