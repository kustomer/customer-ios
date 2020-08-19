//
//  Kustomer.h
//  Kustomer
//
//  Created by Daniel Amitay on 7/1/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "KnowledgeBaseViewController.h"
#import "KustomerViewController.h"
#import "KUSCustomerDescription.h"

FOUNDATION_EXPORT double KustomerVersionNumber;
FOUNDATION_EXPORT const unsigned char KustomerVersionString[];

#define DEPRECATED_PRESENT_SUPPORT DEPRECATED_MSG_ATTRIBUTE("use presentSupportWithAttributes:(KUSChatAttributes) instead");

typedef NSDictionary<NSString *, id>* KUSChatAttributes;
static NSString* _Nonnull const kKUSMessageAttribute = @"KUSMessageAttributeKey";
static NSString* _Nonnull const kKUSFormIdAttribute = @"KUSFormIdAttributeKey";
static NSString* _Nonnull const kKUSScheduleIdAttribute = @"KUSScheduleIdAttributeKey";
static NSString* _Nonnull const kKUSCustomAttributes = @"KUSCustomAttributesKey";

@protocol KustomerDelegate;
@interface Kustomer : NSObject

+ (void)initializeWithAPIKey:(NSString *_Nonnull)apiKey;
+ (void)setDelegate:(__weak id<KustomerDelegate>_Nonnull)delegate;

+ (void)describeConversation:(NSDictionary<NSString *, NSObject *> *_Nonnull)customAttributes;
+ (void)describeNextConversation:(NSDictionary<NSString *, NSObject *> *_Nonnull)customAttributes;
+ (void)describeCustomer:(KUSCustomerDescription *_Nonnull)customerDescription;
+ (void)identify:(nonnull NSString *)externalToken callback:(void (^_Nonnull)(BOOL success))handler;
+ (void)resetTracking;

+ (void)setCurrentPageName:(NSString *_Nonnull)currentPageName;

+ (void)printLocalizationKeys;
+ (void)registerLocalizationTableName:(NSString *_Nonnull)table;
+ (void)setLanguage:(NSString *_Nonnull)language;

// Returns the current count of unread messages. It might not be immediately available.
+ (NSUInteger)unreadMessageCount;

// Get status asynchronously about current chat is available or not.
+ (void)isChatAvailable:(void (^_Nonnull)(BOOL success, BOOL enabled))block;

// A convenience method that will present the support interface on the topmost view controller
+ (void)presentSupport;
+ (void)presentSupportWithAttributes:(KUSChatAttributes _Nullable)attributes;
+ (void)presentSupportWithMessage:(NSString *_Nullable) message DEPRECATED_PRESENT_SUPPORT;
+ (void)presentSupportWithMessage:(NSString *_Nullable)message formId:(NSString *_Nullable)formId DEPRECATED_PRESENT_SUPPORT;
+ (void)presentSupportWithMessage:(NSString *_Nullable) message customAttributes:(NSDictionary<NSString *, NSObject *> *_Nullable)customAttributes DEPRECATED_PRESENT_SUPPORT;
+ (void)presentSupportWithMessage:(NSString *_Nullable)message formId:(NSString *_Nullable)formId customAttributes:(NSDictionary<NSString *, NSObject *> *_Nullable)customAttributes DEPRECATED_PRESENT_SUPPORT;

// A convenience method that will present the knowledgebase interface on the topmost view controller
+ (void)presentKnowledgeBase;

// A convenience method that will present the custom web page interface on the topmost view controller
+ (void)presentCustomWebPage:(NSString * _Nonnull)url;
+ (void)setFormId:(NSString * _Nonnull)formId;

// Returns the total number of open conversations.
+ (NSInteger)openConversationsCount;

// The current SDK version
+ (NSString * _Nullable)sdkVersion;

// Show/Hide new conversation button in closed chat
+ (void)hideNewConversationButtonInClosedChat:(BOOL)status;

- (instancetype _Nonnull )init NS_UNAVAILABLE;
+ (instancetype _Nonnull)new NS_UNAVAILABLE;

@end

@protocol KustomerDelegate <NSObject>

@optional

// Implement this method to allow or disallow Kustomer from showing in-app notifications
// (for example if the user is currently viewing a screen that should be un-interrupted)
// If unimplemented, will default to YES
- (BOOL)kustomerShouldDisplayInAppNotification;

// Implement to perform custom handling and presentation of the support user interface
// If unimplemented, Kustomer will present the support interface on the topmost view controller
- (void)kustomerDidTapOnInAppNotification;


@end
