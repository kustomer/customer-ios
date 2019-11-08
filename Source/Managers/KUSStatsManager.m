//
//  KUSStatsManager.m
//  Kustomer
//
//  Created by BrainX Technologies on 27/03/2019.
//  Copyright © 2019 Kustomer. All rights reserved.
//

#import "KUSStatsManager.h"

@interface KUSStatsManager () <KUSPaginatedDataSourceListener, KUSChatMessagesDataSourceListener> {
    __weak KUSUserSession *_userSession;
    NSDate *_lastActivity;
}

@end

@implementation KUSStatsManager

#pragma mark - Lifecycle methods

- (instancetype)initWithUserSession:(KUSUserSession *)userSession
{
    self = [super init];
    if (self) {
        _userSession = userSession;
    }
    return self;
}

#pragma mark - Public methods

- (void)updateStats:(void (^)(BOOL sessionUpdated))completion
{
    // Fetch last activity time of the client
    
    [self getStats:^(NSDate *lastActivity) {
        BOOL sessionUpdated = (_lastActivity == nil && lastActivity != nil) || ([_lastActivity compare:lastActivity] != NSOrderedSame);
        _lastActivity = lastActivity;
        completion(sessionUpdated);
    }];
}


-(void) getStats:(void (^)(NSDate* lastActivity))completion {
    
    [_userSession.requestManager
    getEndpoint:@"/c/v1/chat/customers/stats"
    authenticated:YES
    completion:^(NSError *error, NSDictionary *response) {
        if (error != nil) {
            completion(false);
            return;
        }
        NSDictionary* json = response[@"data"];
        NSDate* lastActivity = DateFromKeyPath(json, @"attributes.lastActivity");
    
        completion(lastActivity);
    }];
}

@end
