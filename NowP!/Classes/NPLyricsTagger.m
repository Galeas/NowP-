//
//  NPLyricsTagger.m
//  NowP!
//
//  Created by Evgeniy Kratko on 09.08.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import "NPLyricsTagger.h"
//#import "HTMLParser.h"
#import "iTunes.h"
#import "NSString+Extra.h"
#import <GDataXML-HTML/GDataXMLNode.h>

#define LYRICS_WIKIA_REQUEST_STRING(artist,name) [NSString stringWithFormat:@"http://lyrics.wikia.com/api.php?artist=%@&song=%@&fmt=realjson", (artist), (name)]
#define LF_REQUEST_STRING(artist,name) [NSString stringWithFormat:@"http://api.lyricfind.com/lyric.do?apikey=e78b5a84c31a1e23e6997ad8908bbd4a&count=1&output=json&reqtype=offlineviews&trackid=artistname:%@,trackname:%@&useragent=Lyrically%%2F3.0.2%20%28iPad%%3B%%20iOS%%207.1.2%%3B%%20Scale%%2F2.00%%29", (artist), (name)];
#define MUSIXMATCH_REQUEST_STRING(artist,name) [NSString stringWithFormat:@"https://www.musixmatch.com/search/%@%%20%@/tracks", (artist), (name)]

@interface NPLyricsTagger ()
@property (copy) void (^_lyricsGetBlock)(NSString *, iTunesTrack*, NSError*);
@property (strong, nonatomic) dispatch_queue_t queue;
@end

@implementation NPLyricsTagger

- (id)init
{
    self = [super init];
    if (self) {
        [self setQueue:dispatch_queue_create("lyricsTagQueue", NULL)];
    }
    return self;
}

- (void)addTrack:(iTunesTrack *)track
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.queue, ^{
        [weakSelf searchLyrics:track];
    });
}

- (void)setLyricsSearchCompletion:(void (^)(NSString *, iTunesTrack *, NSError*))completion
{
    [self set_lyricsGetBlock:completion];
}

- (void)searchLyrics:(iTunesTrack*)track
{
    if (!track.artist && !track.name) {
        NSError *error = [NSError errorWithDomain:@"com.akki.NowP" code:13 userInfo:@{NSLocalizedDescriptionKey:@"Track artist or track title not read"}];
        self._lyricsGetBlock(nil, track, error);
        return;
    }
    NSString *artist = [track.artist stringUsingEncoding:NSUTF8StringEncoding];
    NSString *title = [track.name stringUsingEncoding:NSUTF8StringEncoding];
    BOOL success = NO;
    NSDictionary *info = @{@"artist":artist, @"title":title};
    NSString *lyrics = [self searchWithMM:info success:&success];
    if (!success) {
        lyrics = [self searchWithLW:info success:&success];
        if (!success) {
            lyrics = [self searchWithLW:info success:&success];
        }
    }
    if (lyrics && success) {
        lyrics = [NSString stringWithFormat:@"%@\n%@\n\n%@", track.name, track.artist, lyrics];
        [track setLyrics:lyrics];
        self._lyricsGetBlock(lyrics, track, nil);
    }
    else {
        NSError *error = [NSError errorWithDomain:@"com.akki.NowP" code:12 userInfo:@{NSLocalizedDescriptionKey:@"Track lyrics not found"}];
        self._lyricsGetBlock(nil, track, error);
    }
}

