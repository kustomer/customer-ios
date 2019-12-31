//
//  Kustomer.m
//  Kustomer
//
//  Created by Daniel Amitay on 7/1/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "Kustomer.h"
#import "Kustomer_Private.h"

#import "KUSLog.h"
#import "KUSUserSession.h"
#import "KUSReachabilityManager.h"

static NSString *kKustomerOrgIdKey = @"org";
static NSString *kKustomerOrgNameKey = @"orgName";

@interface Kustomer ()

@property (nonatomic, weak) __weak id<KustomerDelegate> delegate;
@property (nonatomic, strong) KUSUserSession *userSession;

@property (nonatomic, copy, readwrite) NSString *apiKey;
@property (nonatomic, copy, readwrite) NSString *orgId;
@property (nonatomic, copy, readwrite) NSString *orgName;

@end

@implementation Kustomer

#pragma mark - Class methods

+ (void)initializeWithAPIKey:(NSString *)apiKey
{
    [[self sharedInstance] setApiKey:apiKey];
}

+ (void)setDelegate:(__weak id<KustomerDelegate>)delegate
{
    [[self sharedInstance] setDelegate:delegate];
}

+ (void)describeConversation:(NSDictionary<NSString *, NSObject *> *)customAttributes
{
    [[self sharedInstance] describeConversation:customAttributes];
}

+ (void)describeNextConversation:(NSDictionary<NSString *, NSObject *> *)customAttributes
{
    [[self sharedInstance] describeNextConversation:customAttributes];
}

+ (void)describeCustomer:(KUSCustomerDescription *)customerDescription
{
    [[self sharedInstance] describeCustomer:customerDescription];
}

+ (void)identify:(nonnull NSString *)externalToken callback:(void (^_Nullable)(BOOL success))handler;
{
  [[self sharedInstance] identify:externalToken callback:handler];
}

+ (void)resetTracking
{
    [[self sharedInstance] resetTracking];
}

+ (void)setCurrentPageName:(NSString *)currentPageName
{
    [[self sharedInstance] setCurrentPageName:currentPageName];
}

+ (NSUInteger)unreadMessageCount
{
    return [[self sharedInstance] unreadMessageCount];
}

+ (void)printLocalizationKeys
{
    [[self sharedInstance] printLocalizationKeys];
}

+ (void)registerLocalizationTableName:(NSString *)table
{
    [[self sharedInstance] registerLocalizationTableName:table];
}

+ (void)setLanguage:(NSString *)language
{
    [[self sharedInstance] setLanguage:language];
}

+ (void)isChatAvailable:(void (^)(BOOL success, BOOL enabled))block
{
    [[self sharedInstance] isChatAvailable:block];
}

+ (void)presentSupport
{
    UIViewController *topMostViewController = KUSTopMostViewController();
    if (topMostViewController) {
        if ([topMostViewController isKindOfClass:[KustomerViewController class]]) {
            KUSLogError(@"Kustomer support is already presented");
            return;
        }
        KustomerViewController *kustomerViewController = [[KustomerViewController alloc] init];
        [topMostViewController presentViewController:kustomerViewController animated:YES completion:nil];
    } else {
        KUSLogError(@"Could not find view controller to present on top of!");
    }
}

+ (void)presentKnowledgeBase
{
    UIViewController *topMostViewController = KUSTopMostViewController();
    if (topMostViewController) {
        if ([topMostViewController isKindOfClass:[KnowledgeBaseViewController class]]) {
            KUSLogError(@"KnowledgeBase is already presented");
            return;
        }
        KnowledgeBaseViewController *knowledgeBaseViewController = [[KnowledgeBaseViewController alloc] init];
        [topMostViewController presentViewController:knowledgeBaseViewController animated:YES completion:nil];
    } else {
        KUSLogError(@"Could not find view controller to present on top of!");
    }
}

