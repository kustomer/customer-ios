//
//  KUSChatSessionsDataSource.h
//  Kustomer
//
//  Created by Daniel Amitay on 7/22/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSPaginatedDataSource.h"

#import "KUSChatSession.h"

#define kKUSTempSessionId @"temp_session_id"

@class KUSChatMessage;
@interface KUSChatSessionsDataSource : KUSPaginatedDataSource

@property (nonatomic, copy) NSString *messageToCreateNewChatSession;
@property (nonatomic, copy) NSString *formIdForConversationalForm;

- (void)upsertNewSessions:(NSArray<KUSChatSession *> *)chatSessions;
- (void)createSessionWithTitle:(NSString *)title completion:(void(^)(NSError *error, KUSChatSession *session))completion;
- (void)updateLastSeenAtForSessionId:(NSString *)sessionId completion:(void(^)(NSError *error, KUSChatSession *session))completion;
- (void)updateLocallyLastSeenAtForSessionId:(NSString *)sessionId;
- (void)submitFormMessages:(NSArray<NSDictionary *> *)messages
                    formId:(NSString *)formId
                completion:(void(^)(NSError *error, KUSChatSession *session, NSArray<KUSChatMessage *> *messages))completion;

// Sends custom attributes to the most active conversation, or the first conversation created
- (void)describeActiveConversation:(NSDictionary<NSString *, NSObject *> *)customAttributes;
- (void)describeNextConversation:(NSDictionary<NSString *, NSObject *> *)customAttributes;

// Returns the chat session with the most recent MessageAt
- (KUSChatSession *)mostRecentSession;

// Returns the non-proactive chat session with the most recent MessageAt
- (KUSChatSession *)mostRecentNonProactiveCampaignOpenSession;

// Returns the latest date representing the last message received across all sessions
- (NSDate *)lastMessageAt;

// Returns the lastSeenAt for a given session, using the data model as well as augmented by a local store
- (NSDate *)lastSeenAtForSessionId:(NSString *)sessionId;

// Returns the total unread message count for all sessions excluding the specified sessionId
- (NSUInteger)totalUnreadCountExcludingSessionId:(NSString *)excludedSessionId;

// Returns the total open chat sessions count including pro-active campaigns
- (NSUInteger)openChatSessionsCount;

// Returns the total open pro-active campaign sessions count
- (NSUInteger)openProactiveCampaignsCount;

@end
