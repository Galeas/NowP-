//
//  NPArtworkTagPopover.h
//  NowP!
//
//  Created by Евгений Браницкий on 28.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class iTunesTrack;

@protocol ArtworkHunter <NSObject>
- (void)artworkConfirmed:(NSImage*)artwork forTrack:(iTunesTrack*)track;
@end

@interface NPArtworkTagController : NSPopover
- (void)getArtwork:(iTunesTrack*)track sender:(NSView*)senderView lastFMAllowed:(BOOL)lfAllowed;
@property (unsafe_unretained) NSObject<ArtworkHunter> *artworkDelegate;
@property (strong, nonatomic) iTunesTrack *track;
@property (strong, nonatomic) NSDictionary *trackArtworks;
@end
