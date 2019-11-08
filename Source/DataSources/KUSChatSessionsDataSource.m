//
//  KUSChatSessionsDataSource.m
//  Kustomer
//
//  Created by Daniel Amitay on 7/22/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSChatSessionsDataSource.h"
#import "KUSPaginatedDataSource_Private.h"

#import "KUSDate.h"
#import "KUSLog.h"

@interface KUSChatSession (SortDate)

- (NSDate *)sortDate;

@end

@interface KUSChatSessionsDataSource () <KUSChatMessagesDataSourceListener, KUSObjectDataSourceListener> {
    NSDictionary<NSString *, NSObject *> *_pendingCustomChatSessionAttributes;
    NSDictionary<NSString *, NSObject *> *_pendingCustomChatSessionAttributesForNextConversation;
    NSMutableDictionary<NSString *, NSDate *> *_localLastSeenAtBySessionId;
    BOOL _isNewSession;
}

@end

@implementation KUSChatSessionsDataSource

#pragma mark - Lifecycle methods

- (instancetype)initWithUserSession:(KUSUserSession *)userSession
{
    self = [super initWithUserSession:userSession];
    if (self) {
        _localLastSeenAtBySessionId = [[NSMutableDictionary alloc] init];

        [self addListener:self];
        [self.userSession.chatSettingsDataSource addListener:self];
    }
    return self;
}

#pragma mark - KUSPaginatedDataSource methods

- (void)fetchLatest
{
    if (!self.userSession.chatSettingsDataSource.didFetch) {
        [self.userSession.chatSettingsDataSource fetch];
        return;
    }
    
    [super fetchLatest];
}

- (NSURL *)firstURL
{
    return [self.userSession.requestManager URLForEndpoint:[self _getSessionsUrl]];
}

- (NSString *) _getSessionsUrl {
    
    NSString *url = @"/c/v1/chat/sessions";
    if (self.userSession.chatSettingsDataSource.didFetch) {
        
        KUSChatSettings *chatSettings = self.userSession.chatSettingsDataSource.object;
        if(chatSettings.noHistory) {
            //Only fetch active sessions when no history is enabled
            url = [NSString stringWithFormat:@"%@?active=true", url];
        }
    }
    return url;
}

- (Class)modelClass
{
    return [KUSChatSession class];
}

- (NSArray<NSSortDescriptor *> *)sortDescriptors
{
    //        [NSSortDescriptor sortDescriptorWithKey:@"sortDate" ascending:NO],
    //        [NSSortDescriptor sortDescriptorWithKey:@"oid" ascending:NO]
    return @[
             [NSSortDescriptor sortDescriptorWithKey:@"lockedAt" ascending:YES comparator: ^NSComparisonResult( NSDate *date1,NSDate* date2 ){
                 
                 if ([date1 compare:date2] == NSOrderedAscending) {
                     return NSOrderedDescending;
                 }
                 return NSOrderedAscending;
                 
             }],
             [NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:NO]
    ];
}

#pragma mark - Public methods

- (void)upsertNewSessions:(NSArray<KUSChatSession *> *)chatSessions
{
    if (chatSessions.count == 1) {
        [self upsertObjects:chatSessions];
    } else if (chatSessions.count > 1) {
        NSMutableArray<KUSChatSession *> *reversedSessions = [[NSMutableArray alloc] initWithCapacity:chatSessions.count];
        for (KUSChatSession *chatSession in chatSessions.reverseObjectEnumerator) {
            [reversedSessions addObject:chatSession];
        }
        [self upsertObjects:reversedSessions];
    }
}

- (void)createSessionWithTitle:(NSString *)title completion:(void(^)(NSError *error, KUSChatSession *session))completion
{
    __weak KUSChatSessionsDataSource *weakSelf = self;
    [self.userSession.requestManager
     performRequestType:KUSRequestTypePost
     endpoint:[self _getSessionsUrl]
     params:@{ @"title": title }
     authenticated:YES
     completion:^(NSError *error, NSDictionary *response) {
         if (error) {
             if (completion) {
                 completion(error, nil);
             }
             return;
         }

         KUSChatSession *session = [[KUSChatSession alloc] initWithJSON:response[@"data"]];
         if (session) {
             [self _checkShouldFlushCustomAttributesToChatSessionId:session.oid];
             [weakSelf upsertObjects:@[ session ]];
         }
         if (completion) {
             completion(nil, session);
         }
     }];
}

