//
//  KUSChatMessagesDataSource.m
//  Kustomer
//
//  Created by Daniel Amitay on 7/23/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSChatMessagesDataSource.h"

#import "KUSAudio.h"
#import "KUSLog.h"
#import "KUSPaginatedDataSource_Private.h"
#import "KUSUserSession_Private.h"
#import "KUSDate.h"
#import "KUSUpload.h"
#import "KUSSessionQueuePollingManager.h"
#import "KUSSatisfactionResponse.h"
#import "KUSObjectDataSource_Private.h"
#import "KUSVolumeControlTimerManager.h"
#import <SDWebImage/SDImageCache.h>
#import "KUSMediaAttachment.h"

static const NSTimeInterval KUSChatAutoreplyDelay = 1.0;
static const NSTimeInterval KUSChatDeflectMessageDelay = 1.0;
static const NSTimeInterval KUSChatDeflectMessageAdditonalDelayForArticles = 1.0;
static const NSTimeInterval kKUSResendTypingStatusDelay = 3.0 * 1000;
static const NSTimeInterval kKUSTypingEndDelay = 5.0;

@interface KUSChatMessagesDataSource () <KUSChatMessagesDataSourceListener, KUSObjectDataSourceListener, KUSSessionQueuePollingListener, KUSVolumeControlTimerListener, KUSPushClientListener> {
    NSString *_Nullable _sessionId;
    BOOL _createdLocally;

    NSMutableSet<NSString *> *_delayedChatMessageIds;

    KUSForm *_form;
    NSInteger _questionIndex;
    KUSFormQuestion *_formQuestion;
    BOOL _submittingForm;
    BOOL _creatingSession;
    BOOL _isChatEnding;

    NSInteger _vcformQuestionIndex;
    BOOL _vcTrackingStarted;
    BOOL _vcTrackingDelayCompleted;
    BOOL _vcFormActive;
    BOOL _vcFormEnd;
    BOOL _vcChatClosed;
    BOOL _isProactiveCampaign;
    NSMutableArray<KUSChatMessage *> *_temporaryVCMessagesResponses;
    
    BOOL _nonBusinessHours;
    
    KUSSessionQueuePollingManager *sessionQueuePollingManager;
    KUSFormDataSource *_formDataSource;
    
    // Typing indicator variables
    NSDate *_lastTypingStatusSentAt;
    KUSTimer *_endTypingTimer;
    KUSTimer *_hideTypingTimer;
    KUSTypingIndicator *_typingIndicator;
    
    NSMutableArray<void(^)(BOOL success, NSError *error)> *_onSessionCreationCallbacks;
    NSMutableDictionary<NSString *, void(^)(void)> *_messageRetryBlocksById;
    
    BOOL _didAgentReply;
}
@property (nonatomic, strong) KUSSatisfactionResponseDataSource *satisfactionResponseDataSource;

@end

@implementation KUSChatMessagesDataSource

#pragma mark - Lifecycle methods

- (instancetype)_initWithUserSession:(KUSUserSession *)userSession
{
    self = [super initWithUserSession:userSession];
    if (self) {
        _questionIndex = -1;
        _vcformQuestionIndex = 0;
        _vcFormActive = NO;
        _vcChatClosed = NO;
        _nonBusinessHours = NO;
        _isChatEnding = NO;
        _afterActuallySubmitFormMessages = ^void(NSString* input) {
              
        };
        _temporaryVCMessagesResponses = [[NSMutableArray alloc] init];
        _delayedChatMessageIds = [[NSMutableSet alloc] init];
        _messageRetryBlocksById = [[NSMutableDictionary alloc] init];

        [self.userSession.chatSettingsDataSource addListener:self];
        [self addListener:self];
    }
    return self;
}

- (instancetype)initForNewConversationWithUserSession:(KUSUserSession *)userSession formId:(NSString *)formId
{
    self = [self _initWithUserSession:userSession];
    if (self) {
        _createdLocally = YES;
        if (formId) {
            _formDataSource = [[KUSFormDataSource alloc] initWithUserSession:userSession formId:formId];
        } else {
            _formDataSource = self.userSession.formDataSource;
        }
        [_formDataSource addListener:self];
        [_formDataSource fetch];
    }
    return self;
}

- (instancetype)initWithUserSession:(KUSUserSession *)userSession sessionId:(NSString *)sessionId;
{
    NSAssert(sessionId.length, @"Cannot create messages datasource without valid sessionId");
    self = [self _initWithUserSession:userSession];
    if (self) {
        _sessionId = sessionId;
    }
    return self;
}

#pragma mark - KUSVolumeControlTimerListener methods

- (void)volumeControlTimerDidComplete:(KUSTimer *)timer
{
    _vcTrackingDelayCompleted = YES;
    [self _insertVolumeControlFormMessageIfNecessary];

}

#pragma mark - KUSObjectDataSourceListener methods

- (void)objectDataSourceDidLoad:(KUSObjectDataSource *)dataSource
{
    if ([dataSource isKindOfClass:[KUSSatisfactionResponseDataSource class]]) {
        for (id<KUSChatMessagesDataSourceListener> listener in [self.listeners copy]) {
            if ([listener respondsToSelector:@selector(chatMessagesDataSourceDidFetchSatisfactionForm:)]) {
                [listener chatMessagesDataSourceDidFetchSatisfactionForm:self];
            }
        }
        return;
    }
    
    if (_form == nil && [dataSource isKindOfClass:[KUSFormDataSource class]]) {
        _form = dataSource.object;
        if (_form != nil && _form.questions.count == 0) {
            [self _clearFormAndSendMessageIfNecessary];
        }
    }
    
    [self _insertFormMessageIfNecessary];
}

- (void)objectDataSource:(KUSObjectDataSource *)dataSource didReceiveError:(NSError *)error
{
    if ([dataSource isKindOfClass:[KUSSatisfactionResponseDataSource class]]) {
        return;
    }
    
    if ([dataSource isKindOfClass:[KUSFormDataSource class]]) {
        NSNumber *statusCode = error.userInfo[@"status"];
        if (statusCode != nil && [statusCode integerValue] == 400) {
            [self _clearFormAndSendMessageIfNecessary];
            return;
        }
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [dataSource fetch];
    });
}

#pragma mark - KUSPaginatedDataSource methods

- (void)addListener:(id<KUSChatMessagesDataSourceListener>)listener
{
    [super addListener:listener];
}

- (NSURL *)firstURL
{
    if ([self isActualSessionExist]) {
        NSString *endpoint = [NSString stringWithFormat:@"/c/v1/chat/sessions/%@/messages", _sessionId];
        return [self.userSession.requestManager URLForEndpoint:endpoint];
    }
    return nil;
}

- (Class)modelClass
{
    return [KUSChatMessage class];
}

- (NSArray<NSSortDescriptor *> *)sortDescriptors
{
    return @[
        [NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:NO],
        [NSSortDescriptor sortDescriptorWithKey:@"oid" ascending:NO]
    ];
}

- (BOOL)didFetch
{
    if (_createdLocally) {
        return YES;
    }
    return [super didFetch];
}

- (BOOL)didFetchAll
{
    if (_createdLocally) {
        return YES;
    }
    return [super didFetchAll];
}

#pragma mark - KUSSessionQueuePollingListener methods

- (void)sessionQueuePollingManager:(KUSSessionQueuePollingManager *)manager didUpdateSessionQueue:(KUSSessionQueue *)sessionQueue
{
    KUSChatSettings *chatSettings           = self.userSession.chatSettingsDataSource.object;
    BOOL estimatedWaitTimeIsOverThreshold   = sessionQueue.estimatedWaitTimeSeconds != 0 &&
                                              sessionQueue.estimatedWaitTimeSeconds > chatSettings.upfrontWaitThreshold;
    
    if (!_vcTrackingDelayCompleted && estimatedWaitTimeIsOverThreshold) {
        [self _startVolumeControlFormTrackingAfterDelay:0.0f];
        
        if (chatSettings.markDoneAfterTimeout) {
            [self _endVolumeControlFormAfterDelayIfNecessary:(chatSettings.timeOut ?: 0.0f)];
        }
    }
}

#pragma mark - Push Client methods

- (void)pushClient:(KUSPushClient *)pushClient didChange:(KUSTypingIndicator *)typingIndicator
{
    if (![typingIndicator.oid isEqualToString:_sessionId]) {
        return;
    }
    
    BOOL shouldNotifyUpdate = _typingIndicator == nil || ![_typingIndicator isEqual:typingIndicator];
    if (shouldNotifyUpdate) {
        _typingIndicator = typingIndicator;
        [self notifyAnnouncersDidReceiveTypingUpdate];
    }
    
    if (typingIndicator.typingStatus == KUSTyping) {
        [self _hideTypingIndicatorAfterDelay];
    }
}

