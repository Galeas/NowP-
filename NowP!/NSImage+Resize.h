//
//  NSImage+Resize.h
//  NowP!
//
//  Created by Евгений Браницкий on 13.08.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSImage (Resize)
- (NSImage*)imageByScalingProportionallyToSize:(NSSize)targetSize;
@end
