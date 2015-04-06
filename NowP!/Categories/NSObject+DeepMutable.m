//
//  NSObject+DeepMutable.m
//  VKAPI
//
//  Created by Евгений Браницкий on 03.05.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NSObject+DeepMutable.h"

@implementation NSObject (DeepMutable)
-(id)deepMutableCopy
{
    if ([self isKindOfClass:[NSArray class]]) {
        NSMutableArray *result = [NSMutableArray array];
        [(NSArray*)self enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [result addObject:[obj deepMutableCopy]];
        }];
        return result;
    }
    else if ([self isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        __weak typeof(self) weakSelf = self;
        [(NSDictionary*)self enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [result setObject:[[(NSDictionary*)weakSelf objectForKey:key] deepMutableCopy] forKey:key];
        }];
        return result;
    }
    else if ([self isKindOfClass:[NSSet class]]) {
        NSMutableSet *result = [NSMutableSet set];
        [(NSSet*)self enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
            [result addObject:[obj deepMutableCopy]];
        }];
        return result;
    }
#if MAKE_MUTABLE_COPIES_OF_NONCOLLECTION_OBJECTS
    else if ([self conformsToProtocol:@protocol(NSMutableCopying)]) {
        return [self mutableCopy];
    }
    else if ([self conformsToProtocol:@protocol(NSCopying)]) {
        return [self copy];
    }
#endif
    return self;
//    if ([self isKindOfClass:[NSArray class]]) {
//        NSArray *oldArray = (NSArray *)self;
//        NSMutableArray *newArray = [NSMutableArray array];
//        for (id obj in oldArray) {
//            [newArray addObject:[obj deepMutableCopy]];
//        }
//        return newArray;
//    } else if ([self isKindOfClass:[NSDictionary class]]) {
//        NSDictionary *oldDict = (NSDictionary *)self;
//        NSMutableDictionary *newDict = [NSMutableDictionary dictionary];
//        for (id obj in oldDict) {
//            [newDict setObject:[oldDict[obj] deepMutableCopy] forKey:obj];
//        }
//        return newDict;
//    } else if ([self isKindOfClass:[NSSet class]]) {
//        NSSet *oldSet = (NSSet *)self;
//        NSMutableSet *newSet = [NSMutableSet set];
//        for (id obj in oldSet) {
//            [newSet addObject:[obj deepMutableCopy]];
//        }
//        return newSet;
//#if MAKE_MUTABLE_COPIES_OF_NONCOLLECTION_OBJECTS
//    } else if ([self conformsToProtocol:@protocol(NSMutableCopying)]) {
//        // e.g. NSString
//        return [self mutableCopy];
//    } else if ([self conformsToProtocol:@protocol(NSCopying)]) {
//        // e.g. NSNumber
//        return [self copy];
//#endif
//    } else {
//        return self;
//    }
}
@end
