//
//  KUSBusinessHoursDataSource.m
//  Kustomer
//
//  Created by Hunain Shahid on 15/10/2018.
//  Copyright © 2018 Kustomer. All rights reserved.
//

#import "KUSScheduleDataSource.h"
#import "KUSObjectDataSource_Private.h"

@interface KUSScheduleDataSource() {
    NSString *_lastFetchedScheduleId;
    BOOL _isScheduleNotFound;
    BOOL _isFetched;
}

@end

@implementation KUSScheduleDataSource

#pragma mark - Lifecycle methods

- (instancetype)initWithUserSession:(KUSUserSession *)userSession
{
    self = [super initWithUserSession:userSession];
    if (self) {
    }
    return self;
}

#pragma mark - KUSObjectDataSource subclass methods

- (void)performRequestWithCompletion:(KUSRequestCompletion)completion
{
    NSString *scheduleIdToFetch = [self scheduleIdToFetch];
    NSString *endpoint = [NSString stringWithFormat:@"/c/v1/schedules/%@?include=holidays", scheduleIdToFetch];
    [self.userSession.requestManager getEndpoint:endpoint
                                   authenticated:YES
                                      completion:^(NSError *error, NSDictionary *response) {
                                          
                                          BOOL isSuccessfullyFetched = error == nil;
                                          NSNumber *statusCode = error.userInfo[@"status"];
                                          
                                          _isScheduleNotFound = statusCode != nil && [statusCode integerValue] == 404;
                                          _isFetched = isSuccessfullyFetched || _isScheduleNotFound;
                                          
                                          if (isSuccessfullyFetched) {
                                              _lastFetchedScheduleId = scheduleIdToFetch;
                                          }
                                          _scheduleId = nil;
                                          completion(error, response);
    }];
    
}

- (void)fetch
{
    BOOL isNewSchedule = ![_lastFetchedScheduleId isEqualToString:[self scheduleIdToFetch]];
    BOOL shouldFetch = !self.didFetch || isNewSchedule || _isScheduleNotFound;
    if (shouldFetch) {
        _isFetched = NO;
        [super fetch];
    } else {
        _scheduleId = nil;
    }
}

- (BOOL)didFetch
{
    return _isFetched;
}


- (Class)modelClass
{
    return [KUSSchedule class];
}

#pragma mark - Internal Methods

- (NSString *)scheduleIdToFetch
{
    return _scheduleId != nil ? _scheduleId : @"default";
}

#pragma mark - Public Methods

- (BOOL)isActiveBusinessHours
{
    KUSChatSettings *chatSettings = self.userSession.chatSettingsDataSource.object;
    if (chatSettings.availability == KUSBusinessHoursAvailabilityOnline) {
        return YES;
    }
    
    if (_isScheduleNotFound) {
        return YES;
    }
    
    KUSSchedule *businessHours = [self object];

    // Check that current date is not in holiday date and time
    NSDate *now = [NSDate date];
    for (KUSHoliday *holiday in businessHours.holidays) {
        if (holiday.enabled) {
            BOOL greaterThanStartDate = [[holiday.startDate earlierDate:now] isEqualToDate:holiday.startDate];
            BOOL lessThanEndDate = [[now earlierDate:holiday.endDate] isEqualToDate:now];
            BOOL isHoliday = greaterThanStartDate && lessThanEndDate;
            if (isHoliday) {
                return NO;
            }
        }
    }
    
    // Get Week Day
    NSCalendar* cal = [NSCalendar currentCalendar];
    NSDateComponents *components = [cal components:(NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitWeekday) fromDate:now];
    NSInteger weekday = [components weekday] - 1; // -1 is to make Sunday '0'
    NSInteger minutes = [components hour] * 60 + [components minute];
    
    NSArray<NSArray<NSNumber *> *> *businessHoursOfCurrentDay = businessHours.hours[[NSString stringWithFormat:@"%ld", (long)weekday]];
    if (businessHoursOfCurrentDay != nil && businessHoursOfCurrentDay != (id)[NSNull null]) {
        for (int i = 0; i < [businessHoursOfCurrentDay count]; i++) {
            NSArray<NSNumber *> *businessHoursRange = [businessHoursOfCurrentDay objectAtIndex:i];
            if (businessHoursRange && businessHoursRange.count == 2 &&
                [businessHoursRange[0] integerValue] <= minutes && [businessHoursRange[1]  integerValue] >= minutes) {
                return YES;
            }
        }
    }
    return NO;
}


@end
