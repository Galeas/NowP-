//
//  NPLyricsTagger.m
//  NowP!
//
//  Created by Евгений Браницкий on 27.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NPLyricsTagger.h"
#import "NSString+Extra.h"
#import "NPiTunesController.h"
#import "NPStatusItemView.h"

#import "HTMLParser.h"

#define LYRICS_WIKIA_REQUEST_STRING(artist,name) [NSString stringWithFormat:@"http://lyrics.wikia.com/api.php?artist=%@&song=%@&fmt=realjson", (artist), (name)]

@interface NPLyricsTagger()
{
    void (^_lyricsGetBlock)(NSString *, iTunesTrack*);
    NPStatusItemView *_sender;
}
@end

@implementation NPLyricsTagger

- (id)initWithTrack:(iTunesTrack *)track
{
    self = [super init];
    if (self) {
        [self setTrack:track];
    }
    return self;
}

- (void)runFromSender:(id)sender completion:(void (^)(NSString *, iTunesTrack *))completion
{
    NSString *artist = self.track.artist;
    NSString *name = self.track.name;
    _lyricsGetBlock = [completion copy];
    if (!artist && !name) {
        _lyricsGetBlock(nil, self.track);
        return;
    }
    _sender = sender;
    NSString *stringURL = LYRICS_WIKIA_REQUEST_STRING([artist stringUsingEncoding:NSUTF8StringEncoding], [name stringUsingEncoding:NSUTF8StringEncoding]);
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:stringURL]];
    
    dispatch_queue_t senderQueue = dispatch_get_current_queue();
    dispatch_queue_t requestQueue = dispatch_queue_create("lyrics", NULL);
    __weak NPLyricsTagger *weakSelf = self;
    [_sender setLyricsProcessing:YES];
    dispatch_async(requestQueue, ^{
        NPLyricsTagger *strongSelf = weakSelf;
        if (!strongSelf) return;
        
        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        if (!error) {
            NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
            if (![[responseDict valueForKey:@"lyrics"] isEqualToString:@"Not found"]) {
                NSURL *lyricsURL = [NSURL URLWithString:[responseDict valueForKey:@"url"]];
                HTMLParser *parser = [[HTMLParser alloc] initWithContentsOfURL:lyricsURL error:&error];
                if (parser) {
                    HTMLNode *lyricBox = [[parser body] findChildWithAttribute:@"class" matchingName:@"lyricbox" allowPartial:NO];
                    
                    NSString *lyricString;
                    NSString *raw = [lyricBox rawContents];
                    HTMLNode *sorry = [lyricBox findChildTag:@"i"];
                    if (sorry) {
                        NSInteger lastDot = [[sorry contents] rangeOfString:@"." options:NSBackwardsSearch].location + 1;
                        NSString *sorryStr = [[sorry contents] substringToIndex:lastDot];
                        lyricString = [[[raw stringBetweenString:@"</div>" andString:@"<i>"] stringByReplacingOccurrencesOfString:@"<br>" withString:@"\n"] stringByAppendingFormat:@"\n%@",sorryStr];
                    }
                    HTMLNode *instrumental = [lyricBox findChildTag:@"b"];
                    if (instrumental) {
                        lyricString = [[instrumental contents] stringByAppendingString:@"\n"];
                    }
                    else {
                        lyricString = [[raw stringBetweenString:@"</div>" andString:@"<!--"] stringByReplacingOccurrencesOfString:@"<br>" withString:@"\n"];
                    }
                    lyricString = [[NSString stringWithFormat:@"%@\n%@\n\n",name, artist] stringByAppendingString:[lyricString stringByAppendingFormat:@"\n[ NowP! : %@ ]", [lyricsURL absoluteString]]];
                    [strongSelf.track setLyrics:lyricString];
                    dispatch_async(senderQueue, ^{
                        strongSelf->_lyricsGetBlock(lyricString, weakSelf.track);
                    });
                }
            }
        }
        [strongSelf->_sender setLyricsProcessing:NO];
        strongSelf->_lyricsGetBlock = nil;
    });
    dispatch_release(requestQueue);
}

@end
