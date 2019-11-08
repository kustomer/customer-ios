//
//  KUSUserSession.h
//  Kustomer
//
//  Created by Daniel Amitay on 8/13/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "KUSChatMessagesDataSource.h"
#import "KUSChatSessionsDataSource.h"
#import "KUSChatSettingsDataSource.h"
#import "KUSDelegateProxy.h"
#import "KUSFormDataSource.h"
#import "KUSPushClient.h"
#import "KUSRequestManager.h"
#import "KUSTrackingTokenDataSource.h"
#import "KUSUserDataSource.h"
#import "KUSUserDefaults.h"
#import "KUSCustomerDescription.h"
#import "KUSClientActivityManager.h"
#import "KUSLocalization.h"
#import "KUSScheduleDataSource.h"

@class KUSStatsManager;

@interface KUSUserSession : NSObject

- (instancetype)initWithOrgName:(NSString *)orgName orgId:(NSString *)orgId reset:(BOOL)reset NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithOrgName:(NSString *)orgName orgId:(NSString *)orgId;
- (instancetype)init NS_UNAVAILABLE;

// Org methods
- (NSString *)orgId;
- (NSString *)orgName;
- (NSString *)organizationName; // User facing

// Datasource objects
- (KUSChatSessionsDataSource *)chatSessionsDataSource;
- (KUSChatSettingsDataSource *)chatSettingsDataSource;
- (KUSTrackingTokenDataSource *)trackingTokenDataSource;
- (KUSFormDataSource *)formDataSource;
- (KUSScheduleDataSource *)scheduleDataSource;

- (KUSChatMessagesDataSource *)chatMessagesDataSourceForSessionId:(NSString *)sessionId;
- (KUSUserDataSource *)userDataSourceForUserId:(NSString *)userId;

// Managers & Push client
- (KUSRequestManager *)requestManager;
- (KUSPushClient *)pushClient;
- (KUSDelegateProxy *)delegateProxy;
- (KUSClientActivityManager *)activityManager;
- (KUSStatsManager *)statsManager;

- (KUSUserDefaults *)userDefaults;

// Email info
- (void)submitEmail:(NSString *)emailAddress;
- (BOOL)shouldCaptureEmail;

- (void)describeCustomer:(KUSCustomerDescription *)customerDescription completion:(void(^)(BOOL, NSError *))completion;

- (void) initializeWithReset:(BOOL )reset;
@end
