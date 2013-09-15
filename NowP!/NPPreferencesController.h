//
//  NPPreferencesController.h
//  NowP!
//
//  Created by Евгений Браницкий on 21.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Keys.h"

@protocol PreferencesDelegate <NSObject>
- (void)preferencesDidSaved:(NSDictionary*)preferences;
@end

@interface NPPreferencesController : NSWindowController

+ (instancetype)preferences;

- (NSDictionary*)accountsSettings;
- (NSDictionary*)generalSettings;
- (NSInteger)accountsConfiguration;

@property (assign, nonatomic) BOOL showLyrics;
@property (assign, nonatomic) BOOL allowControl;
@property (assign, nonatomic) BOOL tagLyrics;
@property (assign, nonatomic) BOOL tagArtwork;
@property (assign, nonatomic) VKStatusRestoringPolicy vkStatusRestorePolicy;
@property (assign, nonatomic) BOOL allowSearchCoversOnLastFM;
@property (unsafe_unretained, nonatomic) NSObject<PreferencesDelegate> *delegate;

- (IBAction)defaultSettings:(id)sender;
- (IBAction)saveSettings:(id)sender;
@end