#pragma mark - Internal Logic methods

- (void)_clearFormAndSendMessageIfNecessary
{
    if ([self isActualSessionExist]) {
        return;
    }
    _formDataSource = nil;
    if (self.allObjects.count) {
        KUSChatMessage *firstMessage = self.allObjects.lastObject;
        [self removeObjects:self.allObjects];
        [self sendMessageWithText:firstMessage.body attachments:nil];
    }
}

- (void)_startVolumeControlFormTrackingAfterDelay:(NSTimeInterval)delay
{
    [[KUSVolumeControlTimerManager sharedInstance] createVolumeControlTimerForSession:_sessionId
                                                                           listener:self
                                                                              delay:delay];
}

- (void)_endVolumeControlFormAfterDelayIfNecessary:(NSTimeInterval)delay
{
    __weak KUSChatMessagesDataSource *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong KUSChatMessagesDataSource *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        // End Control Tracking and Automatically marked it Closed, if form not end
        if (!strongSelf->_vcFormEnd && [UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
            [strongSelf endChat:@"timed_out" withCompletion:^(BOOL ended) {
                if (ended) {
                    [strongSelf _endVolumeControlTracking];
                }
            }];
        }
    });
}

- (void)_closeProactiveCampaignIfNecessary
{
    KUSChatSettings *settings = [self.userSession.chatSettingsDataSource object];
    if (settings.singleSessionChat) {
        NSMutableDictionary<NSString *, KUSChatMessagesDataSource *> *chatMessagesDSDic = self.userSession.chatMessagesDataSources;
        NSArray * chatMessagesDatasources = [chatMessagesDSDic allValues];
        
        for (KUSChatMessagesDataSource *chatMsgDataSource in chatMessagesDatasources) {
            if (![chatMsgDataSource isAnyMessageByCurrentUser]) {
                [self.userSession.chatSessionsDataSource updateLastSeenAtForSessionId:chatMsgDataSource.sessionId completion:nil];
                [chatMsgDataSource endChat:@"customer_ended" withCompletion:nil];
            }
        }
    }
}

- (void)_hideTypingIndicatorAfterDelay
{
    if (_hideTypingTimer) {
        [_hideTypingTimer invalidate];
        _hideTypingTimer = nil;
    }
    _hideTypingTimer = [KUSTimer scheduledTimerWithTimeInterval:kKUSTypingEndDelay
                                                                  target:self
                                                                selector:@selector(typingHideDelayComplete:)
                                                                 repeats:NO];
}

#pragma mark - Internal listener methods

- (void)notifyAnnouncersDidReceiveTypingUpdate
{
    for (id<KUSChatMessagesDataSourceListener> listener in [self.listeners copy]) {
        if ([listener respondsToSelector:@selector(chatMessagesDataSource:didReceiveTypingUpdate:)]) {
            [listener chatMessagesDataSource:self didReceiveTypingUpdate:_typingIndicator];
        }
    }
}

#pragma mark - Public methods

- (KUSSatisfactionResponseDataSource *)satisfactionResponseDataSource
{
    if (_satisfactionResponseDataSource == nil && [self isActualSessionExist]) {
        _satisfactionResponseDataSource = [[KUSSatisfactionResponseDataSource alloc] initWithUserSession:self.userSession AndSessionId:_sessionId];
        [_satisfactionResponseDataSource addListener:self];
    }
    return _satisfactionResponseDataSource;
}

- (NSString *)sessionId
{
    return _sessionId;
}

- (BOOL)isActualSessionExist
{
    return _sessionId && ![_sessionId isEqual:kKUSTempSessionId];
}

- (BOOL)shouldAllowAttachments
{
    return [self isActualSessionExist] && !_vcFormActive;
}

