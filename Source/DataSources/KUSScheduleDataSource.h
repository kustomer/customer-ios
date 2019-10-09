//
//  KUSBusinessHoursDataSource.h
//  Kustomer
//
//  Created by Hunain Shahid on 15/10/2018.
//  Copyright © 2018 Kustomer. All rights reserved.
//

#import "KUSObjectDataSource.h"
#import "KUSSchedule.h"

@interface KUSScheduleDataSource : KUSObjectDataSource

@property (nonatomic, strong) NSString* scheduleId;
- (BOOL)isActiveBusinessHours;
@end
