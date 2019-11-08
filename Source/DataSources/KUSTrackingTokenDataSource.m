//
//  KUSTrackingTokenDataSource.m
//  Kustomer
//
//  Created by Daniel Amitay on 8/13/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSTrackingTokenDataSource.h"

#import "KUSObjectDataSource_Private.h"

@interface KUSTrackingTokenDataSource () <KUSObjectDataSourceListener> {
    BOOL _wantsReset;
}

@end

@implementation KUSTrackingTokenDataSource

#pragma mark - Lifecycle methods

- (instancetype)initWithUserSession:(KUSUserSession *)userSession
{
    self = [super initWithUserSession:userSession];
    if (self) {
        [self addListener:self];
    }
    return self;
}

#pragma mark - KUSObjectDataSource subclass methods

- (void)performRequestWithCompletion:(KUSRequestCompletion)completion
{
    NSString *endpoint = (_wantsReset ? @"/c/v1/tracking/tokens" : @"/c/v1/tracking/tokens/current");
    NSURL *URL = [self.userSession.requestManager URLForEndpoint:endpoint];
    KUSRequestType requestType = (_wantsReset ? KUSRequestTypePost : KUSRequestTypeGet);

    [self.userSession.requestManager performRequestType:requestType
                                                    URL:URL
                                                 params:@{}
                                          authenticated:NO
                                      additionalHeaders:[self _additionalHeaders]
                                             completion:completion];
}

- (Class)modelClass
{
    return [KUSTrackingToken class];
}

#pragma mark - Public methods

- (nullable NSString *)currentTrackingToken
{
    KUSTrackingToken *trackingTokenObj = self.object;
    return trackingTokenObj.token;
}

- (void)reset
{
    _wantsReset = YES;
    [self cancel];
    //TODO Swapna removing fetching of token again on reset
    //[self fetch];
}

#pragma mark - Internal methods

- (nullable NSDictionary *)_additionalHeaders
{
    NSString *currentTrackingToken = self.currentTrackingToken;
    if (currentTrackingToken) {
        return @{
            kKustomerTrackingTokenHeaderKey: currentTrackingToken
        };
    }
    NSString *cachedTrackingToken = [self.userSession.userDefaults trackingToken];
    if (cachedTrackingToken) {
        return @{
            kKustomerTrackingTokenHeaderKey: cachedTrackingToken
        };
    }
    return nil;
}

#pragma mark - KUSObjectDataSourceListener methods

- (void)objectDataSourceDidLoad:(KUSObjectDataSource *)dataSource
{
    _wantsReset = NO;

    NSString *currentTrackingToken = self.currentTrackingToken;
    if (currentTrackingToken) {
        [self.userSession.userDefaults setTrackingToken:currentTrackingToken];
    }
}

@end
