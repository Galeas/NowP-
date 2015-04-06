//
//  NPiTunesWorker.h
//  NowP!
//
//  Created by Evgeniy Kratko on 26.06.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import <Foundation/Foundation.h>

@class iTunesTrack;

enum iTunesState {
	iTunesStopped = 'kPSS',
	iTunesPlaying = 'kPSP',
	iTunesPaused = 'kPSp',
	iTunesFastForwarding = 'kPSF',
	iTunesRewinding = 'kPSR'
};
typedef enum iTunesState iTunesState;

extern NSString *const kArtworkKey;
extern NSString *const kArtworkKey_500px;
extern NSString *const kArtistKey;
extern NSString *const kTitleKey;
extern NSString *const kLyricsKey;
extern NSString *const kTrackIDKey;

@class NPiTunesWorker;
@protocol iTunesWorkerDelegate <NSObject>
- (void)worker:(NPiTunesWorker*)worker didUpdateTrack:(iTunesTrack*)track withInfo:(NSDictionary*)info;
- (void)worker:(NPiTunesWorker*)worker failedUpdateTrack:(iTunesTrack*)track error:(NSError*)error;
- (void)playerStoppedWithWoker:(NPiTunesWorker*)worker;
- (void)worker:(NPiTunesWorker*)worker startedWithLastTrack:(iTunesTrack*)track info:(NSDictionary*)info;
@end
@protocol iTunesStateDelegate <NSObject>
- (void)playerStateDidChange:(iTunesState)state;
@end

@interface NPiTunesWorker : NSObject
+ (instancetype)worker;
- (void)fetchCurrentTrackInfo;
- (void)backTrack;
- (void)nextTrack;
- (void)playPause;
- (iTunesState)playerState;
- (NSTimeInterval)currentTrackDuration;
- (NSTimeInterval)currentTrackPosition;
- (NSUInteger)currentTrackID;
@property (weak, nonatomic) NSObject<iTunesWorkerDelegate> *delegate;
@property (weak, nonatomic) NSObject<iTunesStateDelegate> *stateDelegate;
@end