+ (void)presentCustomWebPage:(NSString*)url
{
    UIViewController *topMostViewController = KUSTopMostViewController();
    if (topMostViewController) {
        if ([topMostViewController isKindOfClass:[KnowledgeBaseViewController class]]) {
            KUSLogError(@"KnowledgeBase is already presented");
            return;
        }
        
        NSURL *URL = [NSURL URLWithString:url];
        if (URL) {
            KnowledgeBaseViewController *knowledgeBaseViewController = [[KnowledgeBaseViewController alloc] initWithURL:URL];
            [topMostViewController presentViewController:knowledgeBaseViewController animated:YES completion:nil];
        }
        else {
            KUSLogError(@"Invalid url, Unable to load Web View Controller");
        }
    } else {
        KUSLogError(@"Could not find view controller to present on top of!");
    }
}

+ (NSString *)sdkVersion
{
    return [NSBundle bundleForClass:self].infoDictionary[@"CFBundleShortVersionString"];
}

+ (void)setFormId:(NSString *)formId
{
    [[self sharedInstance] setFormId:formId];
}

+ (NSInteger)openConversationsCount
{
    return [[self sharedInstance] openConversationsCount];
}

+ (void)hideNewConversationButtonInClosedChat:(BOOL)status
{
    [[self sharedInstance] hideNewConversationButtonInClosedChat:status];
}

+ (void)presentSupportWithMessage:(NSString *) message customAttributes:(NSDictionary<NSString *, NSObject *> *)customAttributes
{
    [[self sharedInstance] presentSupportWithMessage:message formId:nil customAttributes:customAttributes];
}

+ (void)presentSupportWithMessage:(NSString *) message
{
    [Kustomer presentSupportWithMessage:message formId:nil customAttributes:nil];
}

+ (void)presentSupportWithMessage:(NSString *) message formId:(NSString *)formId
{

    [Kustomer presentSupportWithMessage:message formId:formId customAttributes: nil];
}

+ (void)presentSupportWithMessage:(NSString *) message formId:(NSString *)formId customAttributes:(NSDictionary<NSString *, NSObject *> *)customAttributes
{
    [[self sharedInstance] presentSupportWithMessage:message formId:formId customAttributes:customAttributes];
}

+ (void)presentSupportWithAttributes:(KUSChatAttributes)attributes
{
    [[self sharedInstance] presentSupportWithAttributes:attributes];
}

#pragma mark - Lifecycle methods

