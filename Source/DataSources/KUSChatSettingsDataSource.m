//
//  KUSChatSettingsDataSource.m
//  Kustomer
//
//  Created by Daniel Amitay on 7/31/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSChatSettingsDataSource.h"

#import "KUSObjectDataSource_Private.h"

@implementation KUSChatSettingsDataSource

#pragma mark - KUSObjectDataSource subclass methods

- (void)performRequestWithCompletion:(KUSRequestCompletion)completion
{
    NSString* lang = [[KUSLocalization sharedInstance] currentLanguage];
    [self.userSession.requestManager performRequestType:KUSRequestTypeGet
                                               endpoint:@"/p/v1/chat/settings"
                                                 params:@{ @"lang": lang }
                                          authenticated:NO
                                             completion:completion];
}

- (Class)modelClass
{
    return [KUSChatSettings class];
}

- (void)isChatAvailable:(void (^)(BOOL success, BOOL enabled))block
{
    [self performRequestWithCompletion:^(NSError *error, NSDictionary *response) {
        KUSChatSettings *settingsModel = [[KUSChatSettings alloc] initWithJSON:response[@"data"]];
        if (error || settingsModel == nil) {
            block(NO, NO);
        } else {
            block(YES, settingsModel.enabled);
        }
    }];
}

@end
