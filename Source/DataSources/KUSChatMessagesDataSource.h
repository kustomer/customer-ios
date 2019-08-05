//
//  KUSChatMessagesDataSource.h
//  Kustomer
//
//  Created by Daniel Amitay on 7/23/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSPaginatedDataSource.h"

#import "KUSChatMessage.h"
#import "KUSFormQuestion.h"
#import "KUSSessionQueuePollingManager.h"
#import "KUSSatisfactionResponseDataSource.h"
#import "KUSTypingIndicator.h"

#import <UIKit/UIKit.h>

@class KUSChatMessagesDataSource;
@protocol KUSChatMessagesDataSourceListener <KUSPaginatedDataSourceListener>

@optional
- (void)chatMessagesDataSource:(KUSChatMessagesDataSource *)dataSource didCreateSessionId:(NSString *)sessionId;
- (void)chatMessagesDataSourceDidFetchSatisfactionForm:(KUSChatMessagesDataSource *)dataSource;
- (void)chatMessagesDataSource:(KUSChatMessagesDataSource *)dataSource didReceiveTypingUpdate:(KUSTypingIndicator *)typingIndicator;
- (void)chatMessagesDataSourceDidEndChatSession:(KUSChatMessagesDataSource *)dataSource;

@end

@interface KUSChatMessagesDataSource : KUSPaginatedDataSource

- (instancetype)initForNewConversationWithUserSession:(KUSUserSession *)userSession formId:(NSString *)formId;
- (instancetype)initWithUserSession:(KUSUserSession *)userSession sessionId:(NSString *)sessionId;
- (instancetype)initWithUserSession:(KUSUserSession *)userSession NS_UNAVAILABLE;

- (void)addListener:(id<KUSChatMessagesDataSourceListener>)listener;

- (KUSSatisfactionResponseDataSource *)satisfactionResponseDataSource;
- (NSString *)sessionId;
- (BOOL)isAnyMessageByCurrentUser;
- (BOOL)shouldAllowAttachments;
- (NSString *)firstOtherUserId;
- (NSArray<NSString *> *)otherUserIds;
- (NSUInteger)unreadCountAfterDate:(NSDate *)date;
- (BOOL)shouldPreventSendingMessage;
- (KUSFormQuestion *)currentQuestion;
- (KUSChatMessage *)latestMessage;
- (KUSFormQuestion *)volumeControlCurrentQuestion;
- (BOOL)isChatClosed;
- (KUSSessionQueuePollingManager *)sessionQueuePollingManager;
- (BOOL)shouldShowSatisfactionForm;

- (void)upsertNewMessages:(NSArray<KUSChatMessage *> *)chatMessages;
- (void)sendMessageWithText:(NSString *)text attachments:(NSArray<UIImage *> *)attachments;
- (void)sendMessageWithText:(NSString *)text attachments:(NSArray<UIImage *> *)attachments value:(NSString *)value;
- (void)resendMessage:(KUSChatMessage *)message;
- (void)endChat:(NSString *)reason withCompletion:(void (^)(BOOL))completion;

- (void)sendTypingStatusToPusher:(KUSTypingStatus)typingStatus;
- (void)startListeningForTypingUpdate;
- (void)stopListeningForTypingUpdate;

@end
