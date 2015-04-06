//
//  NPiTunesWorker.m
//  NowP!
//
//  Created by Evgeniy Kratko on 26.06.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import "NPiTunesWorker.h"
#import "iTunes.h"

#import "NPLyricsTagger.h"
#import "NPArtworkTagger.h"
#import "NSImage+Resize.h"

NSString *const kArtworkKey = @"artwork";
NSString *const kArtworkKey_500px = @"artwork500";
NSString *const kArtistKey = @"artist";
NSString *const kTitleKey = @"title";
NSString *const kLyricsKey = @"lyrics";
NSString *const kTrackIDKey = @"id";

@interface NPiTunesWorker ()
@property (strong, nonatomic) iTunesApplication *iTunes;
@property (strong, nonatomic) NSMutableDictionary *currentTrackInfo;
@property (strong, nonatomic) NPLyricsTagger *_lTagger;
@property (strong, nonatomic) NPArtworkTagger *_aTagger;
@property (assign, nonatomic) BOOL justStarted;
@property (strong, nonatomic) id _iTunesObserver;
@end

@implementation NPiTunesWorker

+ (instancetype)worker
{
    static NPiTunesWorker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NPiTunesWorker alloc] init];
        [instance setITunes:[SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"]];
    });
    return instance;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self setJustStarted:YES];
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(fetchCurrentTrackInfo) name:@"com.apple.iTunes.playerInfo" object:nil];
        [self set_lTagger:[[NPLyricsTagger alloc] init]];
        [self set_aTagger:[[NPArtworkTagger alloc] init]];
        __weak typeof(self) weakSelf = self;
        
        [self._lTagger setLyricsSearchCompletion:^(NSString *lyrics, iTunesTrack *track, NSError *error) {
            NSDictionary *currentInfo = weakSelf.currentTrackInfo;
            if (weakSelf.iTunes.currentTrack.databaseID == track.databaseID) {
                if (error) {
                    if (weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(worker:failedUpdateTrack:error:)]) {
                        [weakSelf.delegate worker:weakSelf failedUpdateTrack:track error:error];
                    }
                }
                else {
                    [currentInfo setValue:lyrics forKey:kLyricsKey];
                    if (weakSelf.delegate && [weakSelf.delegate respondsToSelector:@selector(worker:didUpdateTrack:withInfo:)]) {
                        [weakSelf.delegate worker:weakSelf didUpdateTrack:track withInfo:currentInfo];
                    }
                }
            }
        }];
        
        [self._aTagger setArtworkSearchCompletion:^(NSImage *artwork, iTunesTrack *track, NSError *error) {
            DLog(@"%@", artwork);
        }];
    }
    return self;
}

#pragma mark
#pragma mark Info

- (iTunesState)playerState
{
    if ([self.iTunes isRunning]) {
        iTunesEPlS state = self.iTunes.playerState;
        return (iTunesState)state;
    }
    return iTunesStopped;
}

- (NSImage *)currentTrackImage
{
    [self fetchCurrentTrackInfo];
    return [self.currentTrackInfo valueForKey:kArtworkKey];
}

- (NSString *)currentTrackArtist
{
    [self fetchCurrentTrackInfo];
    return [self.currentTrackInfo valueForKey:kArtistKey];
}

- (NSString *)currentTrackTitle
{
    [self fetchCurrentTrackInfo];
    return [self.currentTrackInfo valueForKey:kTitleKey];
}

//- (NSInteger)currentTrackID
//{
//    return self._currentTrackID;
//}

- (NSTimeInterval)currentTrackDuration
{
    return self.iTunes.currentTrack.duration;
}

- (NSTimeInterval)currentTrackPosition
{
    return self.iTunes.playerPosition;
}

- (NSUInteger)currentTrackID
{
    return self.iTunes.currentTrack.databaseID;
}

