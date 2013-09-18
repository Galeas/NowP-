//
//  NPArtworkTagger.m
//  NowP!
//
//  Created by Евгений Браницкий on 28.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NPArtworkTagger.h"
#import "NPiTunesController.h"

#import "NSString+Extra.h"
#import "HTMLParser.h"

#define kMinArtworkSize 450
#define GoogleImagesSearchURL(artist, album, title) [NSString stringWithFormat:@"http://www.google.com/search?site=imghp&tbm=isch&source=hp&q=%@+%@+%@&tbs=isz:m", (artist), (album), (title)]

static NSString *const kLastFMAPIKey = @"842f9a0390954bf47248f25a44adfba9";

@interface NPArtworkTagger()
{
    void (^_artworkGetBlock)(NSDictionary *);
    NSMutableDictionary *_foundImages;
}
@end

@implementation NPArtworkTagger

- (id)initWithTrack:(iTunesTrack *)track
{
    self = [super init];
    if (self) {
        [self setTrack:track];
    }
    return self;
}

- (void)runWithCompletion:(void (^)(NSDictionary *))completion
{
    _artworkGetBlock = [completion copy];
    if (self.googleImages)
        [self googleImagesSearch];
    if (self.lastFM)
        [self lastFMSearch];
}

- (void)googleImagesSearch
{
    NSString *artist = self.track.artist;
    NSString *album = self.track.album;
    NSString *title = self.track.name;
    if (!artist && !album) {
        return;
    }
    if (album.length > 0) {
        NSInteger breakLocation = [album rangeOfCharacterFromSet:[NSCharacterSet punctuationCharacterSet]].location;
        if (breakLocation != NSNotFound) {
            album = [album substringToIndex:breakLocation];
        }
    }
    else {
        NSString *title = self.track.name;
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
    }
    
    if (!_foundImages) {
        _foundImages = [NSMutableDictionary dictionary];
    }
    
    NSString *stringURL = GoogleImagesSearchURL([artist stringUsingEncoding:NSUTF8StringEncoding], [album stringUsingEncoding:NSUTF8StringEncoding], [title stringUsingEncoding:NSUTF8StringEncoding]);
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:stringURL]];
    __weak NPArtworkTagger *weakSelf = self;
    
    dispatch_queue_t senderQueue = dispatch_get_current_queue();
    dispatch_queue_t googleQueue = dispatch_queue_create("google", NULL);
    dispatch_async(googleQueue, ^{
        NPArtworkTagger *strongSelf = weakSelf;
        if (!strongSelf) return;
        
        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *searchData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        if (searchData && !error) {
            HTMLParser *parser = [[HTMLParser alloc] initWithData:searchData error:&error];
            if (parser) {
                HTMLNode *sourceNode = [[parser body] findChildWithAttribute:@"id" matchingName:@"ires" allowPartial:NO];
                NSArray *sources = [sourceNode findChildTags:@"a"];
                NSMutableArray *possible = [NSMutableArray array];
                for (HTMLNode *node in sources) {
                    NSString *href = [node getAttributeNamed:@"href"];
                    NSString *imageURLString = [href stringBetweenString:@"imgurl=" andString:@"&"];
                    if (imageURLString.length > 0) {
                        response = nil;
                        NSData *imageData = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:imageURLString] cachePolicy:NSURLCacheStorageAllowedInMemoryOnly timeoutInterval:3] returningResponse:&response error:&error];
                        if (imageData && !error) {
                            NSImage *possibleImage = [[NSImage alloc] initWithData:imageData];
                            if (possibleImage) {
                                NSImageRep *imgRep = [[possibleImage representations] objectAtIndex:0];
                                if ([imgRep pixelsWide] >= kMinArtworkSize && [imgRep pixelsHigh] >= kMinArtworkSize - 50) {
                                    [possible addObject:possibleImage];
                                }
                            }
                        }
                    }
                }
                if ([possible count] > 0)
                    [strongSelf->_foundImages setObject:[NSArray arrayWithArray:possible] forKey:kGoogleImages];
                [strongSelf setGoogleImages:NO];
                dispatch_async(senderQueue, ^{
                    [strongSelf searchComplete];
                });
            }
        }
    });
    dispatch_release(googleQueue);
}