- (BOOL)isAnyMessageByCurrentUser
{
    for (KUSChatMessage *message in self.allObjects) {
        if (KUSChatMessageSentByUser(message)) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)didAgentReply
{
    if(!_didAgentReply) {
        
        for (KUSChatMessage *message in self.allObjects) {
            if (!KUSChatMessageSentByUser(message) && message.sentById) {
                _didAgentReply = true;
                break;
            }
        }
    }
    
    return _didAgentReply;
}

- (NSString *)firstOtherUserId
{
    for (KUSChatMessage *message in self.allObjects) {
        if (!KUSChatMessageSentByUser(message)) {
            return message.sentById;
        }
    }
    return nil;
}

- (NSArray<NSString *> *)otherUserIds
{
    NSMutableSet<NSString *> *userIdsSet = [[NSMutableSet alloc] init];
    NSMutableArray<NSString *> *otherUserIds = [[NSMutableArray alloc] init];
    for (KUSChatMessage *message in self.allObjects) {
        if (!KUSChatMessageSentByUser(message)) {
            NSString *sentById = message.sentById;
            if (sentById && ![userIdsSet containsObject:sentById]) {
                [userIdsSet addObject:sentById];
                [otherUserIds addObject:sentById];
            }
        }
    }
    return otherUserIds;
}

- (NSUInteger)unreadCountAfterDate:(NSDate *)date
{
    NSUInteger count = 0;
    for (KUSChatMessage *message in self.allObjects) {
        if (KUSChatMessageSentByUser(message)) {
            return count;
        }
        if (message.createdAt) {
            if ([message.createdAt compare:date] == NSOrderedAscending) {
                return count;
            }
            count++;
        }
    }
    return count;
}

- (BOOL)shouldPreventSendingMessage
{
    // If we haven't loaded the chat settings data source, prevent input
    if (!self.userSession.chatSettingsDataSource.didFetch) {
        return YES;
    }

    // If we are about to insert an artificial message, prevent input
    if (_delayedChatMessageIds.count > 0) {
        return YES;
    }

    // When submitting the form or creating session, prevent sending more responses
    if (_submittingForm || _creatingSession) {
        return YES;
    }

    // If the user sent their first message and it is not yet sent, prevent input
    KUSChatMessage *firstMessage = self.allObjects.lastObject;
    if (![self isActualSessionExist]
        && [self count] == 1
        && firstMessage.state != KUSChatMessageStateSent) {
        return YES;
    }

    return NO;
}

- (KUSFormQuestion *)currentQuestion
{
    if ([self isActualSessionExist]) {
        return nil;
    }
    if (KUSChatMessageSentByUser([self latestMessage])) {
        return nil;
    }
    return _formQuestion;
}

- (KUSFormQuestion *)volumeControlCurrentQuestion
{
    if (!_vcFormActive) {
        return nil;
    }
    if (![self isActualSessionExist]) {
        return nil;
    }
    
    KUSChatSettings *chatSettings = self.userSession.chatSettingsDataSource.object;
    if (!chatSettings.volumeControlEnabled) {
        return nil;
    }
    
    if (_vcFormEnd) {
        return nil;
    }
    
    if ([[self otherUserIds] count] > 0) {
        return nil;
    }
    
    return _formQuestion;
}

- (BOOL)isChatClosed
{
    // For business hours
    if (_nonBusinessHours) {
        return true;
    }
    
    if (_vcFormActive) {
        return false;
    }
    if (![self isActualSessionExist]) {
        return false;
    }
    
    KUSChatSettings *chatSettings = self.userSession.chatSettingsDataSource.object;
    if (!chatSettings.volumeControlEnabled) {
        return false;
    }
    
    if ([[self otherUserIds] count] > 0) {
        return false;
    }
    
    if (_vcChatClosed) {
        return true;
    }
    
    return false;
}

- (KUSChatMessage *)latestMessage
{
    if (self.count > 0) {
        return [self objectAtIndex:0];
    }
    return nil;
}

- (void)upsertNewMessages:(NSArray<KUSChatMessage *> *)chatMessages
{
    if (chatMessages.count == 1) {
        [self upsertObjects:chatMessages];
    } else if (chatMessages.count > 1) {
        NSMutableArray<KUSChatMessage *> *reversedMessages = [[NSMutableArray alloc] initWithCapacity:chatMessages.count];
        for (KUSChatMessage *chatMessage in chatMessages.reverseObjectEnumerator) {
            [reversedMessages addObject:chatMessage];
        }
        [self upsertObjects:reversedMessages];
    }
}

- (void)sendMessageWithText:(NSString *)text attachments:(NSArray<KUSMediaAttachment *> *)attachments
{
    [self sendMessageWithText:text attachments:attachments value:nil];
}

- (void)sendMessageWithText:(NSString *)text attachments:(NSArray<KUSMediaAttachment *> *)attachments value:(NSString *)value
{
    _isProactiveCampaign = ([self allObjects].count > 0) && ![self isAnyMessageByCurrentUser];
    if ([_formDataSource getConversationalFormId] && ![self isActualSessionExist]) {
        NSAssert(attachments.count == 0, @"Should not have been able to send attachments without a _sessionId");
        
        
        if (_sessionId == nil) {
            NSDictionary *json = @{
                   @"type": @"chat_message",
                   @"id": [[NSUUID UUID] UUIDString],
                   @"attributes": @{
                       @"body": text,
                       @"direction": @"in",
                       @"createdAt": [KUSDate stringFromDate:[NSDate date]]
                    },
                   @"relationships": @{
                       @"session" : @{
                           @"data": @{
                               @"id": kKUSTempSessionId
                               }
                           }
                       }
            };

            KUSChatMessage *temporaryMessage = [[KUSChatMessage alloc] initWithJSON: json];
            KUSChatSession *temporarySession = [KUSChatSession tempSessionFromChatMessage:temporaryMessage];
            [self upsertNewMessages: @[ temporaryMessage ]];
            [self.userSession.chatSessionsDataSource upsertNewSessions:@[ temporarySession ]];
            _sessionId = kKUSTempSessionId;
            [self.userSession.chatMessagesDataSources setObject:self forKey:_sessionId];
            // Notify listeners
            for (id<KUSChatMessagesDataSourceListener> listener in [self.listeners copy]) {
                if ([listener respondsToSelector:@selector(chatMessagesDataSource:didCreateSessionId:)]) {
                    [listener chatMessagesDataSource:self didCreateSessionId:kKUSTempSessionId];
                }
            }

            
        } else if ([_sessionId  isEqual: kKUSTempSessionId]) {
            NSDictionary *json = @{
                                   @"type": @"chat_message",
                                   @"id": [[NSUUID UUID] UUIDString],
                                   @"attributes": @{
                                           @"body": text,
                                           @"direction": @"in",
                                           @"createdAt": [KUSDate stringFromDate:[NSDate date]]
                                           }
                                   };
            KUSChatMessage *temporaryMessage = [[KUSChatMessage alloc] initWithJSON: json];
            temporaryMessage.value = value;
            [self upsertNewMessages: @[ temporaryMessage ]];
        }
        
        return;
    }
    else if  ([self isActualSessionExist] && _vcFormActive) {
        NSAssert(attachments.count == 0, @"Should not have been able to send attachments without a _sessionId");
        
        NSDictionary *json = @{
            @"type": @"chat_message",
            @"id": [[NSUUID UUID] UUIDString],
            @"attributes": @{
                @"body": text,
                @"direction": @"in",
                @"createdAt": [KUSDate stringFromDate:[NSDate date]]
            }
        };
        NSArray<KUSChatMessage *> *temporaryMessages = [KUSChatMessage objectsWithJSON:json];
        for (KUSChatMessage *temporaryMessage in temporaryMessages) {
            temporaryMessage.value = value;
            [_temporaryVCMessagesResponses addObject:temporaryMessage];
        }
        
        [self upsertNewMessages:temporaryMessages];
        
        return;
    }

    [self _actuallySendMessageWithText:text attachments:attachments];
}

- (void)_createSessionIfNecessaryWithTitle:(NSString *)title completion:(void(^)(BOOL success, NSError *error))completion
{
    if ([self isActualSessionExist]) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(YES, nil);
            });
        }
    } else {
        if (_onSessionCreationCallbacks) {
            if (completion) {
                [_onSessionCreationCallbacks addObject:completion];
            }
        } else {
            _onSessionCreationCallbacks = [[NSMutableArray alloc] initWithObjects:completion, nil];

            _creatingSession = YES;
            [self.userSession.chatSessionsDataSource
             createSessionWithTitle:title
             completion:^(NSError *error, KUSChatSession *session) {
                 NSArray<void(^)(BOOL success, NSError *error)> *callbacks = [_onSessionCreationCallbacks copy];
                 _onSessionCreationCallbacks = nil;

                 if (error || session == nil) {
                     KUSLogError(@"Error creating session: %@", error);
                     for (void(^callback)(BOOL success, NSError *error) in callbacks) {
                         callback(NO, error);
                     }
                     return;
                 }
                 
                 if (![self isActualSessionExist] && _sessionId != nil) {
                     KUSChatSession *tempSession = [self.userSession.chatSessionsDataSource objectWithId:_sessionId];
                     [self.userSession.chatMessagesDataSources removeObjectForKey:_sessionId];
                     [self.userSession.chatSessionsDataSource removeObjects: @[tempSession]];
                 }

                 // Grab the session id
                 _sessionId = session.oid;
                 _creatingSession = NO;

                 // Create queue polling manager for volume control form
                 sessionQueuePollingManager = [[KUSSessionQueuePollingManager alloc] initWithUserSession:self.userSession sessionId:session.oid];
                 
                 // Insert the current messages data source into the userSession's lookup table
                 [self.userSession.chatMessagesDataSources setObject:self forKey:session.oid];

                 // Notify listeners
                 for (id<KUSChatMessagesDataSourceListener> listener in [self.listeners copy]) {
                     if ([listener respondsToSelector:@selector(chatMessagesDataSource:didCreateSessionId:)]) {
                         [listener chatMessagesDataSource:self didCreateSessionId:session.oid];
                     }
                 }

                 for (void(^callback)(BOOL success, NSError *error) in callbacks) {
                     callback(YES, nil);
                 }
             }];
        }
    }
}

- (void)_actuallySendMessageWithText:(NSString *)text attachments:(NSArray<KUSMediaAttachment *> *)attachments
{
    NSString *tempMessageId = [[NSUUID UUID] UUIDString];
    NSMutableArray<NSDictionary<NSString *, NSString *> *> *attachmentObjects = [[NSMutableArray alloc] initWithCapacity:attachments.count];
    NSMutableArray<NSString *> *cachedImageKeys = [[NSMutableArray alloc] initWithCapacity:attachments.count];
    for (KUSMediaAttachment *attachment in attachments) {
        NSString *attachmentId = [[NSUUID UUID] UUIDString];
        NSURL *attachmentURL = [KUSChatMessage attachmentURLForMessageId:tempMessageId attachmentId:attachmentId];
        NSString *imageKey = attachmentURL.absoluteString;
        [[SDImageCache sharedImageCache] storeImage:attachment.fullSizeImage
                                             forKey:imageKey
                                             toDisk:NO
                                         completion:nil];
        [attachmentObjects addObject:@{ @"id": attachmentId }];
        [cachedImageKeys addObject:imageKey];
    }

    NSMutableDictionary *json = [[NSMutableDictionary alloc] initWithDictionary:@{
        @"type": @"chat_message",
        @"id": tempMessageId,
        @"attributes": @{
            @"direction": @"in",
            @"createdAt": [KUSDate stringFromDate:[NSDate date]]
        },
        @"relationships": @{
            @"attachments" : @{
                @"data": attachmentObjects
            }
        }
    }];
    if (text.length != 0) {
        [json setObject:text forKey:@"attributes.body"];
    }
    
    NSArray<KUSChatMessage *> *temporaryMessages = [KUSChatMessage objectsWithJSON:json];
    // temporaryMessages[0].isVerifiedAnAttachment = NO;
    // temporaryMessages[0].isVerifiedAnImage = YES;
    // temporaryMessages[1].isVerifiedAnAttachment = YES;
    // temporaryMessages[1].isVerifiedAnImage = NO;
    
    
    // Insert the messages
    void(^insertMessagesWithState)(KUSChatMessageState) = ^void(KUSChatMessageState state) {
        [self removeObjects:temporaryMessages];
        for (KUSChatMessage *message in temporaryMessages) {
            message.state = state;
        }
        [self upsertNewMessages:temporaryMessages];
    };

    // Logic to handle a chat session error or a message send error
    void(^handleError)(void) = ^void() {
        insertMessagesWithState(KUSChatMessageStateFailed);
    };

    // Logic to handle a successful message send
    void(^handleMessageSent)(NSDictionary *) = ^void(NSDictionary *response) {
        NSArray<KUSChatMessage *> *finalMessages = [KUSChatMessage objectsWithJSON:response[@"data"]];
        
        // finalMessages[0].isVerifiedAnAttachment = NO;
        // finalMessages[0].isVerifiedAnImage = YES;
        // finalMessages[0].isVerifiedAnAttachment = NO;
        // finalMessages[0].isVerifiedAnImage = YES;
        // finalMessages[1].isVerifiedAnAttachment = YES;
        // finalMessages[1].isVerifiedAnImage = NO;
        
        // Store the local image data in our cache for the remote image urls
        KUSChatMessage *firstMessage = finalMessages.firstObject;
        NSString *messageId = [firstMessage.oid componentsSeparatedByString:@"_"].firstObject ?: firstMessage.oid;
        for (NSUInteger i = 0; i < firstMessage.attachmentIds.count; i++) {
            KUSMediaAttachment *attachment = [attachments objectAtIndex:i];
            NSString *attachmentId = [firstMessage.attachmentIds objectAtIndex:i];
            NSURL *attachmentURL = [KUSChatMessage attachmentURLForMessageId:messageId attachmentId:attachmentId];
            [[SDImageCache sharedImageCache] storeImage:attachment.fullSizeImage
                                                 forKey:attachmentURL.absoluteString
                                                 toDisk:YES
                                             completion:nil];
        }

        // Remove the temporary objects and insert the new/sent objects
        [self removeObjects:temporaryMessages];
        [self upsertNewMessages:finalMessages];

        // Remove the temporary images from the cache
        for (NSString *imageKey in cachedImageKeys) {
            [[SDImageCache sharedImageCache] removeImageForKey:imageKey fromDisk:NO withCompletion:nil];
        }

        // Remove the retry blocks
        for (KUSChatMessage *temporaryMessage in temporaryMessages) {
            [_messageRetryBlocksById removeObjectForKey:temporaryMessage.oid];
        }
        
        if (_isProactiveCampaign) {
            [self _closeProactiveCampaignIfNecessary];
        }
        
        // Update the locally session last seen
        [self.userSession.chatSessionsDataSource updateLocallyLastSeenAtForSessionId:_sessionId];

    };

    // Logic to actually send a message
    void (^sendMessage)(void) = ^void() {
        [KUSUpload
         uploadAttachments:attachments
         userSession:self.userSession
         completion:^(NSError *error, NSArray<KUSChatAttachment *> *attachments) {
             if (error) {
                 KUSLogError(@"Error uploading attachments: %@", error);
                 handleError();
                 return;
             }

             NSArray<NSString *> *attachmentIds = [attachments valueForKeyPath:@"@unionOfObjects.oid"];
             NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithDictionary:@{
                 @"session": _sessionId,
                 @"attachments": attachmentIds
             }];
             if (text.length != 0) {
                 [params setObject:text forKey:@"body"];
             }
             
             [self.userSession.requestManager
              performRequestType:KUSRequestTypePost
              endpoint:@"/c/v1/chat/messages"
              params:params
              authenticated:YES
              completion:^(NSError *error, NSDictionary *response) {
                  if (error) {
                      KUSLogError(@"Error sending message: %@", error);
                      handleError();
                      return;
                  }

                  handleMessageSent(response);
              }];
         }];
    };

    // Full encapsulating logic for sending the message
    void (^fullySendMessage)(void) = ^void() {
        insertMessagesWithState(KUSChatMessageStateSending);
        [self _createSessionIfNecessaryWithTitle:text completion:^(BOOL success, NSError *error) {
            if (success) {
                sendMessage();
            } else {
                handleError();
            }
        }];
    };

    for (KUSChatMessage *temporaryMessage in temporaryMessages) {
        _messageRetryBlocksById[temporaryMessage.oid] = fullySendMessage;
    }
    fullySendMessage();
}

