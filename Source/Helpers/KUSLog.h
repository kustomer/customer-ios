//
//  KUSLog.h
//  Kustomer
//
//  Created by Daniel Amitay on 10/14/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSUInteger, KUSLogOptions) {
    KUSLogOptionInfo                = 1 << 0,
    KUSLogOptionErrors              = 1 << 1,
    KUSLogOptionRequests            = 1 << 2,
    KUSLogOptionPusher              = 1 << 3,
    KUSLogOptionDebug               = 1 << 4,
    KUSLogOptionAll                 = 0xFFFFFF
};

#import "Kustomer_Private.h"

#define KUSLog(req, fmt, ...)       \
    do {                \
        if ([Kustomer logOptions] & req) {         \
            NSLog((@"[Kustomer] " fmt), ##__VA_ARGS__); \
        } \
    } while(0)

#define KUSLogInfo(fmt, ...) KUSLog(KUSLogOptionInfo, fmt, ##__VA_ARGS__);
#define KUSLogError(fmt, ...) KUSLog(KUSLogOptionErrors, fmt, ##__VA_ARGS__);
#define KUSLogRequest(fmt, ...) KUSLog(KUSLogOptionRequests, fmt, ##__VA_ARGS__);
#define KUSLogPusher(fmt, ...) KUSLog(KUSLogOptionPusher, fmt, ##__VA_ARGS__);
#define KUSLogPusherError(fmt, ...) KUSLog(KUSLogOptionErrors | KUSLogOptionPusher, fmt, ##__VA_ARGS__);
#define KUSLogDebug(fmt, ...) KUSLog(KUSLogOptionDebug, fmt, ##__VA_ARGS__);
