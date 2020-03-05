//
//  KUSChatSettings.m
//  Kustomer
//
//  Created by Daniel Amitay on 7/4/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSChatSettings.h"

#import "KUSChatMessage.h"

@implementation KUSChatSettings

#pragma mark - Class methods

+ (NSString *)modelType
{
    return @"chat_settings";
}

#pragma mark - Lifecycle methods

- (instancetype)initWithJSON:(NSDictionary *)json
{
    self = [super initWithJSON:json];
    if (self) {
        _teamName = NSStringFromKeyPath(json, @"attributes.teamName");
        _teamIconURL = NSURLFromKeyPath(json, @"attributes.teamIconUrl");
        _greeting = NSStringFromKeyPath(json, @"attributes.greeting");
        _activeFormId = NSStringFromKeyPath(json, @"attributes.activeForm");
        _pusherAccessKey = NSStringFromKeyPath(json, @"attributes.pusherAccessKey");
        _pusherCluster = NSStringFromKeyPath(json, @"attributes.pusherCluster");
        _enabled = BOOLFromKeyPath(json, @"attributes.enabled");
        _closableChat = BOOLFromKeyPath(json, @"attributes.closableChat");
        _waitMessage = NSStringFromKeyPath(json, @"attributes.waitMessage");
        _singleSessionChat = BOOLFromKeyPath(json, @"attributes.singleSessionChat");
        _noHistory = BOOLFromKeyPath(json, @"attributes.noHistory");
        _campaignsEnabled = BOOLFromKeyPath(json, @"attributes.campaignsEnabled");
        
        _customWaitMessage = NSStringFromKeyPath(json, @"attributes.volumeControl.customWaitMessage");
        _timeOut = IntegerFromKeyPath(json, @"attributes.volumeControl.timeout");
        _promptDelay = IntegerFromKeyPath(json, @"attributes.volumeControl.promptDelay");
        _hideWaitOption = BOOLFromKeyPath(json, @"attributes.volumeControl.hideWaitOption");
        _followUpChannels = NSArrayFromKeyPath(json, @"attributes.volumeControl.followUpChannels");
        _useDynamicWaitMessage = BOOLFromKeyPath(json, @"attributes.volumeControl.useDynamicWaitMessage");
        _markDoneAfterTimeout = BOOLFromKeyPath(json, @"attributes.volumeControl.markDoneAfterTimeout");
        _volumeControlEnabled = BOOLFromKeyPath(json, @"attributes.volumeControl.enabled");
        _volumeControlMode = KUSVolumeControlModeFromString(NSStringFromKeyPath(json, @"attributes.volumeControl.mode"));
        _upfrontWaitThreshold = IntegerFromKeyPath(json, @"attributes.volumeControl.upfrontWaitThreshold");
        
        _offhoursMessage = NSStringFromKeyPath(json, @"attributes.offhoursMessage");
        _offhoursImageUrl = NSStringFromKeyPath(json, @"attributes.offhoursImageUrl");
        _availability = KUSBusinessHoursAvailabilityFromString(NSStringFromKeyPath(json, @"attributes.offhoursDisplay"));
        _brandingKustomer = BOOLFromKeyPath(json, @"attributes.showBrandingIdentifier");
        
        _shouldShowTypingIndicatorCustomerWeb = BOOLFromKeyPath(json, @"attributes.showTypingIndicatorCustomerWeb");
        _shouldShowTypingIndicatorWeb = BOOLFromKeyPath(json, @"attributes.showTypingIndicatorWeb");
    }
    return self;
}

#pragma mark - Convenience methods

KUSBusinessHoursAvailability KUSBusinessHoursAvailabilityFromString(NSString *string)
{
    if ([string isEqualToString:@"online"]) {
        return KUSBusinessHoursAvailabilityOnline;
    } else if ([string isEqualToString:@"offline"]) {
        return KUSBusinessHoursAvailabilityOffline;
    }
    return KUSBusinessHoursAvailabilityHideChat;
}

KUSVolumeControlMode KUSVolumeControlModeFromString(NSString *string)
{
    if ([string isEqualToString:@"upfront"]) {
        return KUSVolumeControlModeUpfront;
    } else if ([string isEqualToString:@"delayed"]) {
        return KUSVolumeControlModeDelayed;
    }
    return KUSVolumeControlModeUnknown;
}

@end