- (void)fetchCurrentTrackInfo
{
    iTunesEPlS state = self.iTunes.playerState;
    if (self.stateDelegate && [self.stateDelegate respondsToSelector:@selector(playerStateDidChange:)]) {
        [self.stateDelegate playerStateDidChange:[self playerState]];
    }
    if (state == iTunesEPlSPlaying || state == iTunesEPlSPaused) {
        iTunesTrack *track = self.iTunes.currentTrack;
        NSInteger currentTrackID = track.databaseID;
        NSUInteger last = getLastTrackID();
        
        if (currentTrackID != last) {
            NSDictionary *info = [self fetchInfoForTrack:track];
            [self setCurrentTrackInfo:[info mutableCopy]];
            if (self.delegate && [self.delegate respondsToSelector:@selector(worker:didUpdateTrack:withInfo:)]) {
                [self.delegate worker:self didUpdateTrack:track withInfo:info];
            }
        }
        else if (self.justStarted) {
            NSDictionary *info = [self fetchInfoForTrack:track];
            [self setCurrentTrackInfo:[info mutableCopy]];
            [self setJustStarted:NO];
            if (self.delegate && [self.delegate respondsToSelector:@selector(worker:startedWithLastTrack:info:)]) {
                [self.delegate worker:self startedWithLastTrack:track info:info];
            }
        }
    }
    else if (state == iTunesEPlSStopped) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(playerStoppedWithWoker:)]) {
            [self.delegate playerStoppedWithWoker:self];
        }
    }
}

- (NSDictionary*)fetchInfoForTrack:(iTunesTrack*)track
{
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithCapacity:4];
    
    [info setValue:@(track.databaseID) forKey:kTrackIDKey];
    iTunesArtwork *artwork = [[track artworks] objectAtIndex:0];
    NSImage *image = nil;
    NSImage *bigImage = nil;
    id possibleImage = [artwork data];
    if (possibleImage) {
        if (![possibleImage isKindOfClass:[NSImage class]]) {
            NSAppleEventDescriptor *descriptor = (NSAppleEventDescriptor*)possibleImage;
            image = [[NSImage alloc] initWithData:[descriptor data]];
        }
        else {
            image = possibleImage;
        }
    }
#warning Убрать комменты
//    if (!image) {
//        image = [NSImage imageNamed:@"noartworkImage"];
        if (needTaggingForType(NPArtworkTagging)) {
            [self._aTagger addTrack:track];
//        }
    }
    else {
        image = [image imageByScalingProportionallyToSize:NSMakeSize(200, 200)];
        bigImage = [image imageByScalingProportionallyToSize:NSMakeSize(500, 500)];
        [info setValue:bigImage forKey:kArtworkKey_500px];
    }
    [info setValue:image forKey:kArtworkKey];
    
    BOOL isRadio = [[[track get] className] isEqualToString:@"ITunesURLTrack"];
    NSString *artist = nil;
    NSString *name = nil;
    if (isRadio) {
        NSString *description = [self.iTunes currentStreamTitle];
        if (description) {
            NSArray *components = [description componentsSeparatedByString:@" - "];
            if ([components count] == 2) {
                artist = [components objectAtIndex:0];
                name = [components objectAtIndex:1];
            }
            else {
                name = description;
                artist = @"";
            }
        }
        else {
            iTunesURLTrack *urlTrack = [track get];
            artist = @"Online radiostation";
            name = [urlTrack address];
        }
    }
    else {
        artist = track.artist;
        name = track.name;
        if (artist.length == 0) {
            NSArray *components = [name componentsSeparatedByString:@" - "];
            if ([components count] == 2) {
                artist = [components objectAtIndex:0];
                name = [components objectAtIndex:1];
#warning Проверка настроек
                [track setArtist:artist];
                [track setName:name];
            }
        }
    }
    [info setValue:artist forKey:kArtistKey];
    [info setValue:name forKey:kTitleKey];
    
    NSString *lyrics = track.lyrics;
    if ([lyrics length] == 0 && needTaggingForType(NPLyricsTagging)) {
#warning Проверка опций
        [self._lTagger addTrack:track];
    }
    else {
        [info setValue:lyrics forKey:kLyricsKey];
    }
    
    return info;
}

#pragma mark
#pragma mark Control

- (void)backTrack
{
    [self.iTunes backTrack];
}

- (void)nextTrack
{
    [self.iTunes nextTrack];
}

- (void)playPause
{
    [self.iTunes playpause];
}

@end
