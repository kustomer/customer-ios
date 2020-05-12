//
//  KUSChatSettings.h
//  Kustomer
//
//  Created by Daniel Amitay on 7/4/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSModel.h"

typedef NS_ENUM(NSInteger, KUSBusinessHoursAvailability) {
    KUSBusinessHoursAvailabilityOnline,
    KUSBusinessHoursAvailabilityOffline,
    KUSBusinessHoursAvailabilityHideChat,
};

typedef NS_ENUM(NSInteger, KUSVolumeControlMode) {
    KUSVolumeControlModeUnknown,
    KUSVolumeControlModeDelayed,
    KUSVolumeControlModeUpfront
};

@class KUSChatMessage;
@interface KUSChatSettings : KUSModel

@property (nonatomic, copy, readonly) NSString *teamName;
@property (nonatomic, copy, readonly) NSURL *teamIconURL;
@property (nonatomic, copy, readonly) NSString *greeting;
@property (nonatomic, copy, readonly) NSString *activeFormId;
@property (nonatomic, assign, readonly) BOOL campaignsEnabled;
@property (nonatomic, copy, readonly) NSString *pusherAccessKey;
@property (nonatomic, copy, readonly) NSString *pusherCluster;
@property (nonatomic, assign, readonly) BOOL enabled;

@property (nonatomic, assign, readonly) KUSBusinessHoursAvailability availability;
@property (nonatomic, copy, readonly) NSString *offhoursImageUrl;
@property (nonatomic, copy, readonly) NSString *offhoursMessage;

@property (nonatomic, copy, readonly) NSString *waitMessage;
@property (nonatomic, copy, readonly) NSString *customWaitMessage;
@property (nonatomic, assign, readonly) NSInteger timeOut;
@property (nonatomic, assign, readonly) NSInteger promptDelay;
@property (nonatomic, assign, readonly) BOOL hideWaitOption;
@property (nonatomic, copy, readonly) NSArray<NSString *> *followUpChannels;
@property (nonatomic, assign, readonly) BOOL useDynamicWaitMessage;
@property (nonatomic, assign, readonly) BOOL markDoneAfterTimeout;
@property (nonatomic, assign, readonly) BOOL volumeControlEnabled;
@property (nonatomic, assign, readonly) BOOL closableChat;
@property (nonatomic, assign, readonly) BOOL singleSessionChat;
@property (nonatomic, assign, readonly) BOOL noHistory;
@property (nonatomic, assign, readonly) KUSVolumeControlMode volumeControlMode;
@property (nonatomic, assign, readonly) NSInteger upfrontWaitThreshold;
@property (nonatomic, assign, readonly) BOOL brandingKustomer;

@property (nonatomic, assign, readonly) BOOL shouldShowTypingIndicatorCustomerWeb;
@property (nonatomic, assign, readonly) BOOL shouldShowTypingIndicatorWeb;

@property (nonatomic, assign, readonly) BOOL outboundMessagesOverride;
@property (nonatomic, assign, readonly) BOOL inboundMessagesOverride;


@end
