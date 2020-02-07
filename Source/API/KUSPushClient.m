//
//  KUSPushClient.m
//  Kustomer
//
//  Created by Daniel Amitay on 8/20/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSPushClient.h"

#import <Pusher/Pusher.h>
#import <Pusher/PTPusherConnection.h>

#import "KUSAudio.h"
#import "KUSLog.h"
#import "KUSNotificationWindow.h"
#import "KUSUserSession.h"
#import "KUSTimer.h"
#import "KUSStatsManager.h"
#import "KUSChatMessagesDataSource_Private.h"

static const NSTimeInterval KUSShouldConnectToPusherRecencyThreshold = 60.0;
static const NSTimeInterval KUSLazyPollingTimerInterval = 30.0;
static const NSTimeInterval KUSActivePollingTimerInterval = 7.5;

@interface KUSPushClient () <KUSObjectDataSourceListener, KUSPaginatedDataSourceListener, PTPusherDelegate, KUSChatMessagesDataSourceListener,PTPusherPresenceChannelDelegate> {
    __weak KUSUserSession *_userSession;

    KUSTimer *_pollingTimer;
    PTPusher *_pusherClient;
    PTPusherChannel *_pusherChannel;
    PTPusherPrivateChannel *_chatActivityChannel;
    PTPusherPresenceChannel *_customerPresenceChannel;

    NSMutableDictionary<NSString *, KUSChatSession *> *_previousChatSessions;
    NSString *_pendingNotificationSessionId;
    
    BOOL _isPusherTrackingStarted;
    BOOL _didPusherLossPackets;
}

@property (nonatomic, strong, readwrite) id<KUSPushClientListener> listener;

@end

@implementation KUSPushClient

#pragma mark - Lifecycle methods

- (instancetype)initWithUserSession:(KUSUserSession *)userSession
{
    self = [super init];
    if (self) {
        _userSession = userSession;
        _isPusherTrackingStarted = NO;

        [_userSession.chatSessionsDataSource addListener:self];
        [_userSession.chatSettingsDataSource addListener:self];
        [_userSession.trackingTokenDataSource addListener:self];
        
        // Make lazy connection of polling with 30s on initialization
        [self _connectToChannelsIfNecessary];
    }
    return self;
}

- (void)dealloc
{
    [_pollingTimer invalidate];
    [_pusherClient unsubscribeAllChannels];
    [_pusherClient disconnect];
}

#pragma mark - Channel constructors

- (NSURL *)_pusherAuthURL
{
    return [_userSession.requestManager URLForEndpoint:@"/c/v1/pusher/auth"];
}

- (NSString *)_pusherChannelName
{
    KUSTrackingToken *trackingTokenObj = _userSession.trackingTokenDataSource.object;
    if (trackingTokenObj.trackingId) {
        return [NSString stringWithFormat:@"presence-external-%@-tracking-%@", _userSession.orgId, trackingTokenObj.trackingId];
    }
    return nil;
}

- (NSString *)_chatActivityChannelNameForSessionId:(NSString *)sessionId
{
    return [NSString stringWithFormat:@"private-external-%@-chat-activity-%@", _userSession.orgId, sessionId];
}

- (NSString *)_presenceChannelNameForCustomerId:(NSString *)customerId
{
    return [NSString stringWithFormat:@"external-%@-customer-activity-%@", _userSession.orgId, customerId];
}

#pragma mark - Internal methods

