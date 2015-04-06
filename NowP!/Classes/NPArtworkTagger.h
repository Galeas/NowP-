//
//  NPArtworkTagger.h
//  NowP!
//
//  Created by Yevgeniy Kratko on 11.12.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import <Foundation/Foundation.h>
@class iTunesTrack;
@interface NPArtworkTagger : NSObject
- (void)addTrack:(iTunesTrack*)track;
- (void)setArtworkSearchCompletion:(void (^)(NSImage *, iTunesTrack *, NSError*))completion;
@end
