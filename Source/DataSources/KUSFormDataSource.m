//
//  KUSFormDataSource.m
//  Kustomer
//
//  Created by Daniel Amitay on 12/20/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSFormDataSource.h"
#import "KUSObjectDataSource_Private.h"

@interface KUSFormDataSource () <KUSObjectDataSourceListener> {
    NSString *_Nullable _formId;
}
@end

@implementation KUSFormDataSource

#pragma mark - Lifecycle methods

- (instancetype)initWithUserSession:(KUSUserSession *)userSession
{
    self = [super initWithUserSession:userSession];
    if (self) {
        [self.userSession.chatSettingsDataSource addListener:self];
    }
    return self;
}

- (instancetype)initWithUserSession:(KUSUserSession *)userSession formId:(NSString *)formId
{
    self = [self initWithUserSession:userSession];
    if (self) {
        _formId = formId;
    }
    return self;
}

#pragma mark - Public methods

- (NSString *)getConversationalFormId
{
    NSString* formId = _formId;
    if (formId == nil) {
        formId = [self.userSession.userDefaults formId];
    }
    if (formId == nil) {
        KUSChatSettings *chatSettings = self.userSession.chatSettingsDataSource.object;
        formId = chatSettings.activeFormId;
    }
    return formId;
}

#pragma mark - KUSObjectDataSource subclass methods

- (void)performRequestWithCompletion:(KUSRequestCompletion)completion
{
    NSString *formId = [self getConversationalFormId];
    [self.userSession.requestManager getEndpoint:[NSString stringWithFormat:@"/c/v1/chat/forms/%@", formId]
                                   authenticated:YES
                                      completion:completion];
}

- (Class)modelClass
{
    return [KUSForm class];
}

#pragma mark - KUSObjectDataSource overrides

- (void)fetch
{
    NSString *formId = [self getConversationalFormId];
    if (!formId && !self.userSession.chatSettingsDataSource.didFetch) {
        [self.userSession.chatSettingsDataSource fetch];
        return;
    }
    
    if (formId) {
        [super fetch];
    }
}

- (BOOL)isFetching
{
    if ([self.userSession.chatSettingsDataSource isFetching]) {
        return [self.userSession.chatSettingsDataSource isFetching];
    }
    return [super isFetching];
}

- (BOOL)didFetch
{
    KUSChatSettings *chatSettings = self.userSession.chatSettingsDataSource.object;
    if (chatSettings && chatSettings.activeFormId == nil) {
        return YES;
    }
    return [super didFetch];
}

- (NSError *)error
{
    return self.userSession.chatSettingsDataSource.error ?: [super error];
}

#pragma mark - KUSObjectDataSourceListener methods

- (void)objectDataSourceDidLoad:(KUSObjectDataSource *)dataSource
{
    [self fetch];
}

- (void)objectDataSource:(KUSObjectDataSource *)dataSource didReceiveError:(NSError *)error
{
    if (!dataSource.didFetch) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [dataSource fetch];
        });
    }
}


@end