- (void)resendMessage:(KUSChatMessage *)message
{
    if (message) {
        void(^retryBlock)(void) = _messageRetryBlocksById[message.oid];
        if (retryBlock) {
            retryBlock();
        }
    }
}

- (void)endChatForm
{
  _formQuestion.type = KUSFormQuestionTypeKBDeflectedSuccessfully;
  
  self.afterActuallySubmitFormMessages = ^void(NSString* input) {
      // if server auto-ends, force the UI to update as ended now. the lockedAt date will be wrong locally.
      KUSChatSession *session = [self.userSession.chatSessionsDataSource objectWithId:_sessionId];
      session.lockedAt = [[NSDate alloc] init];
      [self notifyAnnouncersDidEndChatSession];

      //or trigger end direct from client:
      //[self endChat:@"customer_ended" withCompletion:nil];
  };
}


- (void)endChat:(NSString *)reason withCompletion:(void (^)(BOOL))completion
{
    _isChatEnding = YES;
    [self.userSession.requestManager
     performRequestType:KUSRequestTypePut
     endpoint:[[NSString alloc] initWithFormat:@"/c/v1/chat/sessions/%@", _sessionId]
     params: @{ @"locked": @YES,
                @"lockReason": reason
              }
     authenticated:YES
     completion:^(NSError *error, NSDictionary *response) {
        _isChatEnding = NO;
         if (error) {
             if (completion != nil) {
                 completion(NO);
             }
             // Submit VCForm response if pending
             [self _insertVolumeControlFormMessageIfNecessary];
             return;
         }

         // Temporary set locked at to reflect changes in UI
         KUSChatSession *session = [self.userSession.chatSessionsDataSource objectWithId:_sessionId];
         session.lockedAt = [[NSDate alloc] init];
         
         [self notifyAnnouncersDidEndChatSession];
         
         if (completion != nil) {
             completion(YES);
         }
     }];
}

- (KUSSessionQueuePollingManager *)sessionQueuePollingManager
{
    return sessionQueuePollingManager;
}

- (void)mayGetSatisfactionFormIfAgentJoined
{
    if (![self isActualSessionExist]) {
        return;
    }
    
    
    
    KUSChatSession *chatSession = [self.userSession.chatSessionsDataSource objectWithId:_sessionId];
    BOOL isChatClosed = chatSession.lockedAt != nil;
    BOOL isSatisfactionResponseFetched = [self.satisfactionResponseDataSource didFetch];
    BOOL isSatisfactionFormEnabled = [self.satisfactionResponseDataSource isSatisfactionEnabled];
    BOOL hasAgentMessage = [self otherUserIds].count > 0;
  
    
    BOOL isSatisfactionFormCompleted = NO;
    if (chatSession.satisfactionLockedAt) {
        isSatisfactionFormCompleted = [[NSDate date] compare:chatSession.satisfactionLockedAt] != NSOrderedAscending;
    }
  
    KUSChatSettings *settings = self.userSession.chatSettingsDataSource.object;
    if (!settings || !settings.shouldShowTypingIndicatorWeb) {
      return;
    }
    
    if(settings.outboundMessagesOverride) {
      hasAgentMessage = YES;
    }
    
    BOOL passesAtLeastOneMessageByUserRestriction = NO;
    if(settings.inboundMessagesOverride) {
        passesAtLeastOneMessageByUserRestriction = YES;
    } else {
        //default. make sure at least one user msg
        passesAtLeastOneMessageByUserRestriction = [self isAnyMessageByCurrentUser];
    }
    
    BOOL needSatisfactionForm = isChatClosed && hasAgentMessage && !isSatisfactionFormCompleted && passesAtLeastOneMessageByUserRestriction;
    BOOL shouldFetchSatisfactionForm = !isSatisfactionResponseFetched && isSatisfactionFormEnabled && needSatisfactionForm;
    
    if (shouldFetchSatisfactionForm) {
        [self.satisfactionResponseDataSource fetch];
    }
}

- (BOOL)shouldShowSatisfactionForm
{
    if (![self isActualSessionExist]) {
        return NO;
    }
    KUSChatSession *session = [self.userSession.chatSessionsDataSource objectWithId:_sessionId];
    BOOL isSessionLocked = session && session.lockedAt;
    BOOL isSatisfactionResponseFetched = [self.satisfactionResponseDataSource didFetch];
    BOOL shouldShowSatisfactionForm = isSessionLocked && isSatisfactionResponseFetched;
    return shouldShowSatisfactionForm;
}

- (void)sendTypingStatusToPusher:(KUSTypingStatus)typingStatus
{
    NSString *customerId = [self _customerId];
    if (!customerId) {
        return;
    }
    
    KUSChatSettings *settings = self.userSession.chatSettingsDataSource.object;
    if (!settings || !settings.shouldShowTypingIndicatorWeb) {
        return;
    }
    
    NSDate *currentDate = [NSDate date];
    NSTimeInterval now = [currentDate timeIntervalSince1970] * 1000;
    NSTimeInterval lastSent = [_lastTypingStatusSentAt timeIntervalSince1970] * 1000;
    BOOL isResendDelayOver = now - lastSent > kKUSResendTypingStatusDelay;
    
    BOOL shouldSendStatus = typingStatus == KUSTypingEnded || isResendDelayOver;
    if (!shouldSendStatus) {
        return;
    }
    
    NSNumber *createdAt = [NSNumber numberWithLongLong:now];
    NSDictionary *activityData = @{
        @"type": @"conversation",
        @"id": _sessionId,
        @"userId": customerId,
        @"status": typingStatus == KUSTyping ? @"typing" : @"typing-ended",
        @"userType": @"customer",
        @"createdAt": createdAt
    };
    
    [self.userSession.pushClient sendChatActivityForSessionId:_sessionId
                                                 activityData:activityData];
    
    if (typingStatus == KUSTyping) {
        _lastTypingStatusSentAt = currentDate;
        [self sendTypingEndedStatusAfterDelay];
    }
    else if (typingStatus == KUSTypingEnded && _endTypingTimer) {
        [_endTypingTimer invalidate];
        _endTypingTimer = nil;
    }
}