- (void)_connectToChannelsIfNecessary
{
    KUSChatSettings *chatSettings = _userSession.chatSettingsDataSource.object;
    if (_pusherClient == nil && chatSettings.pusherAccessKey) {
        if(chatSettings.pusherCluster.length > 0){
            _pusherClient = [PTPusher pusherWithKey:chatSettings.pusherAccessKey delegate:self encrypted:YES cluster:chatSettings.pusherCluster];
        }else{
            _pusherClient = [PTPusher pusherWithKey:chatSettings.pusherAccessKey delegate:self encrypted:YES];
        }
        _pusherClient.authorizationURL = [self _pusherAuthURL];
    }
    
    BOOL shouldConnectToPusher = _pusherClient && !_pusherClient.connection.isConnected;
    if (shouldConnectToPusher) {
        [_pusherClient connect];
    }
    if (!_isPusherTrackingStarted) {
        _isPusherTrackingStarted = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(KUSShouldConnectToPusherRecencyThreshold * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
           
            _isPusherTrackingStarted = NO;
            BOOL isPusherConnected = _pusherClient && _pusherClient.connection.isConnected;
            if(!isPusherConnected) {
                
                KUSLogPusher("Pusher Not connected");
                [_userSession.statsManager updateStats:^(BOOL sessionUpdated) {
                    // Get latest session on update to avoid packet loss during socket connection
                    if (sessionUpdated) {
                        _didPusherLossPackets = YES;
                        [_userSession.chatSessionsDataSource fetchLatest];
                    }
                    
                    [self _connectToChannelsIfNecessary];
                }];
            }else{
                KUSLogPusher("Pusher is connected");
            }
            
        });
    }
    
    NSString *pusherChannelName = [self _pusherChannelName];
    if (pusherChannelName && _pusherChannel == nil) {
        _pusherChannel = [_pusherClient subscribeToChannelNamed:pusherChannelName];
        [_pusherChannel bindToEventNamed:@"kustomer.app.chat.message.send"
                                  target:self
                                  action:@selector(_onPusherChatMessageSend:)];
        [_pusherChannel bindToEventNamed:@"kustomer.app.chat.session.end"
                                  target:self
                                  action:@selector(_onPusherChatSessionEnd:)];
    }
    
    [self _updatePollingTimer];
}

- (void)_updatePollingTimer
{
    // Connect or disconnect from pusher
    if (_pusherClient.connection.isConnected && _pusherChannel.isSubscribed) {
        // Stop polling
        if (_pollingTimer) {
            [_pollingTimer invalidate];
            _pollingTimer = nil;
            KUSLogPusher(@"Stopped polling timer");
        }
    } else {
        // We are not yet connected to pusher, setup an active polling timer
        // (in the event that connecting to pusher fails)
        if (_supportViewControllerPresented) {
            if (_pollingTimer == nil || _pollingTimer.timeInterval != KUSActivePollingTimerInterval) {
                [_pollingTimer invalidate];
                _pollingTimer = [KUSTimer scheduledTimerWithTimeInterval:KUSActivePollingTimerInterval
                                                                      target:self
                                                                    selector:@selector(_onPollTick)
                                                                     repeats:YES];
                KUSLogPusher(@"Started active polling timer");
            }
        } else {
            // Make sure we're polling lazily
            if (_pollingTimer == nil || _pollingTimer.timeInterval != KUSLazyPollingTimerInterval) {
                [_pollingTimer invalidate];
                _pollingTimer = [KUSTimer scheduledTimerWithTimeInterval:KUSLazyPollingTimerInterval
                                                                      target:self
                                                                    selector:@selector(_onPollTick)
                                                                     repeats:YES];
                KUSLogPusher(@"Started lazy polling timer");
            }
        }
        
    }
}

- (void)_onPollTick
{
    KUSLogPusher(@"Poll Tick called");
    [_userSession.statsManager updateStats:^(BOOL sessionUpdated) {
        // Get latest session on update
        if (sessionUpdated) {
            [_userSession.chatSessionsDataSource fetchLatest];
        }
    }];
}

- (void)_notifyForUpdatedChatSession:(NSString *)chatSessionId
{
    if (self.supportViewControllerPresented) {
        [KUSAudio playMessageReceivedSound];
    } else {
        KUSChatMessagesDataSource *chatMessagesDataSource = [_userSession chatMessagesDataSourceForSessionId:chatSessionId];
        KUSChatMessage *latestMessage = [chatMessagesDataSource latestMessage];
        KUSChatSession *chatSession = [_userSession.chatSessionsDataSource objectWithId:chatSessionId];
        if (chatSession == nil) {
            chatSession = [KUSChatSession tempSessionFromChatMessage:latestMessage];
            [_userSession.chatSessionsDataSource fetchLatest];
        }
        if ([_userSession.delegateProxy shouldDisplayInAppNotification] && chatSession) {
            BOOL shouldAutoDismiss = latestMessage.campaignId.length == 0;
            [KUSAudio playMessageReceivedSound];
            [[KUSNotificationWindow sharedInstance] showChatSession:chatSession autoDismiss:shouldAutoDismiss];
        }
    }
}