- (NSString*)searchWithMM:(NSDictionary*)info success:(BOOL*)success
{
    NSString *stringURL = MUSIXMATCH_REQUEST_STRING(info[@"artist"], info[@"title"]);
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:stringURL]];
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (!data || error) {
        *success = NO;
        return nil;
    }
    GDataXMLDocument *document = [[GDataXMLDocument alloc] initWithHTMLData:data error:&error];
    GDataXMLElement *content = (GDataXMLElement*)[[document rootElement] firstNodeForXPath:@"//*[@id=\"content\"]/div/div/div/div[@class=\"tab-content\"]" error:&error];
    GDataXMLElement *empty = (GDataXMLElement*)[content firstNodeForXPath:@"//*[@id=\"search-tracks\"]/div/div[@class=\"empty\"]" error:&error];
    if (empty && !error) {
        if ([[empty stringValue] isEqualToString:@"No tracks found"]) {
            *success = NO;
            return nil;
        }
    }
    GDataXMLElement *titleElement = (GDataXMLElement*)[content firstNodeForXPath:@"//*[@id=\"search-tracks\"]/div/div/ul/li/div/div/div/h2[@class=\"media-card-title\"]/a" error:&error];
    if (titleElement && !error) {
        NSString *tail = [[titleElement attributeForName:@"href"] stringValue];
        NSURL *trackURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.musixmatch.com%@", tail]];
        content = nil;
        empty = nil;
        
        data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:trackURL] returningResponse:NULL error:&error];
        if (data && !error) {
            document = [[GDataXMLDocument alloc] initWithHTMLData:data error:&error];
            GDataXMLElement *lyrics = (GDataXMLElement*)[[document rootElement] firstNodeForXPath:@"//*[@id=\"lyrics-html\"]" error:&error];
            if (lyrics && !error) {
                NSString *text = [lyrics stringValue];
                NSString *title = info[@"title"];
                title = (NSString*)CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapesUsingEncoding(NULL, (CFStringRef)title, (CFStringRef)@"!*'();:@&=+$,/?%#[]", kCFStringEncodingUTF8));
                if ([text hasPrefix:title] || [text hasPrefix:[NSString stringWithFormat:@"\"%@\"", title]]) {
                    text = [text hasPrefix:[NSString stringWithFormat:@"\"%@\"", title]] ? [text substringFromIndex:title.length + 4] : [text substringFromIndex:title.length + 2];
                }
                *success = YES;
                return text;
            }
            else if (!lyrics && !error) {
                lyrics = (GDataXMLElement*)[[document rootElement] firstNodeForXPath:@"//*[@id=\"lyrics\"]/h3[@class=\"lyrics-instrumental\"]" error:&error];
                if (lyrics) {
                    *success = YES;
                    return @"Instrumental";
                }
            }
        }
    }
    *success = NO;
    return nil;
}

- (NSString*)searchWithLF:(NSDictionary*)info success:(BOOL*)success
{
    NSString *stringURL = LF_REQUEST_STRING(info[@"artist"], info[@"title"]);
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:stringURL]];
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (!data || error) {
        *success = NO;
        return nil;
    }
    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
    if (!error) {
        NSString *text = [responseDict valueForKeyPath:@"track.lyrics"];
        if (text) {
            *success = YES;
            return text;
        }
    }
    return nil;
}

- (NSString*)searchWithLW:(NSDictionary*)info success:(BOOL*)success
{
    NSString *stringURL = LYRICS_WIKIA_REQUEST_STRING(info[@"artist"], info[@"title"]);
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:stringURL]];
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (!data || error) {
        *success = NO;
        return nil;
    }
    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&error];
    if (![[responseDict valueForKey:@"lyrics"] isEqualToString:@"Not found"]) {
        if ([[responseDict valueForKey:@"lyrics"] isEqualToString:@"Instrumental"]) {
            *success = YES;
            return @"Instrumental";
        }
        NSURL *lyricsURL = [NSURL URLWithString:[responseDict valueForKey:@"url"]];
        NSData *data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:lyricsURL] returningResponse:NULL error:&error];
        if (!error) {
            NSString *document = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            NSString *text = [self lyricsFromLWPage:document success:success];
            return text;
        }
    }
    else {
        NSString *artist = [responseDict valueForKey:@"artist"];
        const char *charArtist = [artist cStringUsingEncoding:NSISOLatin1StringEncoding];
        artist = [[NSString stringWithCString:charArtist encoding:NSUTF8StringEncoding] capitalizedString];
        NSString *song = [responseDict valueForKey:@"song"];
        const char *charSong = [song cStringUsingEncoding:NSISOLatin1StringEncoding];
        song = [[NSString stringWithCString:charSong encoding:NSUTF8StringEncoding] capitalizedString];
        NSString *requestString = [[NSString stringWithFormat:@"%@+%@", [artist stringUsingEncoding:NSUTF8StringEncoding], [song stringUsingEncoding:NSUTF8StringEncoding]] stringByReplacingOccurrencesOfCharacterSet:[NSCharacterSet whitespaceCharacterSet] withString:@"+"];
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://lyrics.wikia.com/Special:Search?search=%@&fulltext=Search&ns0=1&ns220=1#", requestString]];
        NSURLRequest *deepRequest = [NSURLRequest requestWithURL:url];
        NSData *deepData = [NSURLConnection sendSynchronousRequest:deepRequest returningResponse:NULL error:&error];
        if (deepData && !error) {
            GDataXMLDocument *document = [[GDataXMLDocument alloc] initWithHTMLData:deepData error:&error];
            if (!error) {
                NSArray *searchNodes = [[document rootElement] nodesForXPath:@"//*[@id=\"search-v2-form\"]/div/ul/li/article/h1/a" error:&error];
                if (!error) {
                    NSString *fingerprint = [NSString stringWithFormat:@"%@:%@", artist, song];
                    __weak typeof(self) weakSelf = self;
                    __block NSString *text = nil;
                    
                    void (^lBlock)(GDataXMLElement*, NSUInteger, BOOL*) = ^(GDataXMLElement *obj, NSUInteger idx, BOOL *stop) {
                        NSString *nodeName = [obj stringValue];
                        if ([nodeName isEqualToString:fingerprint] || *stop == YES) {
                            NSURL *pageURL = [NSURL URLWithString:[[obj attributeForName:@"href"] stringValue]];
                            if (pageURL) {
                                NSError *pageError = nil;
                                NSData *pageData = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:pageURL] returningResponse:NULL error:&pageError];
                                if (pageData && !pageError) {
                                    NSString *document = [[NSString alloc] initWithData:pageData encoding:NSUTF8StringEncoding];
                                    text = [weakSelf lyricsFromLWPage:document success:success];
                                }
                            }
                        }
                    };
                    
                    [searchNodes enumerateObjectsUsingBlock:lBlock];
                    if (!text) {
                        BOOL stop = YES;
                        lBlock([searchNodes firstObject], 0, &stop);
                    }
                    return text;
                }
            }
        }
    }
    return nil;
}