- (void)sendTypingEndedStatusAfterDelay
{
    if (_endTypingTimer) {
        [_endTypingTimer invalidate];
        _endTypingTimer = nil;
    }
    _endTypingTimer = [KUSTimer scheduledTimerWithTimeInterval:kKUSTypingEndDelay
                                                       target:self
                                                     selector:@selector(typingEndDelayComplete:)
                                                      repeats:NO];
}

- (void)startListeningForTypingUpdate
{
    if (![self isActualSessionExist]) {
        return;
    }
    
    KUSChatSettings *chatSettings = self.userSession.chatSettingsDataSource.object;
    if (!chatSettings || !chatSettings.shouldShowTypingIndicatorCustomerWeb) {
        return;
    }
    
    KUSChatSession *chatSession = [self.userSession.chatSessionsDataSource objectWithId:_sessionId];
    if (!chatSession || chatSession.lockedAt) {
        return;
    }
    
    [self.userSession.pushClient connectToChatActivityChannel:_sessionId];
    [self.userSession.pushClient setListener:self];
}

- (void)stopListeningForTypingUpdate
{
    [self sendTypingStatusToPusher:KUSTypingEnded];
    [self.userSession.pushClient disconnectFromChatAcitvityChannel];
    [self.userSession.pushClient removeListener:self];
    
    [_hideTypingTimer invalidate];
    _hideTypingTimer = nil;
    
    _typingIndicator.typingStatus = KUSTypingEnded;
    [self notifyAnnouncersDidReceiveTypingUpdate];
}

- (void)notifyAnnouncersDidEndChatSession
{
    self.afterActuallySubmitFormMessages = ^void(NSString* input) {
      
    };
    for (id<KUSChatMessagesDataSourceListener> listener in [self.listeners copy]) {
        if ([listener respondsToSelector:@selector(chatMessagesDataSourceDidEndChatSession:)]) {
            [listener chatMessagesDataSourceDidEndChatSession:self];
        }
    }
}

#pragma mark - Timer Completion handler

- (void)typingEndDelayComplete:(KUSTimer *)timer
{
    [self sendTypingStatusToPusher:KUSTypingEnded];
}

- (void)typingHideDelayComplete:(KUSTimer *)timer
{
    _typingIndicator.typingStatus = KUSTypingEnded;
    [self notifyAnnouncersDidReceiveTypingUpdate];
}

#pragma mark - KUSChatMessagesDataSourceListener methods

- (void)paginatedDataSourceDidChangeContent:(KUSPaginatedDataSource *)dataSource
{
    [self _insertFormMessageIfNecessary];
    [self _insertVolumeControlFormMessageIfNecessary];
}

- (void)chatMessagesDataSource:(KUSChatMessagesDataSource *)dataSource didCreateSessionId:(NSString *)sessionId
{
    [self _startVolumeControlTracking];
    if(_isProactiveCampaign){
        [self _closeProactiveCampaignIfNecessary];
    }
}

- (void)chatMessagesDataSourceDidEndChatSession:(KUSChatMessagesDataSource *)dataSource
{
    // Cancel Volume Control Polling if necessary
    [sessionQueuePollingManager cancelPolling];
    
    // Fetch Customer Satisfaction Form If necessary
    [self mayGetSatisfactionFormIfAgentJoined];
}

- (void)_insertFormMessageIfNecessary
{
    if ([_formDataSource getConversationalFormId] == nil) {
        return;
    }
    if (_form == nil) {
      return;
    }
    if (!_form.proactive && [self count] == 0) {
        return;
    }
    if ([self isActualSessionExist]) {
        return;
    }

    KUSChatMessage *lastMessage = [self latestMessage];
    
    if ([self shouldPreventSendingMessage]) {
        return;
    }
    
    
    BOOL isResponseRequired = _formQuestion && [KUSFormQuestion KUSFormQuestionRequiresResponse: _formQuestion];
    BOOL isAnswered = KUSChatMessageSentByUser(lastMessage);
    if (isResponseRequired && !isAnswered) {
        return;
    }
    
    //000 >= not ==
    BOOL isLastQuestion = _questionIndex >= (NSInteger)(_form.questions.count - 1);
  
  
  
  
    BOOL endChat = (isLastQuestion || [KUSFormQuestion KUSFormQuestionIsEndChat: _formQuestion]);
    
    if (endChat && !_submittingForm) {
      
        //000 //set isAnswered to true if Response is not required for current question
        isAnswered = isResponseRequired ? isAnswered : true;
      
        if(isAnswered){
          [self _submitFormResponses];
          return;
        }
    }
    
    _questionIndex++;
    _formQuestion = _form.questions[_questionIndex];
    
    NSString* formQuestionId = _formQuestion.oid;
    NSDate* baseDate = lastMessage.createdAt ? lastMessage.createdAt : [[NSDate alloc] init];
    
    if(_formQuestion.type == KUSFormQuestionTypeKBDeflectResponse){
      [self searchKbForString:lastMessage.body completion:^void(NSArray* matches) {
        
        if(matches.count == 0){
          [self createFormQuestion:[NSString stringWithFormat:@"question_%@_0", formQuestionId]
                            prompt:[_formQuestion noResultResponse]
                     timeWithDelay:[baseDate dateByAddingTimeInterval:KUSChatDeflectMessageDelay]];
          
          _formQuestion.type = KUSFormQuestionTypeKBDeflectNoResponseFound;
        }else{
          [self createFormQuestion:[NSString stringWithFormat:@"question_%@_1", formQuestionId]
                            prompt:[_formQuestion hasResultResponse]
                     timeWithDelay:[baseDate dateByAddingTimeInterval:KUSChatDeflectMessageDelay]];
          
          for(NSMutableDictionary* article in matches) {
            [self createKBSearchResult:[NSString stringWithFormat:@"question_%@", formQuestionId]
                              article:article
                       timeWithDelay:[baseDate dateByAddingTimeInterval:KUSChatDeflectMessageDelay + KUSChatDeflectMessageAdditonalDelayForArticles]];
          }
          
          [self createFormQuestion:[NSString stringWithFormat:@"question_%@_2", formQuestionId]
                            prompt:[_formQuestion followUpQuestion]
                     timeWithDelay:[baseDate dateByAddingTimeInterval:KUSChatDeflectMessageDelay + KUSChatDeflectMessageAdditonalDelayForArticles + 1.3]];
        }
      }];
    } else {
      [self createFormQuestion:[NSString stringWithFormat:@"question_%@", _formQuestion.oid]
                        prompt:_formQuestion.prompt
                   timeWithDelay:[baseDate dateByAddingTimeInterval:KUSChatDeflectMessageDelay]];
      // [self insertMessageForFormQuestion:_formQuestion withLastMessage:lastMessage];
    }
}

#pragma mark - KB deflect changes
- (void)searchKbForString:(NSString *)string completion:(void(^)(NSArray * matches))completion
{
  NSString *searchKbString = [NSString stringWithFormat:@"/c/v1/kb/deflection/chat?term=%@&pageSize=3", string];
  [[Kustomer sharedInstance].userSession.requestManager
   performRequestType:KUSRequestTypeGet
   endpoint:searchKbString
   params: @{ }
   authenticated:YES
   completion:^(NSError *error, NSDictionary *response) {
    if (error) {
      return;
    }
    NSArray *rawData = [response valueForKeyPath:@"data"];
    NSMutableArray *matches = [@[] mutableCopy]; //[[NSMutableArray alloc] init];
    
    NSInteger maxItems = 3;
    NSInteger itemCounter = 0;
    for(NSDictionary* articleDict in rawData){
      if(itemCounter > maxItems){
        break;
      }
      itemCounter++;
      NSString* lang = [articleDict valueForKeyPath:@"attributes.lang"];
      NSString* slug = [articleDict valueForKeyPath:@"attributes.slug"];
      NSString* hash = [articleDict valueForKeyPath:@"attributes.hash"];
      NSString* title = [articleDict valueForKeyPath:@"attributes.title"];
      NSString* articleId = [articleDict valueForKeyPath:@"id"];
      NSString* urlOfArticle = [NSString stringWithFormat:@"https://%@.kustomer.help/%@/%@-%@", [Kustomer sharedInstance].userSession.orgName, lang, slug, hash];
      
      [matches addObject:[@{
        @"id": articleId,
        @"url": urlOfArticle,
        @"title": title,
        @"viewCount": @"0"
      } mutableCopy]];
    }
    completion(matches);
  }];
    
}
- (KUSChatMessage*)getLatestMessage
{
  return [self latestMessage];
}
- (void)createFormQuestion:(NSString *)questionId prompt:(NSString*)prompt timeWithDelay:(NSDate*)timeWithDelay
{
  NSDate *createdAt = timeWithDelay;
  NSDictionary *json = @{
    @"type": @"chat_message",
    @"id": questionId,
    @"attributes": @{
        @"body": prompt,
        @"direction": @"out",
        @"createdAt": [KUSDate stringFromDate:createdAt]
    }
  };
  KUSChatMessage *formMessage = [[KUSChatMessage alloc] initWithJSON:json];
  [self _insertDelayedMessage:formMessage];
}
- (void)createKBSearchResult:(NSString *)questionId article:(NSMutableDictionary*)article timeWithDelay:(NSDate*)timeWithDelay
{
  NSDate *createdAt = timeWithDelay;
  NSDictionary *json = @{
    @"type": @"chat_message",
    @"id": [NSString stringWithFormat:@"%@_article_%@", questionId, [article valueForKey:@"id"]],
    @"attributes": @{
      @"body": [NSString stringWithFormat:@"📖 [%@](%@)", [article valueForKey:@"title"], [article valueForKey:@"url"]],
      @"direction": @"out",
      @"createdAt": [KUSDate stringFromDate:createdAt],
      @"kbDeflectUrl": [article valueForKey:@"url"]
    }
  };

  KUSChatMessage *formMessage = [[KUSChatMessage alloc] initWithJSON:json];
  formMessage.type = KUSChatMessageTypeArticle;
  [formMessage setKbArticle:article];
  [self _insertDelayedMessage:formMessage];
}

