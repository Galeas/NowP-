//
//  NPArtworkTagger.m
//  NowP!
//
//  Created by Yevgeniy Kratko on 11.12.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import "NPArtworkTagger.h"
#import "iTunes.h"
#import "NSString+Extra.h"
#import <GDataXML-HTML/GDataXMLNode.h>

typedef NS_OPTIONS(NSUInteger, ArtworkCompletionMask) {
    NotCompleted = 0,
    LastFM = (0x1 << 1),
    Google = (0x1 << 2),
    MusixMatch = (0x1 << 3)
};

@interface NPArtworkTagger ()
@property (copy) void (^_artworkGetBlock)(NSImage *, iTunesTrack*, NSError*);
@property (strong, nonatomic) dispatch_queue_t queue;
@property (strong, nonatomic) NSMutableDictionary *_foundImages;
@property (assign, nonatomic) ArtworkCompletionMask completionMask;
@end

@implementation NPArtworkTagger

- (id)init
{
    self = [super init];
    if (self) {
        [self setQueue:dispatch_queue_create("artworkTagQueue", NULL)];
        [self set_foundImages:[NSMutableDictionary dictionary]];
    }
    return self;
}

- (void)addTrack:(iTunesTrack *)track
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.queue, ^{
        [weakSelf searchArtwork:track];
    });
}

- (void)setArtworkSearchCompletion:(void (^)(NSImage *, iTunesTrack *, NSError *))completion
{
    [self set_artworkGetBlock:completion];
}

- (void)searchArtwork:(iTunesTrack*)track
{
    [self setCompletionMask:NotCompleted];
    [self lastFMSearch:track];
}

- (void)lastFMSearch:(iTunesTrack*)track
{
    NSString *artist = track.artist;
    NSString *album = track.album;
    if (!artist && !album) {
        return;
    }
    NSString *stringURL = nil;
    if (album.length > 0) {
        NSInteger breakLocation = [album rangeOfCharacterFromSet:[NSCharacterSet punctuationCharacterSet]].location;
        if (breakLocation != NSNotFound) {
            album = [album substringToIndex:breakLocation];
        }
        stringURL = [NSString stringWithFormat:@"http://ws.audioscrobbler.com/2.0/?method=album.getinfo&api_key=%@&artist=%@&album=%@&format=json", kLFAppKey, [artist stringUsingEncoding:NSUTF8StringEncoding], [album stringUsingEncoding:NSUTF8StringEncoding]];
    }
    else {
        NSString *title = track.name;
        if (!title || title.length == 0) {
            return;
        }
        if (artist.length == 0) {
            NSArray *components = [title componentsSeparatedByString:@" - "];
            if ([components count] == 2) {
                artist = [components objectAtIndex:0];
                title = [components objectAtIndex:1];
            }
        }
        stringURL = [NSString stringWithFormat:@"http://ws.audioscrobbler.com/2.0/?method=track.getInfo&api_key=%@&artist=%@&track=%@&format=json", kLFAppKey, [artist stringUsingEncoding:NSUTF8StringEncoding], [title stringUsingEncoding:NSUTF8StringEncoding]];
    }
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:stringURL] cachePolicy:NSURLCacheStorageAllowedInMemoryOnly timeoutInterval:5];
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:&error];
    if (data && !error) {
        NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (responseDict && !error) {
            NSArray *imageURLs = [responseDict valueForKeyPath:@"track.album.image"];
            if (!imageURLs) {
                imageURLs = [responseDict valueForKeyPath:@"album.image"];
            }
            if (!imageURLs) {
                [self setCompletionMask:self.completionMask|LastFM];
                [self searchComplete];
                return;
            }
            NSMutableArray *images = [NSMutableArray arrayWithCapacity:[imageURLs count]];
            [imageURLs enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
                NSString *imageURLString = [obj valueForKey:@"#text"];
                NSURLRequest *imgRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:imageURLString] cachePolicy:NSURLCacheStorageAllowedInMemoryOnly timeoutInterval:5];
                NSURLResponse *imgResponse = nil;
                NSError *imgError = nil;
                NSData *imageData = [NSURLConnection sendSynchronousRequest:imgRequest returningResponse:&imgResponse error:&imgError];
                if (imageData && !imgError) {
                    NSImage *image = [[NSImage alloc] initWithData:imageData];
                    [images addObject:image];
                }
            }];
            
            if ([images count] > 0) {
                [self._foundImages setObject:images forKey:@"LF"];
            }
            [self setCompletionMask:self.completionMask|LastFM];
            [self searchComplete];
        }
    }
}

- (void)musixMatchSearch:(iTunesTrack*)track
{
    
}

- (void)searchComplete
{
    
}

@end
