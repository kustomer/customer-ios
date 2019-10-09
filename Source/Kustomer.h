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
static NSString* const kKUSMessageAttribute = @"KUSMessageAttributeKey";
static NSString* const kKUSFormIdAttribute = @"KUSFormIdAttributeKey";
static NSString* const kKUSScheduleIdAttribute = @"KUSScheduleIdAttributeKey";
static NSString* const kKUSCustomAttributes = @"KUSCustomAttributesKey";

@protocol KustomerDelegate;
@interface Kustomer : NSObject

+ (void)initializeWithAPIKey:(NSString *)apiKey;
+ (void)setDelegate:(__weak id<KustomerDelegate>)delegate;

+ (void)describeConversation:(NSDictionary<NSString *, NSObject *> *)customAttributes;
+ (void)describeNextConversation:(NSDictionary<NSString *, NSObject *> *)customAttributes;
+ (void)describeCustomer:(KUSCustomerDescription *)customerDescription;
+ (void)identify:(nonnull NSString *)externalToken callback:(void (^_Nullable)(BOOL success))handler;
+ (void)resetTracking;

+ (void)setCurrentPageName:(NSString *)currentPageName;

+ (void)printLocalizationKeys;
+ (void)registerLocalizationTableName:(NSString *)table;
+ (void)setLanguage:(NSString *)language;

// Returns the current count of unread messages. It might not be immediately available.
+ (NSUInteger)unreadMessageCount;

// Get status asynchronously about current chat is available or not.
+ (void)isChatAvailable:(void (^)(BOOL success, BOOL enabled))block;

// A convenience method that will present the support interface on the topmost view controller
+ (void)presentSupport;
+ (void)presentSupportWithAttributes:(KUSChatAttributes)attributes;
+ (void)presentSupportWithMessage:(NSString *) message DEPRECATED_PRESENT_SUPPORT;
+ (void)presentSupportWithMessage:(NSString *)message formId:(NSString *)formId DEPRECATED_PRESENT_SUPPORT;
+ (void)presentSupportWithMessage:(NSString *) message customAttributes:(NSDictionary<NSString *, NSObject *> *)customAttributes DEPRECATED_PRESENT_SUPPORT;
+ (void)presentSupportWithMessage:(NSString *)message formId:(NSString *)formId customAttributes:(NSDictionary<NSString *, NSObject *> *)customAttributes DEPRECATED_PRESENT_SUPPORT;

// A convenience method that will present the knowledgebase interface on the topmost view controller
+ (void)presentKnowledgeBase;

// A convenience method that will present the custom web page interface on the topmost view controller
+ (void)presentCustomWebPage:(NSString*)url;
+ (void)setFormId:(NSString *)formId;

// Returns the total number of open conversations.
+ (NSInteger)openConversationsCount;

// The current SDK version
+ (NSString *)sdkVersion;

// Show/Hide new conversation button in closed chat
+ (void)hideNewConversationButtonInClosedChat:(BOOL)status;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

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