- (void)_fetchMessageById:(NSString *)messageId AndSessionId:(NSString *)sessionId
{
    NSString *messageEndpoint = [NSString stringWithFormat:@"/c/v1/chat/sessions/%@/messages/%@", sessionId, messageId];
    [_userSession.requestManager
     getEndpoint:messageEndpoint
     authenticated:YES
     completion:^(NSError *error, NSDictionary *response) {
         if (error != nil) {
             dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                 [self _fetchMessageById:messageId AndSessionId:sessionId];
             });
             return;
         }
         NSDictionary* json = response[@"data"];
         NSArray<KUSChatMessage *> *chatMessages = [KUSChatMessage objectsWithJSON:json];
         [self _upsertMessagesAndNotify:chatMessages];
     }];
}

- (void)_fetchEndedSessionById:(NSString *)sessionId
{
    [_userSession.requestManager
     getEndpoint: @"/c/v1/chat/sessions"
     authenticated:YES
     completion:^(NSError *error, NSDictionary *response) {
         if (error != nil) {
             dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                 [self _fetchEndedSessionById:sessionId];
             });
             return;
         }
         NSArray<KUSChatSession *> *chatSessions = [KUSChatSession objectsWithJSONs:response[@"data"]];
         for (KUSChatSession *session in chatSessions)
         {
             if ([sessionId isEqualToString:session.oid]) {
                 [self _upsertEndedSessionsAndNotify:@[session]];
                 break;
             }
         }
     }];
}

- (void)_upsertMessagesAndNotify:(NSArray<KUSChatMessage *> *)chatMessages
{
    KUSChatMessage *chatMessage = chatMessages.firstObject;
    KUSChatMessagesDataSource *messagesDataSource = [_userSession chatMessagesDataSourceForSessionId:chatMessage.sessionId];

    // Upsert the messages, but don't notify if we already have the objects
    BOOL doesNotAlreadyContainMessage = ![messagesDataSource objectWithId:chatMessage.oid];
    [messagesDataSource upsertNewMessages:chatMessages];
    if (doesNotAlreadyContainMessage) {
        [self _notifyForUpdatedChatSession:chatMessage.sessionId];
    }
}

- (void)_upsertEndedSessionsAndNotify:(NSArray<KUSChatSession *> *)chatSessions
{
    [_userSession.chatSessionsDataSource upsertNewSessions:chatSessions];
    KUSChatSettings *settings = [_userSession.chatSettingsDataSource object];
    if (settings.singleSessionChat) {
        // To update the UI of chat
        for (KUSChatSession *session in [_userSession.chatSessionsDataSource allObjects])
        {
            KUSChatMessagesDataSource *messagesDataSource = [_userSession chatMessagesDataSourceForSessionId:session.oid];
            [messagesDataSource notifyAnnouncersDidEndChatSession];
        }
    } else {
        
        KUSChatSession *chatSession = chatSessions.firstObject;
        KUSChatMessagesDataSource *messagesDataSource = [_userSession chatMessagesDataSourceForSessionId:chatSession.oid];
        [messagesDataSource notifyAnnouncersDidEndChatSession];
    }
}

#pragma mark - Public methods

- (void)onClientActivityTick
{
    // We only need to poll for client activity changes if we are not connected to the socket
    if (!_pusherClient.connection.connected || !_pusherChannel.isSubscribed) {
        [self _onPollTick];
    }
}

