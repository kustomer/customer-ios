//
//  KUSChatMessagesDataSource.h
//  Kustomer
//
//  Created by Daniel Amitay on 7/23/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSPaginatedDataSource.h"

#import "KUSChatMessage.h"

@interface KUSChatMessagesDataSource : KUSPaginatedDataSource

- (instancetype)initWithUserSession:(KUSUserSession *)userSession sessionId:(NSString *)sessionId;
- (instancetype)initWithUserSession:(KUSUserSession *)userSession NS_UNAVAILABLE;

- (NSString *)firstOtherUserId;
- (NSUInteger)unreadCountAfterDate:(NSDate *)date;

- (void)upsertMessageReceivedFromPusher:(KUSChatMessage *)chatMessage;

- (void)sendTextMessage:(NSString *)text completion:(void(^)(NSError *error, KUSChatMessage *message))completion;

@end