- (void)updateLastSeenAtForSessionId:(NSString *)sessionId completion:(void(^)(NSError *error, KUSChatSession *session))completion
{
    if (sessionId.length == 0) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion([NSError new], nil);
            });
        }
        return;
    }

    NSDate *lastSeenAtDate = [NSDate date];
    [_localLastSeenAtBySessionId setObject:lastSeenAtDate forKey:sessionId];
    NSString *lastSeenAtString = [KUSDate stringFromDate:lastSeenAtDate];
    
    BOOL isLocalSession = [sessionId isEqualToString:kKUSTempSessionId];
    if (isLocalSession) {
        KUSChatSession *session = [self objectWithId:sessionId];
        [self removeObjects:@[session]];
        session.lastSeenAt = lastSeenAtDate;
        [self upsertObjects:@[session]];
        return;
    }

    __weak KUSChatSessionsDataSource *weakSelf = self;
    [self.userSession.requestManager
     performRequestType:KUSRequestTypePut
     endpoint:[NSString stringWithFormat:@"/c/v1/chat/sessions/%@", sessionId]
     params:@{ @"lastSeenAt": lastSeenAtString }
     authenticated:YES
     completion:^(NSError *error, NSDictionary *response) {
         if (error) {
             if (completion) {
                 completion(error, nil);
             }
             return;
         }

         KUSChatSession *session = [[KUSChatSession alloc] initWithJSON:response[@"data"]];
         if (session) {
             [weakSelf upsertObjects:@[ session ]];
         }
         if (completion) {
             completion(nil, session);
         }
     }];
}

- (void)updateLocallyLastSeenAtForSessionId:(NSString *)sessionId
{
    if (sessionId.length == 0) {
        return;
    }
    [_localLastSeenAtBySessionId setObject:[NSDate date] forKey:sessionId];
}

- (void)submitFormMessages:(NSArray<NSDictionary *> *)messages
                    formId:(NSString *)formId
                completion:(void (^)(NSError *, KUSChatSession *, NSArray<KUSChatMessage *> *))completion
{
    __weak KUSChatSessionsDataSource *weakSelf = self;
    [self.userSession.requestManager
     performRequestType:KUSRequestTypePost
     endpoint:[NSString stringWithFormat:@"/c/v1/chat/forms/%@/responses", formId]
     params:@{ @"messages": messages }
     authenticated:YES
     completion:^(NSError *error, NSDictionary *response) {
         if (error) {
             if (completion) {
                 completion(error, nil, nil);
             }
             return;
         }

         KUSChatSession *chatSession = nil;
         NSMutableArray<KUSChatMessage *> *chatMessages = [[NSMutableArray alloc] init];

         NSArray<NSDictionary *> *includedModelsJSON = response[@"included"];
         for (NSDictionary *includedModelJSON in includedModelsJSON) {
             NSString *type = includedModelJSON[@"type"];
             if ([type isEqual:[KUSChatSession modelType]]) {
                 chatSession = [[KUSChatSession alloc] initWithJSON:includedModelJSON];
             } else if ([type isEqual:[KUSChatMessage modelType]]) {
                 KUSChatMessage *chatMessage = [[KUSChatMessage alloc] initWithJSON:includedModelJSON];
                 [chatMessages addObject:chatMessage];
             }
         }

         if (chatSession) {
             [self _checkShouldFlushCustomAttributesToChatSessionId:chatSession.oid];
             [weakSelf upsertObjects:@[ chatSession ]];
         }
         if (completion) {
             completion(nil, chatSession, chatMessages);
         }
     }];
}

- (void)describeActiveConversation:(NSDictionary<NSString *, NSObject *> *)customAttributes
{
    NSMutableDictionary<NSString *, NSObject *> *pendingCustomChatSessionAttributes = [[NSMutableDictionary alloc] init];
    if (_pendingCustomChatSessionAttributes) {
        [pendingCustomChatSessionAttributes addEntriesFromDictionary:_pendingCustomChatSessionAttributes];
    }
    [pendingCustomChatSessionAttributes addEntriesFromDictionary:customAttributes];
    _pendingCustomChatSessionAttributes = pendingCustomChatSessionAttributes;
    
    KUSChatSession *mostRecentSession = [self mostRecentSession];
    NSString *mostRecentSessionId = mostRecentSession.oid;
    if (mostRecentSessionId) {
        [self _flushCustomAttributes:_pendingCustomChatSessionAttributes toChatSessionId:mostRecentSessionId];
    }
}