- (void)connectToChatActivityChannel:(NSString *)sessionId
{
    [self disconnectFromChatAcitvityChannel];
    
    NSString *chatActivityChannelName = [self _chatActivityChannelNameForSessionId:sessionId];
    _chatActivityChannel = (PTPusherPrivateChannel *) [_pusherClient subscribeToChannelNamed:chatActivityChannelName];
    [_chatActivityChannel bindToEventNamed:@"client-kustomer.app.chat.activity.typing"
                                    target:self
                                    action:@selector(_onPusherChatActivityTyping:)];
}

- (void)disconnectFromChatAcitvityChannel
{
    if (_chatActivityChannel) {
        [_chatActivityChannel unsubscribe];
        _chatActivityChannel = nil;
    }
}

- (void)sendChatActivityForSessionId:(NSString *)sessionId activityData:(NSDictionary *)activityData
{
    NSString *activityChannelName = [self _chatActivityChannelNameForSessionId:sessionId];
    if (![_chatActivityChannel.name isEqualToString:activityChannelName]) {
        [self connectToChatActivityChannel:sessionId];
    }
    
    [_chatActivityChannel triggerEventNamed:@"client-kustomer.app.chat.activity.typing"
                                       data:activityData];
}

- (void)connectToCustomerPresenceChannel:(NSString *)customerId
{
    if(nil == _customerPresenceChannel) {
        
        NSString *presenceChannelName = [self _presenceChannelNameForCustomerId:customerId];
        KUSLogPusher(@"Connecting to presence channel %@",presenceChannelName);
        _customerPresenceChannel = (PTPusherPresenceChannel *) [_pusherClient subscribeToPresenceChannelNamed:presenceChannelName];
    }
    
}

- (void)disconnectFromCustomerPresenceChannel
{
    if (_customerPresenceChannel) {
        KUSLogPusher(@"Disconnecting from presence channel");
        [_customerPresenceChannel unsubscribe];
        _customerPresenceChannel = nil;
    }
}

#pragma mark - Property methods

- (void)setSupportViewControllerPresented:(BOOL)supportViewControllerPresented
{
    _supportViewControllerPresented = supportViewControllerPresented;
    [self _connectToChannelsIfNecessary];
}

#pragma mark - Pusher event methods

- (void)_onPusherChatMessageSend:(PTPusherEvent *)event
{
    KUSLogPusher(@"Received chat message from Pusher");
    
    BOOL clippedEvent = event.data[@"clipped"];
    
    if (clippedEvent) {
        NSString *sessionId = NSStringFromKeyPath(event.data, @"data.relationships.session.data.id");
        NSString *messageId = NSStringFromKeyPath(event.data, @"data.id");
        KUSChatMessagesDataSource *messagesDataSource = [_userSession chatMessagesDataSourceForSessionId:sessionId];
        
        // Upsert the messages, but don't notify if we already have the objects
        BOOL doesNotAlreadyContainMessage = ![messagesDataSource objectWithId:messageId];
        if (doesNotAlreadyContainMessage) {
            [self _fetchMessageById:messageId AndSessionId:sessionId];
        }
    } else {
        NSArray<KUSChatMessage *> *chatMessages = [KUSChatMessage objectsWithJSON:event.data[@"data"]];
        [self _upsertMessagesAndNotify:chatMessages];
    }
}

- (void)_onPusherChatSessionEnd:(PTPusherEvent *)event
{
    KUSLogPusher(@"Ended chat session from Pusher");
    
    BOOL clippedEvent = event.data[@"clipped"];
    if (clippedEvent) {
        NSString *sessionId = NSStringFromKeyPath(event.data, @"data.id");
        [self _fetchEndedSessionById:sessionId];
    } else {
        NSArray<KUSChatSession *> *chatSessions = [KUSChatSession objectsWithJSON:event.data[@"data"]];
        [self _upsertEndedSessionsAndNotify:chatSessions];
    }
    
}

- (void)_onPusherChatActivityTyping:(PTPusherEvent *)event
{
    KUSLogPusher(@"Typing event from Pusher");
    
    BOOL shouldNotifyChange = _listener && [_listener respondsToSelector:@selector(pushClient:didChange:)];
    if (shouldNotifyChange) {
        KUSTypingIndicator *typingIndicator = [[KUSTypingIndicator alloc] initWithJSON:event.data];
        [_listener pushClient:self didChange:typingIndicator];
    }
}

