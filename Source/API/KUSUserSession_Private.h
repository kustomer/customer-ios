//
//  KUSUserSession_Private.h
//  Kustomer
//
//  Created by Daniel Amitay on 12/17/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSUserSession.h"

@class KUSChatMessagesDataSource;
@interface KUSUserSession (Private)

@property (nonatomic, readonly, null_resettable) NSMutableDictionary<NSString *, KUSChatMessagesDataSource *> *chatMessagesDataSources;


@property (nonatomic, strong) KUSRequestManager * _Nonnull requestManager;
@property (nonatomic, strong) KUSChatSessionsDataSource * _Nonnull chatSessionsDataSource;

@end
