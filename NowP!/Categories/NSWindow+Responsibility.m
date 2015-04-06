//
//  NSWindow+Responsibility.m
//  NowP!
//
//  Created by Yevgeniy Kratko on 10.09.14.
//  Copyright (c) 2014 Yevgeniy Kratko (Branitsky). All rights reserved.
//

#import "NSWindow+Responsibility.h"

@implementation NSWindow (Responsibility)
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
- (BOOL)canBecomeKeyWindow
{
    return YES;
}
#pragma clang diagnostic pop
@end