- (void)describeNextConversation:(NSDictionary<NSString *, NSObject *> *)customAttributes
{
    NSMutableDictionary<NSString *, NSObject *> *pendingCustomChatSessionAttributesForNextConversation = [[NSMutableDictionary alloc] init];
    if (_pendingCustomChatSessionAttributesForNextConversation) {
        [pendingCustomChatSessionAttributesForNextConversation addEntriesFromDictionary:_pendingCustomChatSessionAttributesForNextConversation];
    }
    [pendingCustomChatSessionAttributesForNextConversation addEntriesFromDictionary:customAttributes];
    _pendingCustomChatSessionAttributesForNextConversation = pendingCustomChatSessionAttributesForNextConversation;
}

- (NSUInteger)openChatSessionsCount
{
    NSUInteger count = 0;
    for (KUSChatSession *session in self.allObjects) {
        if (!session.lockedAt) {
            count += 1;
        }
    }
    return count;
}

- (NSUInteger)openProactiveCampaignsCount
{
    NSUInteger count = 0;
    for (KUSChatSession *session in self.allObjects) {
        KUSChatMessagesDataSource *chatDataSource = [self.userSession chatMessagesDataSourceForSessionId:session.oid];
        if (!session.lockedAt && !chatDataSource.isAnyMessageByCurrentUser) {
            count += 1;
        }
    }
    return count;
}

- (void)setMessageToCreateNewChatSession:(NSString *)messageToCreateNewChatSession
{
    _messageToCreateNewChatSession = [messageToCreateNewChatSession copy];
}

- (void)setFormIdForConversationalForm:(NSString *)formIdForConversationalForm
{
    _formIdForConversationalForm = [formIdForConversationalForm copy];
}

- (BOOL)didFetch
{
    if (_isNewSession) {
        return YES;
    }
    return [super didFetch];
}

- (void)markSessionAsNew
{
    _isNewSession = YES;
}

#pragma mark - Internal methods

- (void)_checkShouldFlushCustomAttributesToChatSessionId:(NSString *)chatSessionId
{
    BOOL hasChatSessionAttributes = _pendingCustomChatSessionAttributes || _pendingCustomChatSessionAttributesForNextConversation;
    if (hasChatSessionAttributes) {
        NSMutableDictionary<NSString *, NSObject *> *pendingCustomChatSessionAttributes = [[NSMutableDictionary alloc] init];
        if (_pendingCustomChatSessionAttributes) {
            [pendingCustomChatSessionAttributes addEntriesFromDictionary:_pendingCustomChatSessionAttributes];
        }
        if (_pendingCustomChatSessionAttributesForNextConversation) {
            [pendingCustomChatSessionAttributes addEntriesFromDictionary:_pendingCustomChatSessionAttributesForNextConversation];
            _pendingCustomChatSessionAttributesForNextConversation = nil;
        }
        [self _flushCustomAttributes:pendingCustomChatSessionAttributes toChatSessionId:chatSessionId];
    }
}

- (void)_flushCustomAttributes:(NSDictionary<NSString *, NSObject *> *)customAttributes toChatSessionId:(NSString *)chatSessionId
{
    NSDictionary<NSString *, NSObject *> *formData = @{ @"custom" : customAttributes };
    NSString *endpoint = [NSString stringWithFormat:@"/c/v1/conversations/%@", chatSessionId];
    [self.userSession.requestManager
     performRequestType:KUSRequestTypePatch
     endpoint:endpoint
     params:formData
     authenticated:YES
     completion:^(NSError *error, NSDictionary *response) {
         if (error) {
             KUSLogError(@"Error updating chat attributes: %@", error);
         }
     }];
}


#pragma mark - Helper methods

- (KUSChatSession * _Nullable)mostRecentSession
{
    NSDate *mostRecentMessageAt = nil;
    KUSChatSession *mostRecentSession = nil;
    for (KUSChatSession *chatSession in self.allObjects) {
        if (!chatSession.lockedAt) {
            if (mostRecentMessageAt == nil) {
                mostRecentMessageAt = chatSession.lastMessageAt;
                mostRecentSession = chatSession;
            } else if ([mostRecentMessageAt laterDate:chatSession.lastMessageAt] == chatSession.lastMessageAt) {
                mostRecentMessageAt = chatSession.lastMessageAt;
                mostRecentSession = chatSession;
            }
        }
    }
    return mostRecentSession ?: self.firstObject;
}

