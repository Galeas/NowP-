//
//  NPLyricsTagger.h
//  NowP!
//
//  Created by Evgeniy Kratko on 09.08.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import <Foundation/Foundation.h>
@class iTunesTrack;
@interface NPLyricsTagger : NSObject
- (void)addTrack:(iTunesTrack*)track;
- (void)setLyricsSearchCompletion:(void (^)(NSString *, iTunesTrack *, NSError*))completion;
@end