#pragma mark - Listener methods

- (void)setListener:(id<KUSPushClientListener>)listener
{
    _listener = listener;
}

- (void)removeListener:(id<KUSPushClientListener>)listener
{
    if (_listener != listener) {
        return;
    }
    
    self.listener = nil;
}

#pragma mark - KUSObjectDataSourceListener methods

- (void)objectDataSourceDidLoad:(KUSObjectDataSource *)dataSource
{
    if (!_userSession.chatSessionsDataSource.didFetch) {
        [_userSession.chatSessionsDataSource fetchLatest];
    }
    [self _connectToChannelsIfNecessary];
}

#pragma mark - KUSPaginatedDataSourceListener methods

- (void)_updatePreviousChatSessions
{
    _previousChatSessions = [[NSMutableDictionary alloc] init];
    for (KUSChatSession *chatSession in _userSession.chatSessionsDataSource.allObjects) {
        [_previousChatSessions setObject:chatSession forKey:chatSession.oid];
    }
}

- (void)paginatedDataSourceDidLoad:(KUSPaginatedDataSource *)dataSource
{
    [self _updatePreviousChatSessions];

    if ([dataSource isKindOfClass:[KUSChatMessagesDataSource class]]) {
        KUSChatMessagesDataSource *chatMessagesDataSource = (KUSChatMessagesDataSource *)dataSource;
        if ([chatMessagesDataSource.sessionId isEqualToString:_pendingNotificationSessionId]) {
            [self _notifyForUpdatedChatSession:_pendingNotificationSessionId];
            _pendingNotificationSessionId = nil;
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self _connectToChannelsIfNecessary];
    });
}

- (void)paginatedDataSource:(KUSPaginatedDataSource *)dataSource didReceiveError:(NSError *)error
{
    if (dataSource == _userSession.chatSessionsDataSource) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [_userSession.chatSessionsDataSource fetchLatest];
        });
    }
    if ([dataSource isKindOfClass:[KUSChatMessagesDataSource class]]) {
        KUSChatMessagesDataSource *chatMessagesDataSource = (KUSChatMessagesDataSource *)dataSource;
        if ([chatMessagesDataSource.sessionId isEqualToString:_pendingNotificationSessionId]) {
            [self _notifyForUpdatedChatSession:_pendingNotificationSessionId];
            _pendingNotificationSessionId = nil;
        }
    }
}

- (void)paginatedDataSourceDidChangeContent:(KUSPaginatedDataSource *)dataSource
{
    if (dataSource == _userSession.chatSessionsDataSource) {
        // Only consider new messages here if we're actively polling
        if (_pollingTimer == nil && !_didPusherLossPackets) {
            // But update the state of _previousChatSessions
            [self _updatePreviousChatSessions];
            return;
        }

        _didPusherLossPackets = NO;
        NSString *updatedSessionId = nil;
        NSArray<KUSChatSession *> *newChatSessions = _userSession.chatSessionsDataSource.allObjects;
        for (KUSChatSession *chatSession in newChatSessions) {
            KUSChatSession *previousChatSession = [_previousChatSessions objectForKey:chatSession.oid];
            KUSChatMessagesDataSource *messagesDataSource = [_userSession chatMessagesDataSourceForSessionId:chatSession.oid];
            if (previousChatSession) {
                KUSChatMessage *latestChatMessage = messagesDataSource.allObjects.firstObject;
                BOOL isUpdatedSession = [chatSession.lastMessageAt compare:previousChatSession.lastMessageAt] == NSOrderedDescending;
                NSDate *sessionLastSeenAt = [_userSession.chatSessionsDataSource lastSeenAtForSessionId:chatSession.oid];
                BOOL lastSeenBeforeMessage = [chatSession.lastMessageAt compare:sessionLastSeenAt] == NSOrderedDescending;
                BOOL lastMessageAtNewerThanLocalLastMessage = latestChatMessage == nil || [chatSession.lastMessageAt compare:latestChatMessage.createdAt] == NSOrderedDescending;
                BOOL chatSessionSetToLock = chatSession.lockedAt != nil && ![chatSession.lockedAt isEqual:previousChatSession.lockedAt];
                
                // Check that new message arrived or not
                if (isUpdatedSession && lastSeenBeforeMessage && lastMessageAtNewerThanLocalLastMessage) {
                    updatedSessionId = chatSession.oid;
                    [messagesDataSource addListener:self];
                    [messagesDataSource fetchLatest];
                }
                // Check that session lock state changed
                else if (chatSessionSetToLock) {
                    [messagesDataSource fetchLatest];
                }
            } else if (_previousChatSessions != nil) {
                updatedSessionId = chatSession.oid;
                [messagesDataSource addListener:self];
                [messagesDataSource fetchLatest];
            }
        }

        [self _updatePreviousChatSessions];

        if (updatedSessionId) {
            _pendingNotificationSessionId = updatedSessionId;
        }
    }
}