+ (instancetype)sharedInstance
{
    static Kustomer *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (void)setApiKey:(NSString *)apiKey
{
    NSAssert(apiKey.length, @"Kustomer requires a valid API key");
    if (apiKey.length == 0) {
        return;
    }

    NSArray<NSString *> *apiKeyParts = [apiKey componentsSeparatedByString:@"."];
    NSAssert(apiKeyParts.count > 2, @"Kustomer API key has unexpected format");
    if (apiKeyParts.count <= 2) {
        return;
    }

    NSString *base64EncodedTokenJson = paddedBase64String(apiKeyParts[1]);
    NSDictionary<NSString *, NSString *> *tokenPayload = jsonFromBase64EncodedJsonString(base64EncodedTokenJson);

    _apiKey = [apiKey copy];
    self.orgId = tokenPayload[kKustomerOrgIdKey];
    self.orgName = tokenPayload[kKustomerOrgNameKey];
    NSAssert(self.orgName.length > 0, @"Kustomer API key missing expected field: orgName");
    if (self.orgName.length == 0) {
        return;
    }

    KUSLogInfo(@"Kustomer initialized for organization: %@", self.orgName);

    self.userSession = [[KUSUserSession alloc] initWithOrgName:self.orgName orgId:self.orgId];
    [self.userSession.delegateProxy setDelegate:self.delegate];
    
    //Intialize Reachability manager to get callbacks for newtwork state change
    [KUSReachabilityManager.sharedInstance startObservingNetworkChange];
}

- (void)setDelegate:(__weak id<KustomerDelegate>)delegate
{
    _delegate = delegate;
    [self.userSession.delegateProxy setDelegate:self.delegate];
}

#pragma mark - Private class methods

static NSString *_hostDomainOverride = nil;

+ (NSString *)hostDomain
{
    return _hostDomainOverride ?: @"kustomerapp.com";
}

+ (void)setHostDomain:(NSString *)hostDomain
{
    _hostDomainOverride = [hostDomain copy];
}

static KUSLogOptions _logOptions = KUSLogOptionInfo | KUSLogOptionErrors;

+ (KUSLogOptions)logOptions
{
    return _logOptions;
}

+ (void)setLogOptions:(KUSLogOptions)logOptions
{
    _logOptions = logOptions;
}

#pragma mark - Private methods

- (KUSUserSession *)userSession
{
    NSAssert(_userSession, @"Kustomer needs to be initialized before use");
    return _userSession;
}

#pragma mark - Internal methods

- (void)describeConversation:(NSDictionary<NSString *, NSObject *> *)customAttributes
{
    NSAssert(customAttributes.count, @"Attempted to describe a conversation with no attributes set");
    if (customAttributes.count == 0) {
        return;
    }
    [self.userSession.chatSessionsDataSource describeActiveConversation:customAttributes];
}

- (void)describeNextConversation:(NSDictionary<NSString *, NSObject *> *)customAttributes
{
    NSAssert(customAttributes.count, @"Attempted to describe next conversation with no attributes set");
    if (customAttributes.count == 0) {
        return;
    }
    [self.userSession.chatSessionsDataSource describeNextConversation:customAttributes];
}

- (void)describeCustomer:(KUSCustomerDescription *)customerDescription
{
    [self.userSession describeCustomer:customerDescription completion:nil];
}

- (void)identify:(nonnull NSString *)externalToken callback:(void (^_Nullable)(BOOL success))handler
{
    NSAssert(externalToken, @"Kustomer expects externalToken to be non-nil");
    if (externalToken == nil) {
        return;
    }

    __weak KUSUserSession *weakUserSession = self.userSession;
    [self.userSession.requestManager
     performRequestType:KUSRequestTypePost
     endpoint:@"/c/v1/identity"
     params:@{ @"externalToken" : externalToken }
     authenticated:YES
     completion:^(NSError *error, NSDictionary *response) {
       //[weakUserSession.trackingTokenDataSource fetch];
       if (handler)  {
         handler(error == nil);
       }
        [weakUserSession initializeWithReset:NO];
     }];
}

- (void)resetTracking
{
    NSString *currentPageName = [self.userSession.activityManager currentPageName];

    // Create a new userSession and release the previous one
    self.userSession = [[KUSUserSession alloc] initWithOrgName:self.orgName orgId:self.orgId reset:YES];

    // Update the new userSession with the previous state
    [self.userSession.delegateProxy setDelegate:self.delegate];
    [self.userSession.activityManager setCurrentPageName:currentPageName];
    [self.userSession.userDefaults reset];
}

- (void)setCurrentPageName:(NSString *)currentPageName
{
    [self.userSession.activityManager setCurrentPageName:currentPageName];
}

- (NSUInteger)unreadMessageCount
{
    return [self.userSession.chatSessionsDataSource totalUnreadCountExcludingSessionId:nil];
}

- (void)printLocalizationKeys
{
    [[KUSLocalization sharedInstance] printAllKeys];
}

- (void)registerLocalizationTableName:(NSString *)table
{
    [[KUSLocalization sharedInstance] setTable:table];
}

- (void)setLanguage:(NSString *)language
{
    [[KUSLocalization sharedInstance] setLanguage:language];
}

- (void)isChatAvailable:(void (^)(BOOL success, BOOL enabled))block
{
    [self.userSession.chatSettingsDataSource isChatAvailable:^(BOOL success, BOOL enabled) {
        if(success && enabled) {
            //Chat Settings is enabled
            //Check if within Business Hours and outside of Holidays
            [self checkBusinessHoursAvailability:block];
        }else if(success){
            block(YES,NO);
        }else{
            block(NO,NO);
        }
    }];
}

- (void)checkBusinessHoursAvailability:(void (^)(BOOL success, BOOL enabled))block
{
    //Check if Business Schedule was already fetched
    if([self.userSession.scheduleDataSource didFetch]) {
        block(YES,[self.userSession.scheduleDataSource isActiveBusinessHours]);
    }else{
        //Fetch Business Schedule and check if within Business Hours and outside of Holidays
        [self.userSession.scheduleDataSource fetchBusinessHours:block];
    }
}

- (void)setFormId:(NSString *)formId
{
    [self.userSession.userDefaults setFormId:formId];
}

- (NSInteger)openConversationsCount
{
    return [self.userSession.userDefaults openChatSessionsCount];
}

- (void)hideNewConversationButtonInClosedChat:(BOOL)status
{
    [self.userSession.userDefaults setShouldHideNewConversationButtonInClosedChat:status];
}

- (void)presentSupportWithMessage:(NSString *) message formId:(NSString *)formId customAttributes:(NSDictionary<NSString *, NSObject *> *)customAttributes
{
    NSAssert(message.length, @"Requires a valid message to create chat session.");
    if (message.length == 0) {
        return;
    }
    
    if (formId != nil) {
        [self.userSession.chatSessionsDataSource setFormIdForConversationalForm:formId];
    }
    
    [self.userSession.chatSessionsDataSource setMessageToCreateNewChatSession:message];
    
    if (customAttributes.count) {
        [self describeNextConversation:customAttributes];
    }
    
    [Kustomer presentSupport];
}

- (void)presentSupportWithAttributes:(KUSChatAttributes)attributes
{
    NSString *message = [attributes objectForKey:kKUSMessageAttribute];
    BOOL isValidMessage = message != nil &&
                            [message isKindOfClass:[NSString class]] &&
                            message.length != 0;
    if (isValidMessage) {
        [self.userSession.chatSessionsDataSource setMessageToCreateNewChatSession:message];
    }

    NSString *formId = [attributes objectForKey:kKUSFormIdAttribute];
    BOOL isValidFormId = formId != nil &&
                            [formId isKindOfClass:[NSString class]] &&
                            formId.length != 0;
    if (isValidFormId) {
        [self.userSession.chatSessionsDataSource setFormIdForConversationalForm:formId];
    }
    
    NSString *scheduleId = [attributes objectForKey:kKUSScheduleIdAttribute];
    BOOL isValidScheduleId = scheduleId != nil &&
                                [scheduleId isKindOfClass:[NSString class]] &&
                                scheduleId.length != 0;
    if (isValidScheduleId) {
        [self.userSession.scheduleDataSource setScheduleId:scheduleId];
    }
    NSDictionary<NSString *, NSObject *> *customAttributes = [attributes objectForKey:kKUSCustomAttributes];
    BOOL hasCustomAttributes = customAttributes != nil &&
                                [customAttributes isKindOfClass:[NSDictionary class]] &&
                                customAttributes.count != 0;
    if (hasCustomAttributes) {
        [self describeNextConversation:customAttributes];
    }
    [Kustomer presentSupport];
}

#pragma mark - Helper functions

NS_INLINE NSString *paddedBase64String(NSString *base64String) {
    if (base64String.length % 4) {
        NSUInteger paddedLength = base64String.length + (4 - (base64String.length % 4));
        return [base64String stringByPaddingToLength:paddedLength withString:@"=" startingAtIndex:0];
    }
    return base64String;
}

NS_INLINE NSDictionary<NSString *, NSString *> *jsonFromBase64EncodedJsonString(NSString *base64EncodedJson) {
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:base64EncodedJson options:kNilOptions];
    return [NSJSONSerialization JSONObjectWithData:decodedData options:kNilOptions error:NULL];
}

NS_INLINE UIViewController *KUSTopMostViewController() {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *rootViewController = keyWindow.rootViewController;
    UIViewController *topMostViewController = rootViewController;
    while (topMostViewController && topMostViewController.presentedViewController) {
        topMostViewController = topMostViewController.presentedViewController;
    }
    return topMostViewController;
}

@end
