//
//  KUSReachabilityManager.m
//  Kustomer
//
//  Created by BrainX Technologies on 25/03/2019.
//  Copyright © 2019 Kustomer. All rights reserved.
//

#import "KUSReachabilityManager.h"
#import "KUSReachability.h"
#import "Kustomer_Private.h"
#import "KUSUserSession.h"
#import "KUSStatsManager.h"
#import "KUSVolumeControlTimerManager.h"

@interface KUSReachabilityManager ()<KUSPaginatedDataSourceListener> {
    NSMutableDictionary<NSString *, KUSChatSession *> *_previousChatSessions;
}

@property (nonatomic) KUSReachability *internetReachability;

@end

@implementation KUSReachabilityManager


#pragma mark - Lifecycle methods

+ (KUSReachabilityManager *)sharedInstance
{
    static KUSReachabilityManager *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Public methods

- (void)startObservingNetworkChange
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    
    _internetReachability = [KUSReachability reachabilityForInternetConnection];
    [self.internetReachability startNotifier];
}

- (void)stopObservingNetworkChange
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.internetReachability stopNotifier];
    _internetReachability = nil;
}

- (KUSNetworkConnectionState)networkConnectionState
{
    if (_internetReachability == nil) {
        return KUSNetworkConnectionStateUndefined;
    }
    BOOL notConnected =  _internetReachability.currentReachabilityStatus == NotReachable;
    
    if (notConnected) {
        return KUSNetworkConnectionStateNotConnected;
    }
    return KUSNetworkConnectionStateConnected;
}

#pragma mark - Notification Listener for network state change

- (void)_reachabilityChanged:(NSNotification *)note
{
    KUSReachability* currentReachability = [note object];
    if ([currentReachability isKindOfClass:[KUSReachability class]]) {
        _internetReachability = currentReachability;
        KUSNetworkConnectionState connectionState = [self networkConnectionState];
        if (connectionState == KUSNetworkConnectionStateConnected) {
            [self _handleAppOnNetworkConnected];
            
        } else {
            [self _handleAppOnNetworkDisconnected];
        }
    }
}

#pragma mark - Internal methods

- (void)_handleAppOnNetworkConnected
{
    KUSUserSession *userSession = Kustomer.sharedInstance.userSession;
    [userSession.statsManager updateStats:^(BOOL sessionUpdated) {
        if (sessionUpdated) {
            [self _updatePreviousChatSessions];
            [userSession.chatSessionsDataSource addListener:self];
            [userSession.chatSessionsDataSource fetchLatest];
        } else {
            [[KUSVolumeControlTimerManager sharedInstance] resumeVCTimers];
        }
    }];
}

- (void)_handleAppOnNetworkDisconnected
{
    [[KUSVolumeControlTimerManager sharedInstance] pauseVCTimers];
}

- (void)_updatePreviousChatSessions
{
    _previousChatSessions = [[NSMutableDictionary alloc] init];
    KUSUserSession *userSession = Kustomer.sharedInstance.userSession;
    for (KUSChatSession *chatSession in userSession.chatSessionsDataSource.allObjects) {
        [_previousChatSessions setObject:chatSession forKey:chatSession.oid];
    }
}

#pragma mark - KUSPaginatedDataSourceListener methods

- (void)paginatedDataSourceDidLoad:(KUSPaginatedDataSource *)dataSource
{
    if ([dataSource isKindOfClass:[KUSChatSessionsDataSource class]]) {
        KUSUserSession *userSession = Kustomer.sharedInstance.userSession;
        [userSession.chatSessionsDataSource removeListener:self];
        [[KUSVolumeControlTimerManager sharedInstance] resumeVCTimers];
    }
}

- (void)paginatedDataSource:(KUSPaginatedDataSource *)dataSource didReceiveError:(NSError *)error
{
    if ([dataSource isKindOfClass:[KUSChatSessionsDataSource class]]) {
        KUSUserSession *userSession = Kustomer.sharedInstance.userSession;
        [userSession.chatSessionsDataSource removeListener:self];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [userSession.chatSessionsDataSource addListener:self];
            [userSession.chatSessionsDataSource fetchLatest];
        });
    }
}

- (void)paginatedDataSourceDidChangeContent:(KUSPaginatedDataSource *)dataSource
{
    if ([dataSource isKindOfClass:[KUSChatSessionsDataSource class]]) {
        KUSUserSession *userSession = Kustomer.sharedInstance.userSession;
        [userSession.chatSessionsDataSource removeListener:self];
        NSArray<KUSChatSession *> *newChatSessions = userSession.chatSessionsDataSource.allObjects;
        for (KUSChatSession *chatSession in newChatSessions) {
            KUSChatSession *previousChatSession = [_previousChatSessions objectForKey:chatSession.oid];
            KUSChatMessagesDataSource *messagesDataSource = [userSession chatMessagesDataSourceForSessionId:chatSession.oid];
            if (previousChatSession) {
                
                NSDate *previousSessionLastMessageAt = previousChatSession.lastMessageAt;
                BOOL isUpdatedSession;
                if (previousSessionLastMessageAt == nil) {
                    isUpdatedSession = true;
                } else {
                    isUpdatedSession = [chatSession.lastMessageAt compare:previousSessionLastMessageAt] == NSOrderedDescending;
                }
                NSDate *sessionLastSeenAt = [userSession.chatSessionsDataSource lastSeenAtForSessionId:chatSession.oid];
                BOOL lastSeenBeforeMessage = [chatSession.lastMessageAt compare:sessionLastSeenAt] == NSOrderedDescending;
                
                //removing this flag, since it is not fetching the agent messages which might have been sent before the last local message
                //KUSChatMessage *latestChatMessage = messagesDataSource.allObjects.firstObject;
                //BOOL lastMessageAtNewerThanLocalLastMessage = latestChatMessage == nil || [chatSession.lastMessageAt compare:latestChatMessage.createdAt] == NSOrderedDescending;
                
                BOOL chatSessionSetToLock = chatSession.lockedAt != nil && ![chatSession.lockedAt isEqual:previousChatSession.lockedAt];
                
                // Check that new message arrived or not
                if (isUpdatedSession && lastSeenBeforeMessage) {
                    [messagesDataSource fetchLatest];
                }
                // Check that session lock state changed
                else if (chatSessionSetToLock) {
                    [messagesDataSource fetchLatest];
                }
                else {
                    [[KUSVolumeControlTimerManager sharedInstance] resumeVCTimerForSession:chatSession.oid];
                }
            } else if (_previousChatSessions != nil) {
                [messagesDataSource fetchLatest];
            }
        }
    }
}

@end