#pragma mark - KB deflect unused
- (void)xxcreateFormQuestion:(KUSFormQuestion *)question withLastMessage:(KUSChatMessage*)lastMessage
{
  [self insertMessageForFormQuestion:question withLastMessage:lastMessage];
}


#pragma mark - Form submission
-(NSMutableDictionary*)getFormMessage:(KUSFormQuestion*)kusFormQuestion questionMessage:(KUSChatMessage*)questionMessage responseMessage:(KUSChatMessage*)responseMessage
{
  NSMutableDictionary<NSString *, NSObject *> *formMessage = [[NSMutableDictionary alloc] init];
  [formMessage setObject:kusFormQuestion.oid forKey:@"id"];
  [formMessage setObject:kusFormQuestion.prompt forKey:@"prompt"];
  [formMessage setObject:[KUSDate stringFromDate:questionMessage.createdAt] forKey:@"promptAt"];
  
  if(responseMessage != nil){
    [formMessage setObject:responseMessage.body forKey:@"input"];
    [formMessage setObject:[KUSDate stringFromDate:responseMessage.createdAt] forKey:@"inputAt"];
    if(responseMessage.value != nil){
      [formMessage setObject:responseMessage.value forKey:@"value"];
    }
  }
  
  // old way
  // if ([KUSFormQuestion KUSFormQuestionRequiresResponse: question]) {
  //   KUSChatMessage *responseMessage = [self objectAtIndex:currentMessageIndex];
  //  //BEWARE: currentMessageIndex--;
  //
  //   [formMessage setObject:responseMessage.body forKey:@"input"];
  //   [formMessage setObject:[KUSDate stringFromDate:responseMessage.createdAt] forKey:@"inputAt"];
  //   if (responseMessage.value) {
  //     [formMessage setObject:responseMessage.value forKey:@"value"];
  //   }
  // }
  
  return formMessage;
}

- (void)_submitFormResponses
{
    NSMutableArray<NSDictionary<NSString *, NSObject *> *> *messagesJSON = [[NSMutableArray alloc] init];
    
    NSMutableDictionary* lastDeflectionJSON = [@{
      @"query": [[NSMutableDictionary alloc] init],
      @"articles": [[NSMutableArray alloc] init],
      @"type": @"kb-search"
    } mutableCopy];
  // [@{
  //     @"type": @"kb-search",
  //     @"status": deflectQuestion.deflectStatus,
      // @"query": [[NSMutableDictionary alloc] init],
      // @"articles": [[NSMutableArray alloc] init]
  //   } mutableCopy];
  //   [lastDeflectionJSON setValue:deflectQuestion.deflectSearchedFor forKeyPath:@"query.rawText"];
  //   params[@"lastDeflection"] = dvi;
  //
    NSInteger currentMessageIndex = self.count - 1;
  
    if(!_form.proactive) {
      KUSChatMessage *firstUserMessage = [self objectAtIndex:currentMessageIndex];
      currentMessageIndex--;
      
      [messagesJSON addObject:@{
        @"input": firstUserMessage.body,
        @"inputAt": [KUSDate stringFromDate:firstUserMessage.createdAt]
      }];
    }
    
    for (KUSFormQuestion *question in _form.questions) {
      if(currentMessageIndex < 0) {
        continue;
      }
        
      if(question.type == KUSFormQuestionTypeKBDeflectQuestion){
        KUSChatMessage* questionMessage = [self objectAtIndex:currentMessageIndex];
        currentMessageIndex--;
        KUSChatMessage* queryMessage = [self objectAtIndex:currentMessageIndex];
        currentMessageIndex--;
        
        [lastDeflectionJSON setValue:queryMessage.body forKeyPath:@"query.rawText"];
        
        NSMutableDictionary* formMessage = [self getFormMessage:question
                                                questionMessage:questionMessage
                                                responseMessage:queryMessage];
        [messagesJSON addObject:formMessage];
      }else if(question.type == KUSFormQuestionTypeKBDeflectResponse || question.type == KUSFormQuestionTypeKBDeflectedSuccessfully) {
      // }else if(question.type == KUSFormQuestionTypeKBDeflectResponse || question.type == KUSFormQuestionTypeKBDeflectedSuccessfully) {
        NSMutableArray* articlesJSON = [@[] mutableCopy];
        currentMessageIndex--;
        KUSChatMessage* articleMessage = [self objectAtIndex:currentMessageIndex];
        currentMessageIndex--;
        while(articleMessage != nil) {
          if([articleMessage.kbArticle count] != 0){
            NSMutableDictionary* articleDetails = [articleMessage.kbArticle copy];
            NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
            formatter.numberStyle = NSNumberFormatterNoStyle;
            NSNumber *visitedNsn = [formatter numberFromString: (NSString*)[articleDetails valueForKey:@"viewCount"]];
            
            NSMutableDictionary* articleJsonObject = [[NSMutableDictionary alloc] init];
            [articleJsonObject setValue:[articleDetails valueForKey:@"id"] forKey:@"version"];
            [articleJsonObject setValue:visitedNsn forKey:@"visited"];
            
            [articlesJSON addObject:articleJsonObject];
          }
          if(currentMessageIndex < 0 || currentMessageIndex >= [self count]){
            articleMessage = nil;
          }else{
            articleMessage = [self objectAtIndex:currentMessageIndex];
            if([articleMessage.kbArticle count] == 0){
              articleMessage = nil;
            }
          }
          
          currentMessageIndex--;
        }
        
        [lastDeflectionJSON setValue:articlesJSON forKeyPath:@"articles"];
        // KUSChatMessage* userKBDeflectResponse = [self objectAtIndex:currentMessageIndex];
        currentMessageIndex--;
        
        [lastDeflectionJSON setValue:[KUSDate stringFromDate:[[self latestMessage] createdAt]] forKeyPath:@"deflectedAt"];
        
        if(question.type == KUSFormQuestionTypeKBDeflectedSuccessfully) {
          [lastDeflectionJSON setValue:@"accepted" forKeyPath:@"status"];
        } else {
          [lastDeflectionJSON setValue:@"rejected" forKeyPath:@"status"];
        }
        
      }else if(question.type == KUSFormQuestionTypeKBDeflectNoResponseFound){
        currentMessageIndex--;
        [lastDeflectionJSON setValue:@"status" forKeyPath:@"no-match"];
      }else{
        //default case
        KUSChatMessage* questionMessage = [self objectAtIndex:currentMessageIndex];
        currentMessageIndex--;
        KUSChatMessage* responseMessage = nil;
        
        if ([KUSFormQuestion KUSFormQuestionRequiresResponse: question]) {
          if(currentMessageIndex >= 0){
            responseMessage = [self objectAtIndex:currentMessageIndex];
            currentMessageIndex--;
          }
        }
        
        NSMutableDictionary* formMessage = [self getFormMessage:question
                                                questionMessage:questionMessage
                                                responseMessage:responseMessage];
        [messagesJSON addObject:formMessage];
      }
    }
    //A1
    
    _submittingForm = YES;
    KUSChatMessage *lastUserChatMessage = nil;
    for (KUSChatMessage *chatMessage in self.allObjects) {
        if (KUSChatMessageSentByUser(chatMessage)) {
            lastUserChatMessage = chatMessage;
            break;
        }
    }
    
    // Logic to handle an error
    void(^handleError)(void) = ^void() {
        if (lastUserChatMessage) {
            [self removeObjects:@[ lastUserChatMessage ]];
            lastUserChatMessage.state = KUSChatMessageStateFailed;
            [self upsertObjects:@[ lastUserChatMessage ]];
        }
    };
    
    void (^actuallySubmitForm)(void) = ^void() {
        NSMutableDictionary<NSString *, id> *params = [[NSMutableDictionary alloc] init];
        params[@"messages"] = messagesJSON;
        
        if([[lastDeflectionJSON valueForKey:@"status"] isEqualToString:@"rejected"] || [[lastDeflectionJSON valueForKey:@"status"] isEqualToString:@"accepted"] || [[lastDeflectionJSON valueForKey:@"status"] isEqualToString:@"no-match"]){
          params[@"lastDeflection"] = lastDeflectionJSON;
        }
        
        [self.userSession.chatSessionsDataSource
         submitFormWithParams:params
         formId:_form.oid
         completion:^(NSError *error, KUSChatSession *session, NSArray<KUSChatMessage *> *messages) {
             if (error) {
                 handleError();
                 return;
             }
             
             // If the form contained an email prompt, mark the local session as having submitted email
             if ([_form containsEmailQuestion]) {
                 [self.userSession.userDefaults setDidCaptureEmail:YES];
             }
             
             // Set variable for business hours
             if (![self.userSession.scheduleDataSource isActiveBusinessHours] && _form.questions.count > 0) {
                 _nonBusinessHours = YES;
             }
             
             if (![self isActualSessionExist] && _sessionId != NULL) {
                 KUSChatSession *tempSession = [self.userSession.chatSessionsDataSource objectWithId:_sessionId];
                 if(tempSession != NULL){
                     [self.userSession.chatMessagesDataSources removeObjectForKey:_sessionId];
                     [self.userSession.chatSessionsDataSource removeObjects: @[tempSession]];
                 }
             }
             // Grab the session id
             _sessionId = session.oid;
             _form = nil;
             _questionIndex = -1;
             _formQuestion = nil;
             _submittingForm = NO;
             
             // Replace all of the local messages with the new ones
             [self removeObjects:self.allObjects];
             [self upsertNewMessages:messages];
             if (lastUserChatMessage) {
                 [_messageRetryBlocksById removeObjectForKey:lastUserChatMessage.oid];
             }
             // Create queue polling manager for volume control form
             sessionQueuePollingManager = [[KUSSessionQueuePollingManager alloc] initWithUserSession:self.userSession sessionId:_sessionId];
             
             // Insert the current messages data source into the userSession's lookup table
             [self.userSession.chatMessagesDataSources setObject:self forKey:_sessionId];
             
             // Notify listeners
             for (id<KUSChatMessagesDataSourceListener> listener in [self.listeners copy]) {
                 if ([listener respondsToSelector:@selector(chatMessagesDataSource:didCreateSessionId:)]) {
                     [listener chatMessagesDataSource:self didCreateSessionId:_sessionId];
                 }
             }
             
             // Update last seen locally for the session
             [self.userSession.chatSessionsDataSource updateLocallyLastSeenAtForSessionId:_sessionId];
          
            // to auto close the convo. see implementation.
            _afterActuallySubmitFormMessages(@"token");
         }];
    };
    
    void (^retrySubmittingForm)(void) = ^void() {
        if (lastUserChatMessage) {
            [self removeObjects:@[ lastUserChatMessage ]];
            lastUserChatMessage.state = KUSChatMessageStateSending;
            [self upsertObjects:@[ lastUserChatMessage ]];
        }
        actuallySubmitForm();
    };
    
    if (lastUserChatMessage) {
        _messageRetryBlocksById[lastUserChatMessage.oid] = retrySubmittingForm;
    }
    actuallySubmitForm();
}

