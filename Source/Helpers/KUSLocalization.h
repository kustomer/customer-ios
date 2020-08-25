//
//  KUSLocalizationManager.h
//  Kustomer
//
//  Created by Hunain Shahid on 03/05/2018.
//  Copyright © 2018 Kustomer. All rights reserved.
//

#import <Foundation/Foundation.h>

@class KUSUserSession;
@interface KUSLocalization : NSObject

@property (nonatomic, copy) NSString *table;
@property (nonatomic, copy) NSString *language;
@property (nonatomic, copy) NSString *kbDeflectLanguage;

+ (instancetype)sharedInstance;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (void)printAllKeys;
- (NSString *)localizedString:(NSString *)key;
- (BOOL)isCurrentLanguageRTL;
- (NSLocale *)currentLocale;
- (NSString *)currentLanguage;

@end