- (NSString*)lyricsFromLWPage:(NSString*)htmlString success:(BOOL*)success
{
    NSError *error = nil;
    GDataXMLDocument *document = [[GDataXMLDocument alloc] initWithHTMLString:htmlString error:&error];
    NSArray *textNodes = [[document rootElement] nodesForXPath:@"//*[@class=\"lyricbox\"]" error:&error];
    NSString *text = nil;
    if ([textNodes count] > 0 && !error) {
        text = [self lyricsFromLWNodes:textNodes];
    }
    if ([text length] == 0) { //Buggy HTML on LyricsWiki
        NSString *fixed = [self cleanedLWDocument:htmlString];
        if (fixed) {
            text = [self lyricsFromLWPage:fixed success:success];
            *success = YES;
        }
        else {
            text = nil;
            *success = NO;
        }
    }
    else {
        *success = YES;
    }
    return text;
}

- (NSString*)cleanedLWDocument:(NSString*)dirtyHTML
{
    NSString *html = [dirtyHTML copy];
    html = [html stringByReplacingOccurrencesOfString:@"<div class='lyricsbreak'></div>" withString:@""];
    NSUInteger lyricboxStart = [html rangeOfString:@"<div class='lyricbox'>"].location;
    if (lyricboxStart == NSNotFound) {
        lyricboxStart = [html rangeOfString:@"<div class=\"lyricbox\">"].location;
        if (lyricboxStart == NSNotFound) {
            return nil;
        }
    }
    NSUInteger lyricboxEnd = [html rangeOfString:@"</div>\n" options:0 range:NSMakeRange(lyricboxStart, [html length] - lyricboxStart)].location;
    html = [html substringWithRange:NSMakeRange(lyricboxStart, lyricboxEnd - lyricboxStart + 6)];
    BOOL found = YES;
    while (found) {
        NSString *script = [html stringBetweenString:@"<script>" andString:@"</script>"];
        if (script) {
            html = [html stringByReplacingOccurrencesOfString:script withString:@""];
            html = [html stringByReplacingCharactersInRange:[html rangeOfString:@"<script>"] withString:@""];
            html = [html stringByReplacingCharactersInRange:[html rangeOfString:@"</script>"] withString:@""];
        }
        else {
            found = NO;
        }
    }
    return html;
}

- (NSString*)lyricsFromLWNodes:(NSArray*)textNodes
{
    NSMutableString *text = [NSMutableString string];
    [[[textNodes firstObject] children] enumerateObjectsUsingBlock:^(GDataXMLNode *obj, NSUInteger idx, BOOL *stop) {
        if ([obj kind] == GDataXMLTextKind) {
            [text appendString:[obj stringValue]];
        }
        else if ([obj kind] == GDataXMLElementKind && [[obj XMLString] isEqualToString:@"<br/>"]) {
            [text appendString:@"\n"];
        }
    }];
    return [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString*)valueForRequest:(NSString*)pre
{
    NSMutableArray *components = [[pre componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] mutableCopy];
    for (int i = 0; i < [components count]; i++) {
        NSString *str = [components objectAtIndex:i];
        str = [str stringUsingEncoding:NSUTF8StringEncoding];
        [components replaceObjectAtIndex:i withObject:str];
    }
    return [components componentsJoinedByString:@" "];
}
@end