- (void)_insertDelayedMessage:(KUSChatMessage *)chatMessage
{
    // Sanity check
    if (chatMessage.oid.length == 0) {
        return;
    }
    
    // Only insert the message if it doesn't exist already
    if ([self objectWithId:chatMessage.oid]) {
        return;
    }
    
    // Get the desired delay
    NSTimeInterval delay = [chatMessage.createdAt timeIntervalSinceNow];
    
    // Immediately add it if desired
    if (delay <= 0.0) {
        [self upsertObjects:@[ chatMessage ]];
        return;
    }
    
    [_delayedChatMessageIds addObject:chatMessage.oid];
    
    __weak KUSChatMessagesDataSource *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong KUSChatMessagesDataSource *strongSelf = weakSelf;
        if (strongSelf == nil) {
            return;
        }
        
        [strongSelf->_delayedChatMessageIds removeObject:chatMessage.oid];
        BOOL doesNotAlreadyContainMessage = ![strongSelf objectWithId:chatMessage.oid];
        [strongSelf upsertObjects:@[ chatMessage ]];
        if (doesNotAlreadyContainMessage) {
            [KUSAudio playMessageReceivedSound];
        }
    });
}

#pragma mark - Volume Control Form Messaging

- (BOOL)_shouldPreventVCFormQuestionMessage
{
    if (![self isActualSessionExist]) {
        return YES;
    }
    
    // If we haven't loaded the chat settings data source, prevent input
    if (!self.userSession.chatSettingsDataSource.didFetch) {
        return YES;
    }
    
    KUSChatSettings *chatSettings = self.userSession.chatSettingsDataSource.object;
    if (!chatSettings.volumeControlEnabled) {
        return YES;
    }
    
    if (!_vcTrackingDelayCompleted) {
        return YES;
    }
    
    // If we are about to insert an artificial message, prevent input
    if (_delayedChatMessageIds.count > 0) {
        return YES;
    }
    
    // When submitting the form, prevent sending more responses
    if (_submittingForm) {
        return YES;
    }
    
    if (_vcFormEnd) {
        return YES;
    }
    
    // Check that last message is VC form last message
    KUSChatMessage *lastMessage = [self latestMessage];
    if ([lastMessage.oid isEqualToString:@"vc_question_2"]) {
        return NO;
    }
    
    // Check that response of previous asked question is already entered ? if not return
    if (_vcFormActive && !KUSChatMessageSentByUser(lastMessage) && [[self otherUserIds] count] == 0) {
        return YES;
    }
    
    return NO;
}

- (void)_insertVolumeControlFormMessageIfNecessary
{
    // If any pre-condition not fulfilled
    if ([self _shouldPreventVCFormQuestionMessage]) {
        return;
    }
    
    // If any message sent by Server apart from auto response or form message.
    if ([[self otherUserIds] count] > 0) {
        [self _endVolumeControlTracking];
        
        // Update Listeners that chat ended
        [self notifyAnnouncersDidChangeContent];
        return;
    }

    KUSChatSession *session = [self.userSession.chatSessionsDataSource objectWithId:_sessionId];
    if (session.lockedAt) {
        [self _endVolumeControlTracking];
        
        // Update Listeners that chat ended
        [self notifyAnnouncersDidChangeContent];
        return;
    }
    
    KUSChatMessage *lastMessage = [self latestMessage];
    NSString *previousMessage = lastMessage.body;
    if (_vcformQuestionIndex == 1 && [previousMessage isEqualToString:@"I'll wait"]) {
        [self _endVolumeControlTracking];
        
        // Update Listeners that chat ended
        [self notifyAnnouncersDidChangeContent];
        return;
    }
    
    // If last question, send request on backend
    if (_vcformQuestionIndex == 3) {
        
        // Submit VCForm response if chatEnding request is not in process
        if (!_isChatEnding) {
            [self _endVolumeControlTracking];
            [self _submitVCFormResponses];
        }
        return;
    }
    
    // Ask next question
    NSDate *createdAt = [lastMessage.createdAt dateByAddingTimeInterval:KUSChatAutoreplyDelay];
    if (!_vcFormActive) {
        createdAt = [[NSDate date] dateByAddingTimeInterval:KUSChatAutoreplyDelay];
    }
    
    _vcFormActive = YES;
    
    NSString *previousChannel = [lastMessage.body lowercaseString];
    KUSFormQuestion *vcFormQuestion = [self _getNextVCFormQuestion:_vcformQuestionIndex previousMessage:previousChannel];
    if(vcFormQuestion) {
        NSDictionary *json = @{
           @"type": @"chat_message",
           @"id": vcFormQuestion.oid,
           @"attributes": @{
               @"body": vcFormQuestion.prompt,
               @"direction": @"out",
               @"createdAt": [KUSDate stringFromDate:createdAt]
            }
        };
        KUSChatMessage *formMessage = [[KUSChatMessage alloc] initWithJSON:json];
        [self _insertDelayedMessage:formMessage];
        
        _formQuestion = vcFormQuestion;
        // If first options response input, update view by remove options component
        if (_vcformQuestionIndex == 1) {
            [self notifyAnnouncersDidChangeContent];
        }
        _vcformQuestionIndex++;
    }else{
        return;
    }
    
}