#pragma mark - PTPusherDelegate methods

- (void)pusher:(PTPusher *)pusher connectionDidConnect:(PTPusherConnection *)connection
{
    KUSLogPusher(@"Pusher connection did connect");

    [self _updatePollingTimer];
    
    if(_didPusherLossPackets){
        [self _onPollTick];
    }
}

- (void)pusher:(PTPusher *)pusher connection:(PTPusherConnection *)connection didDisconnectWithError:(NSError *)error willAttemptReconnect:(BOOL)willAttemptReconnect
{
    if (error) {
        KUSLogPusherError(@"Pusher connection did disconnect with error: %@", error);
    } else {
        KUSLogPusher(@"Pusher connection did disconnect and willAttemptReconnect: %d",willAttemptReconnect);
    }

    [self _updatePollingTimer];
    _didPusherLossPackets = YES;
}

- (void)pusher:(PTPusher *)pusher connection:(PTPusherConnection *)connection failedWithError:(NSError *)error
{
    KUSLogPusherError(@"Pusher connection failed with error: %@", error);

    [self _updatePollingTimer];
}

- (void)pusher:(PTPusher *)pusher willAuthorizeChannel:(PTPusherChannel *)channel
withAuthOperation:(PTPusherChannelAuthorizationOperation *)operation
{
    [operation.mutableURLRequest setValue:_userSession.trackingTokenDataSource.currentTrackingToken
                       forHTTPHeaderField:kKustomerTrackingTokenHeaderKey];

    NSDictionary<NSString *, NSString *> *genericHTTPHeaderValues = [_userSession.requestManager genericHTTPHeaderValues];
    for (NSString *key in genericHTTPHeaderValues) {
        [operation.mutableURLRequest setValue:genericHTTPHeaderValues[key] forHTTPHeaderField:key];
    }
}

- (void)pusher:(PTPusher *)pusher didSubscribeToChannel:(PTPusherChannel *)channel
{
    KUSLogPusher(@"Pusher did subscribe to channel: %@", channel.name);
    
    [self _updatePollingTimer];
}

- (void)pusher:(PTPusher *)pusher didFailToSubscribeToChannel:(PTPusherChannel *)channel withError:(NSError *)error
{
    KUSLogPusherError(@"Pusher did fail to subscribe to channel: %@ with error: %@", channel.name, error);
    
    [self _updatePollingTimer];
}

#pragma mark PTPusherPresenceChannelDelegate methods

- (void)presenceChannelDidSubscribe:(PTPusherPresenceChannel *)channel {
    KUSLogPusher(@"presenceChannelDidSubscribe %@",channel);
}

- (void)presenceChannel:(PTPusherPresenceChannel *)channel memberAdded:(PTPusherChannelMember *)member {
    KUSLogPusher(@"presenceChannel memberAdded %@ - member %@",channel,member.userInfo);
}

- (void)presenceChannel:(PTPusherPresenceChannel *)channel memberRemoved:(PTPusherChannelMember *)member{
    KUSLogPusher(@"presenceChannel memberRemoved %@ - member %@",channel,member.userInfo);
}

@end
