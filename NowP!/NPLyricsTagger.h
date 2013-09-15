//
//  NPLyricsTagger.h
//  NowP!
//
//  Created by Евгений Браницкий on 27.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import <Foundation/Foundation.h>

@class iTunesTrack;
@interface NPLyricsTagger : NSObject
- (id)initWithTrack:(iTunesTrack*)track;
- (void)runFromSender:(id)sender completion:(void(^)(NSString *lyrics, iTunesTrack *track))completion;
@property (strong, nonatomic) iTunesTrack *track;
@end
