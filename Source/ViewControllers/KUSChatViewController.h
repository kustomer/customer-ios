//
//  KUSChatViewController.h
//  Kustomer
//
//  Created by Daniel Amitay on 7/16/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSBaseViewController.h"

@class KUSChatSession;
@class KUSUserSession;
@interface KUSChatViewController : KUSBaseViewController

- (instancetype)initWithUserSession:(KUSUserSession *)userSession forChatSession:(KUSChatSession *)session;
- (instancetype)initWithUserSession:(KUSUserSession *)userSession forNewSessionWithBackButton:(BOOL)showBackButton;
- (instancetype)initWithUserSession:(KUSUserSession *)userSession forNewSessionWithMessage:(NSString *)message andFormId:(NSString *)formId;
- (instancetype)init NS_UNAVAILABLE;

@end