- (void)_submitVCFormResponses
{
    if (self.count <= 5) {
        return;
    }
    
    if ([[self otherUserIds] count] > 0) {
        return;
    }
    
    NSMutableArray<NSDictionary<NSString *, NSObject *> *> *messagesJSON = [[NSMutableArray alloc] init];
    
    NSUInteger currentMessageIndex = 4;
    NSString *property = nil;
    for (int i = 0; i < 3; i++) {
        NSMutableDictionary<NSString *, NSObject *> *formMessage = [[NSMutableDictionary alloc] init];
        
        KUSChatMessage *questionMessage = [self objectAtIndex:currentMessageIndex];
        currentMessageIndex--;
        [formMessage setObject:questionMessage.body forKey:@"prompt"];
        [formMessage setObject:[KUSDate stringFromDate:questionMessage.createdAt] forKey:@"promptAt"];
        
        if (i != 2) {
            KUSChatMessage *responseMessage = [self objectAtIndex:currentMessageIndex];
            currentMessageIndex--;
            [formMessage setObject:responseMessage.body forKey:@"input"];
            [formMessage setObject:[KUSDate stringFromDate:responseMessage.createdAt] forKey:@"inputAt"];
            
            if (i == 0) {
                property = responseMessage.body;
            }
        }
        
        if (i == 0) {
            [formMessage setObject:@"conversation_replyChannel" forKey:@"property"];
        } else if (i == 1) {
            if ([[property lowercaseString] isEqualToString:@"email"]) {
                [formMessage setObject:@"customer_email" forKey:@"property"];
            } else if([[property lowercaseString] isEqualToString:@"voice"] || [[property lowercaseString] isEqualToString:@"sms"]){
                [formMessage setObject:@"customer_phone" forKey:@"property"];
            }
        }
        
        [messagesJSON addObject:formMessage];
    }
    
    _submittingForm = YES;

    void (^actuallySubmitVCForm)(void) = ^void() {
        [self.userSession.requestManager
         performRequestType:KUSRequestTypePost
         endpoint:@"/c/v1/chat/volume-control/responses"
         params:@{ @"messages": messagesJSON , @"session": _sessionId }
         authenticated:YES
         completion:^(NSError *error, NSDictionary *response) {
             if (error) {
                 return;
             }
             
             NSMutableArray<KUSChatMessage *> *chatMessages = [[NSMutableArray alloc] init];
             
             NSArray<NSDictionary *> *includedModelsJSON = response[@"included"];
             for (NSDictionary *includedModelJSON in includedModelsJSON) {
                 NSString *type = includedModelJSON[@"type"];
                 if ([type isEqual:[KUSChatMessage modelType]]) {
                     KUSChatMessage *chatMessage = [[KUSChatMessage alloc] initWithJSON:includedModelJSON];
                     [chatMessages addObject:chatMessage];
                 }
             }

             NSMutableArray<KUSChatMessage *> *temporaryMessages = [[NSMutableArray alloc] init];
             for (KUSChatMessage *chatMessage in self.allObjects) {
                 if ([chatMessage.oid containsString:@"vc_question_"]) {
                     [temporaryMessages addObject:chatMessage];
                 }
             }
             
             _submittingForm = NO;
             _vcChatClosed = YES;
             
             [self removeObjects:temporaryMessages];
             [self removeObjects:_temporaryVCMessagesResponses];
             [self upsertNewMessages:chatMessages];
             
             
             // Cancel Volume Control Polling if necessary
             [sessionQueuePollingManager cancelPolling];
         }];
    };
    
    actuallySubmitVCForm();
}

- (void)_startVolumeControlTracking
{
    if (![self isActualSessionExist]) {
        return;
    }
    
    KUSChatSettings *chatSettings = self.userSession.chatSettingsDataSource.object;
    if (!chatSettings.volumeControlEnabled) {
        return;
    }
    
    // Check if business hours enabled and not in business hours
    if (![self.userSession.scheduleDataSource isActiveBusinessHours]) {
        return;
    }
    
    if (_vcTrackingStarted) {
        return;
    }
    _vcTrackingStarted = YES;
    
    if (chatSettings.volumeControlMode == KUSVolumeControlModeDelayed) {
        NSTimeInterval delay = chatSettings.promptDelay ?: 0.0f;
        [self _startVolumeControlFormTrackingAfterDelay:delay];
        
        // Automatically end chat
        if (chatSettings.markDoneAfterTimeout) {
            delay = (chatSettings.timeOut ?: 0.0f) + (chatSettings.promptDelay ?: 0.0f);
            [self _endVolumeControlFormAfterDelayIfNecessary:delay];
        }
    }
    else if (chatSettings.volumeControlMode == KUSVolumeControlModeUpfront) {
        [sessionQueuePollingManager addListener:self];
        [sessionQueuePollingManager startPolling];
    }
}

- (void)_endVolumeControlTracking
{
    _vcFormEnd = YES;
    _vcFormActive = NO;
    [[KUSVolumeControlTimerManager sharedInstance] invalidateVCTimerForSession:_sessionId];
}
        
- (KUSFormQuestion *)_getNextVCFormQuestion:(NSInteger)index previousMessage:(NSString *)previousMessage
{
    if (index == 0) {
        KUSChatSettings *chatSettings = self.userSession.chatSettingsDataSource.object;
        NSMutableArray<NSString *> *options = [[NSMutableArray alloc] init];
        for (NSString *option in chatSettings.followUpChannels) {
            [options addObject:[NSString stringWithFormat:@"%@%@",[[option substringToIndex:1] uppercaseString], [[option substringFromIndex:1] lowercaseString]]];
        }
        
        if (!chatSettings.hideWaitOption) {
            [options addObject:@"I'll wait"];
        }
        
        //volume_control_alternative_method_question
        NSString *prompt = [[KUSLocalization sharedInstance] localizedString:@"volume_control_alternative_method_question"];
        KUSSessionQueue *sessionQueue = [sessionQueuePollingManager sessionQueue];
        
        if (chatSettings.volumeControlMode == KUSVolumeControlModeUpfront &&
            sessionQueue.estimatedWaitTimeSeconds != 0) {
            
            NSString *currentWaitTimeMessage = [KUSDate volumeControlCurrentWaitTimeMessageForSeconds:sessionQueue.estimatedWaitTimeSeconds];
            NSString *upfrontAlternatePrompt = [[KUSLocalization sharedInstance] localizedString:@"upfront_volume_control_alternative_method_question"];
            prompt = [[NSString alloc] initWithFormat:@"%@. %@", currentWaitTimeMessage, upfrontAlternatePrompt];
        }
        
        KUSFormQuestion *question = [[KUSFormQuestion alloc]
                                     initWithJSON:@{
                                        @"id" : @"vc_question_0",
                                        @"name" : @"Volume Form 0",
                                        @"prompt" : prompt,
                                        @"property" : @"followup_channel",
                                        @"values" : options,
                                    }];
        return question;
    }
    else if (index == 1) {
        NSString *propery = nil;
        NSString *prompt = nil;
        NSString *channel = previousMessage;
        
        if ([[previousMessage lowercaseString] isEqualToString:@"email"]) {
            propery = @"customer_email";
            channel = @"email";
            prompt = [[KUSLocalization sharedInstance] localizedString:@"volume_control_email_question"];
        } else if ([[previousMessage lowercaseString] isEqualToString:@"voice"] || [[previousMessage lowercaseString] isEqualToString:@"sms"]){
            propery = @"customer_phone";
            channel = @"phone number";
            prompt = [[KUSLocalization sharedInstance] localizedString:@"volume_control_phone_question"];
        } else { //If previous message is none from email,voice or sms - choose i'll wait option
            [self _endVolumeControlTracking];
            
            // Update Listeners that chat ended
            [self notifyAnnouncersDidChangeContent];
            return nil;
        }

        KUSFormQuestion *question = [[KUSFormQuestion alloc]
                                     initWithJSON:@{
                                        @"id" : @"vc_question_1",
                                        @"name" : @"Volume Form 1",
                                        @"prompt" : prompt,
                                        @"type" : @"response",
                                        @"property" : propery
                                    }];
        return question;
    }
    else if (index == 2) {
        NSString *message = [[KUSLocalization sharedInstance] localizedString:@"volume_control_thankyou_response"];
        KUSFormQuestion *question = [[KUSFormQuestion alloc]
                                     initWithJSON:@{
                                        @"id" : @"vc_question_2",
                                        @"name" : @"Volume Form 2",
                                        @"prompt" : message,
                                        @"type" : @"message"
                                    }];
        return question;
    }
    
    return nil;
}
@end
