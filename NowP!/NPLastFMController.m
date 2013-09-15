//
//  NPLastFMController.m
//  NowP!
//
//  Created by Евгений Браницкий on 11.09.13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NPLastFMController.h"
#import "NSString+Extra.h"

static NSString *const kLastFMAPIKey = @"842f9a0390954bf47248f25a44adfba9";
#warning LastFM Secret
static NSString *const kLastFMSecret = @"LASTFM_SECRET";

static NSString *const kLastFMLoginDomain = @"kLastFMLoginDomain";

@interface NPLastFMController()
{
    void (^_completionHandler)(NSDictionary*, NSError*);
}
@end

@implementation NPLastFMController

+ (BOOL)scrobbleArtist:(NSString *)artist title:(NSString *)title sessionKey:(NSString *)sessionKey
{
    NSInteger timestamp = [[NSDate date] timeIntervalSince1970];
    NSMutableDictionary *requestInfo = [NSMutableDictionary dictionaryWithDictionary:@{@"artist[0]":artist, @"track[0]":title, @"api_key":kLastFMAPIKey, @"sk":sessionKey, @"method":@"track.scrobble", @"timestamp[0]":@(timestamp)}];
    NPLastFMController *instance = [[self alloc] init];
    NSString *signature = [instance generateSignatureFromDictionary:requestInfo];
    [requestInfo setValue:signature forKey:@"api_sig"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"http://ws.audioscrobbler.com/2.0/" stringByAppendingString:@"?format=json"]] cachePolicy:NSURLCacheStorageAllowedInMemoryOnly timeoutInterval:5];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[instance generatePOSTBodyFromDictionary:requestInfo]];
    
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if (data && !error) {
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (![dict valueForKey:@"error"]) {
            return YES;
        }
    }
    return NO;
}

static NSInteger sortAlpha(NSString *n1, NSString *n2, void *context) {
	return [n1 caseInsensitiveCompare:n2];
}

- (void)loginModalForWindow:(NSWindow *)parentWindow completion:(void (^)(NSDictionary *, NSError *))completion
{
    _completionHandler = [completion copy];
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Login"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setMessageText:@"Please enter username and password"];
    [alert setInformativeText:@"NowP! will login you on LastFM"];
    [alert setAlertStyle:NSInformationalAlertStyle];
    
    NSTextField *usernameTextField = [[NSTextField alloc] initWithFrame:NSMakeRect(0,32, 180, 24)];
    [usernameTextField setTag:1];
    NSSecureTextField *passwordTextField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 180, 24)];
    [passwordTextField setTag:2];
    NSView *accessoryView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 64)];
    [accessoryView addSubview:usernameTextField];
    [accessoryView addSubview:passwordTextField];
    [alert setAccessoryView:accessoryView];
    
    [alert beginSheetModalForWindow:parentWindow modalDelegate:self didEndSelector:@selector(loginAlertDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)loginAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(NSDictionary *)contextInfo
{
    NSString *username = [[[alert accessoryView] viewWithTag:1] stringValue];
    NSString *password = [[[alert accessoryView] viewWithTag:2] stringValue];
    NSString *token = [[NSString stringWithFormat:@"%@%@", username, [password md5sum]] md5sum];
    NSMutableDictionary *requestInfo = [NSMutableDictionary dictionaryWithDictionary:@{ @"username":username, @"authToken":token, @"api_key":kLastFMAPIKey, @"method":@"auth.getMobileSession" }];
    NSString *signature = [self generateSignatureFromDictionary:requestInfo];
    [requestInfo setValue:signature forKey:@"api_sig"];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[@"http://ws.audioscrobbler.com/2.0/" stringByAppendingString:@"?format=json"]]];
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:[self generatePOSTBodyFromDictionary:requestInfo]];
    
    dispatch_queue_t requestQueue = dispatch_queue_create("lastFM", NULL);
    dispatch_queue_t senderQueue = dispatch_get_current_queue();
    __weak NPLastFMController *weakSelf = self;
    dispatch_async(requestQueue, ^{
        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        if (data && !error) {
            NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            dispatch_async(senderQueue, ^{
                NPLastFMController *strongSelf = weakSelf;
                if (!strongSelf) return;
                if ([response objectForKey:@"session"]) {
                    NSMutableDictionary *buffer = [NSMutableDictionary dictionaryWithDictionary:[response objectForKey:@"session"]];
                    [buffer setValue:username forKey:@"screen_name"];
                    [buffer setValue:password forKey:@"password"];
                    strongSelf->_completionHandler(buffer, nil);
                }
                else {
                    strongSelf->_completionHandler(nil, [NSError errorWithDomain:kLastFMLoginDomain code:666 userInfo:@{ NSLocalizedDescriptionKey:NSLocalizedString([response valueForKey:@"message"], @"LastFM login error") }]);
                }
            });
        }
    });
    dispatch_release(requestQueue);
}

- (NSString *)generateSignatureFromDictionary:(NSDictionary *)dict {
	NSMutableArray *aMutableArray = [[NSMutableArray alloc] initWithArray:[dict allKeys]];
	NSMutableString *rawSignature = [[NSMutableString alloc] init];
	[aMutableArray sortUsingFunction:sortAlpha context:(__bridge void *)(self)];
	
	for(NSString *key in aMutableArray) {
		[rawSignature appendString:[NSString stringWithFormat:@"%@%@", key, [dict objectForKey:key]]];
	}
	
	[rawSignature appendString:kLastFMSecret];
	
	NSString *signature = [rawSignature md5sum];
	return signature;
}

- (NSData *)generatePOSTBodyFromDictionary:(NSDictionary *)dict {
	NSMutableString *rawBody = [[NSMutableString alloc] init];
	NSMutableArray *aMutableArray = [[NSMutableArray alloc] initWithArray:[dict allKeys]];
	[aMutableArray sortUsingFunction:sortAlpha context:(__bridge void *)(self)];
	
	for(NSString *key in aMutableArray) {
		[rawBody appendString:[NSString stringWithFormat:@"&%@=%@", key, [dict objectForKey:key]]];
	}
	NSString *body = [NSString stringWithString:rawBody];	
	return [body dataUsingEncoding:NSUTF8StringEncoding];
}

@end