- (void)lastFMSearch
{
    NSString *artist = self.track.artist;
    NSString *album = self.track.album;
    if (!artist && !album) {
        return;
    }
    NSString *stringURL = nil;
    if (album.length > 0) {
        NSInteger breakLocation = [album rangeOfCharacterFromSet:[NSCharacterSet punctuationCharacterSet]].location;
        if (breakLocation != NSNotFound) {
            album = [album substringToIndex:breakLocation];
        }
        stringURL = [NSString stringWithFormat:@"http://ws.audioscrobbler.com/2.0/?method=album.getinfo&api_key=%@&artist=%@&album=%@&format=json", kLastFMAPIKey, [artist stringUsingEncoding:NSUTF8StringEncoding], [album stringUsingEncoding:NSUTF8StringEncoding]];
    }
    else {
        NSString *title = self.track.name;
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
        stringURL = [NSString stringWithFormat:@"http://ws.audioscrobbler.com/2.0/?method=track.getInfo&api_key=%@&artist=%@&track=%@&format=json", kLastFMAPIKey, [artist stringUsingEncoding:NSUTF8StringEncoding], [title stringUsingEncoding:NSUTF8StringEncoding]];
    }
    
    if (!_foundImages) {
        _foundImages = [NSMutableDictionary dictionary];
    }

    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:stringURL] cachePolicy:NSURLCacheStorageAllowedInMemoryOnly timeoutInterval:5];
    
    __weak NPArtworkTagger *weakSelf = self;
    dispatch_queue_t senderQueue = dispatch_get_current_queue();
    dispatch_queue_t lastFMQueue = dispatch_queue_create("lastFM", NULL);
    dispatch_async(lastFMQueue, ^{
        NPArtworkTagger *strongSelf = weakSelf;
        if (!strongSelf) return;
        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        if (data && !error) {
            NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (responseDict && !error) {
                NSArray *imageURLs = [responseDict valueForKeyPath:@"track.album.image"];
                if (!imageURLs) {
                    imageURLs = [responseDict valueForKeyPath:@"album.image"];
                }
                if (!imageURLs) {
                    [strongSelf setLastFM:NO];
                    dispatch_async(senderQueue, ^{
                        [strongSelf searchComplete];
                    });
                    return;
                }
                NSMutableArray *images = [NSMutableArray arrayWithCapacity:imageURLs.count];
                for (NSDictionary *imageDict in imageURLs) {
                    NSString *imageURLString = [imageDict valueForKey:@"#text"];
                    NSURLRequest *imgRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:imageURLString] cachePolicy:NSURLCacheStorageAllowedInMemoryOnly timeoutInterval:5];
                    NSURLResponse *imgResponse = nil;
                    NSError *imgError = nil;
                    NSData *imageData = [NSURLConnection sendSynchronousRequest:imgRequest returningResponse:&imgResponse error:&imgError];
                    if (imageData && !imgError) {
                        NSImage *image = [[NSImage alloc] initWithData:imageData];
                        [images addObject:image];
                    }
                }
                if ([images count] > 0)
                    [strongSelf->_foundImages setObject:[NSArray arrayWithArray:images] forKey:kLastFMImages];
                [strongSelf setLastFM:NO];
                dispatch_async(senderQueue, ^{
                    [strongSelf searchComplete];
                });
            }
        }
    });
    dispatch_release(lastFMQueue);
}

- (void)searchComplete
{
    if (!self.googleImages && !self.lastFM) {
        if ([_foundImages count] > 0) {
            _artworkGetBlock([NSDictionary dictionaryWithDictionary:_foundImages]);
        }
        else {
            _artworkGetBlock(nil);
        }
    }
}

@end
