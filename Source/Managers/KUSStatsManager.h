//
//  KUSStatsManager.h
//  Kustomer
//
//  Created by BrainX Technologies on 27/03/2019.
//  Copyright © 2019 Kustomer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "KUSUserSession.h"

@interface KUSStatsManager : NSObject

- (instancetype)initWithUserSession:(KUSUserSession *)userSession;
- (void)updateStats:(void (^)(BOOL sessionUpdated))completion;
- (void)getStats:(void (^)(NSDate* lastActivity))completion;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end
