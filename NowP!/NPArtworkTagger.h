//
//  NPArtworkTagger.h
//  NowP!
//
//  Created by Евгений Браницкий on 28.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString *const kGoogleImages = @"google";
static NSString *const kLastFMImages = @"lastfm";

@class iTunesTrack;
@interface NPArtworkTagger : NSObject
- (id)initWithTrack:(iTunesTrack*)track;
- (void)runWithCompletion:(void(^)(NSDictionary* possibleArtworks))completion;
@property (strong, nonatomic) iTunesTrack *track;
@property (assign, nonatomic) BOOL googleImages;
@property (assign, nonatomic) BOOL lastFM;
@end
