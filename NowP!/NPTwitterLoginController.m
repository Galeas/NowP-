//
//  NPTwitterLoginController.m
//  NowP!
//
//  Created by Евгений Браницкий on 08.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NPTwitterLoginController.h"

@interface NPTwitterLoginController () <NSTextFieldDelegate>
{
    __unsafe_unretained NSObject<TwitterLogin> *_delegate;
    NSString *_screenName;
}
@end

@implementation NPTwitterLoginController

@synthesize delegate = _delegate;

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    _screenName = [obj.object stringValue];
}

- (IBAction)nameConfirmation:(id)sender
{
    [self.delegate twitterDidConfirmScreenName:_screenName];
}

- (IBAction)close:(id)sender
{
    [NSApp endSheet:[self window] returnCode:NSCancelButton];
}

- (void)dealloc
{
    _delegate = nil;
}
@end