- (KUSChatSession *)mostRecentNonProactiveCampaignOpenSession
{
    NSDate *mostRecentMessageAt = nil;
    KUSChatSession *mostRecentSession = nil;
    for (KUSChatSession *chatSession in self.allObjects) {
        KUSChatMessagesDataSource *chatDataSource = [self.userSession chatMessagesDataSourceForSessionId:chatSession.oid];
        if (!chatSession.lockedAt && chatDataSource.isAnyMessageByCurrentUser) {
            if (mostRecentMessageAt == nil) {
                mostRecentMessageAt = chatSession.lastMessageAt;
                mostRecentSession = chatSession;
            } else if ([mostRecentMessageAt laterDate:chatSession.lastMessageAt] == chatSession.lastMessageAt) {
                mostRecentMessageAt = chatSession.lastMessageAt;
                mostRecentSession = chatSession;
            }
        }
    }
    return mostRecentSession ?: self.firstObject;
}

- (NSDate * _Nullable)lastMessageAt
{
    NSDate *mostRecentMessageAt = nil;
    for (KUSChatSession *chatSession in self.allObjects) {
        if (mostRecentMessageAt == nil) {
            mostRecentMessageAt = chatSession.lastMessageAt;
        } else if ([mostRecentMessageAt laterDate:chatSession.lastMessageAt] == chatSession.lastMessageAt) {
            mostRecentMessageAt = chatSession.lastMessageAt;
        }
    }
    
    if (!mostRecentMessageAt) {
        KUSChatSession *firstSession = self.firstObject;
        return firstSession.lastMessageAt;
    }
    return mostRecentMessageAt;
}

- (NSDate * _Nullable)lastSeenAtForSessionId:(NSString *)sessionId
{
    KUSChatSession *chatSession = [self objectWithId:sessionId];
    NSDate *chatSessionDate = chatSession.lastSeenAt;
    NSDate *localDate = [_localLastSeenAtBySessionId objectForKey:sessionId];
    return [chatSessionDate ?: localDate laterDate:localDate];
}

- (NSUInteger)totalUnreadCountExcludingSessionId:(NSString *)excludedSessionId
{
    NSUInteger count = 0;
    for (KUSChatSession *session in self.allObjects) {
        NSString *sessionId = session.oid;
        if (excludedSessionId && [excludedSessionId isEqualToString:sessionId]) {
            continue;
        }
        KUSChatMessagesDataSource *messagesDataSource = [self.userSession chatMessagesDataSourceForSessionId:sessionId];
        NSDate *sessionLastSeenAt = [self lastSeenAtForSessionId:sessionId];
        NSUInteger unreadCountForSession = [messagesDataSource unreadCountAfterDate:sessionLastSeenAt];
        count += unreadCountForSession;
    }
    return count;
}

#pragma mark - KUSPaginatedDataSourceListener methods

- (void)paginatedDataSourceDidChangeContent:(KUSPaginatedDataSource *)dataSource
{
    if (dataSource == self) {
        [self.userSession.userDefaults setOpenChatSessionsCount:[self openChatSessionsCount]];
        NSArray<NSString *> *sessionIds = [self.allObjects valueForKeyPath:@"@unionOfObjects.oid"];
        for (NSString *sessionId in sessionIds) {
            KUSChatMessagesDataSource *messagesDataSource = [self.userSession chatMessagesDataSourceForSessionId:sessionId];
            [messagesDataSource addListener:self];
        }
    } else if ([dataSource isKindOfClass:[KUSChatMessagesDataSource class]]) {
        [self sortObjects];
        [self notifyAnnouncersDidChangeContent];
    }
}

#pragma mark - KUSObjectDataSourceListener methods

- (void)objectDataSourceDidLoad:(KUSObjectDataSource *)dataSource
{
    [self fetchLatest];
}

- (void)objectDataSource:(KUSObjectDataSource *)dataSource didReceiveError:(NSError *)error
{
    if (!dataSource.didFetch) {
        [self notifyAnnouncersDidError:error];
    }
}

@end

@implementation KUSChatSession (SortDate)

- (NSDate *)sortDate
{
    KUSUserSession *userSession = [Kustomer sharedInstance].userSession;
    KUSChatMessagesDataSource *messagesDataSource = [userSession chatMessagesDataSourceForSessionId:self.oid];
    KUSChatMessage *chatMessage = (messagesDataSource.count ? [messagesDataSource objectAtIndex:0] : nil);
    NSDate *laterLastMessageAt = [chatMessage.createdAt ?: self.lastMessageAt laterDate:self.lastMessageAt];
    return laterLastMessageAt ?: self.createdAt;
}

@end
