//
//  KUSClientActivityManager.m
//  Kustomer
//
//  Created by Daniel Amitay on 2/11/18.
//  Copyright © 2018 Kustomer. All rights reserved.
//

#import "KUSClientActivityManager.h"

#import <QuartzCore/CABase.h>

#import "KUSClientActivityDataSource.h"
#import "KUSUserSession.h"
#import "KUSTimer.h"

@interface KUSClientActivityManager () <KUSObjectDataSourceListener> {
    __weak KUSUserSession *_userSession;
    NSString *_previousPageName;
    NSTimeInterval _currentPageStartTime;

    NSArray<KUSTimer *> *_timers;
    KUSClientActivityDataSource *_activityDataSource;
}

@end

@implementation KUSClientActivityManager

#pragma mark - Lifecycle methods

- (instancetype)initWithUserSession:(KUSUserSession *)userSession
{
    self = [super init];
    if (self) {
        _userSession = userSession;
    }
    return self;
}

#pragma mark - Internal methods

- (void)_cancelTimers
{
    NSArray<KUSTimer *> *timers = [_timers copy];
    _timers = nil;
    for (KUSTimer *timer in timers) {
        [timer invalidate];
    }
}

- (void)_updateTimers
{
    [self _cancelTimers];

    if (_activityDataSource.object == nil) {
        return;
    }

    NSMutableArray<KUSTimer *> *timers = [[NSMutableArray alloc] initWithCapacity:_activityDataSource.intervals.count];
    for (NSNumber *intervalNumber in _activityDataSource.intervals) {
        // The time intervals in the response are relative to the 0 second start time
        NSTimeInterval intervalTimeFromNow = intervalNumber.doubleValue - _activityDataSource.currentPageSeconds;
        if (intervalTimeFromNow > 0) {
            KUSTimer *timer = [KUSTimer scheduledTimerWithTimeInterval:intervalNumber.doubleValue
                                                                        target:self
                                                                      selector:@selector(_onActivityTimer:)
                                                                       repeats:NO];
            timer.userInfo = intervalNumber;
            [timers addObject:timer];
        }
    }
    _timers = timers;
}

- (void)_requestClientActivity
{
    [self _requestClientActivityWithCurrentPageSeconds:[self _timeOnCurrentPage]];
}

- (void)_requestClientActivityWithCurrentPageSeconds:(NSTimeInterval)currentPageSeconds
{
    _activityDataSource = [[KUSClientActivityDataSource alloc] initWithUserSession:_userSession
                                                                  previousPageName:_previousPageName
                                                                   currentPageName:_currentPageName
                                                                currentPageSeconds:currentPageSeconds];
    [_activityDataSource addListener:self];
    [_activityDataSource fetch];
}

#pragma mark - Internal helper methods

- (NSTimeInterval)_timeOnCurrentPage
{
    return round(CACurrentMediaTime() - _currentPageStartTime);
}

#pragma mark - Timer methods

- (void)_onActivityTimer:(KUSTimer *)timer
{
    NSNumber *intervalNumber = timer.userInfo;
    [self _requestClientActivityWithCurrentPageSeconds:[intervalNumber doubleValue]];
}

#pragma mark - Public methods

- (void)setCurrentPageName:(NSString *)currentPageName
{
    if (_currentPageName == currentPageName || [_currentPageName isEqualToString:currentPageName]) {
        return;
    }
    _previousPageName = [_currentPageName copy];
    _currentPageName = [currentPageName copy];

    [self _cancelTimers];
    [_activityDataSource cancel];
    _activityDataSource = nil;

    // If we don't have a current page name, stop here.
    if (_currentPageName == nil) {
        return;
    }

    // Check that settings is fetched and no history is not enabled
    if (_userSession.chatSettingsDataSource.didFetch) {
        KUSChatSettings *settings = [_userSession.chatSettingsDataSource object];
        if (settings.campaignsEnabled) {
            _currentPageStartTime = CACurrentMediaTime();
            [self _requestClientActivityWithCurrentPageSeconds:0];
            return;
        }
    }
    else {
        [_userSession.chatSettingsDataSource addListener:self];
        [_userSession.chatSettingsDataSource fetch];
    }
}

#pragma mark - KUSObjectDataSourceListener methods

- (void)objectDataSourceDidLoad:(KUSObjectDataSource *)dataSource
{
    if (dataSource == _userSession.chatSettingsDataSource) {
        [_userSession.chatSettingsDataSource removeListener:self];
        
        KUSChatSettings *settings = [_userSession.chatSettingsDataSource object];
        if (settings.campaignsEnabled) {
            _currentPageStartTime = CACurrentMediaTime();
            [self _requestClientActivityWithCurrentPageSeconds:0];
        }
        return;
    }
    
    if (dataSource == _activityDataSource) {
        if (_activityDataSource.currentPageSeconds > 0) {
            // Tell the push client to perform a sessions list pull to check for automated messages
            // We delay a bit here to avoid a race in message creation delay
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [_userSession.pushClient onClientActivityTick];
            });
        }
    }
    [self _updateTimers];
}

@end
