//
//  KUSSatisfactionForm.h
//  Kustomer
//
//  Created by BrainX Technologies on 10/04/2019.
//  Copyright © 2019 Kustomer. All rights reserved.
//

#import "KUSForm.h"

typedef NS_ENUM(NSInteger, KUSSatisfactionScaleType) {
    KUSSatisfactionScaleTypeUnknown = -1,
    KUSSatisfactionScaleTypeNumber,
    KUSSatisfactionScaleTypeEmoji,
    KUSSatisfactionScaleTypeThumb
};

@interface KUSSatisfactionForm : KUSForm

@property (nonatomic, copy, readonly) NSString *ratingPrompt;
@property (nonatomic, copy, readonly) NSString *introduction;
@property (nonatomic, assign, readonly) KUSSatisfactionScaleType scaleType;
@property (nonatomic, copy, readonly) NSString *scaleLabelHigh;
@property (nonatomic, copy, readonly) NSString *scaleLabelLow;
@property (nonatomic, assign, readonly) NSInteger scaleOptions;
@end

