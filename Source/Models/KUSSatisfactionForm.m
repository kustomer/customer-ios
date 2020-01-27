//
//  KUSSatisfactionForm.m
//  Kustomer
//
//  Created by BrainX Technologies on 10/04/2019.
//  Copyright © 2019 Kustomer. All rights reserved.
//

#import "KUSSatisfactionForm.h"

@implementation KUSSatisfactionForm

#pragma mark - Class methods

+ (NSString * _Nullable)modelType
{
    return @"satisfaction";
}

#pragma mark - Lifecycle methods

- (instancetype)initWithJSON:(NSDictionary *)json
{
    self = [super initWithJSON:json];
    if (self) {
        _ratingPrompt = NSStringFromKeyPath(json, @"attributes.ratingPrompt");
        _introduction = NSStringFromKeyPath(json, @"attributes.introduction");
        _scaleLabelHigh = NSStringFromKeyPath(json, @"attributes.scale.labelHigh");
        _scaleLabelLow = NSStringFromKeyPath(json, @"attributes.scale.labelLow");
        _scaleType = KUSSatisfactionScaleTypeFromString(NSStringFromKeyPath(json, @"attributes.scale.type"));
        _scaleOptions = IntegerFromKeyPath(json, @"attributes.scale.options");
    }
    return self;
}

static KUSSatisfactionScaleType KUSSatisfactionScaleTypeFromString(NSString * string)
{
    if ([string isEqualToString:@"number"]) {
        return KUSSatisfactionScaleTypeNumber;
    } else if ([string isEqualToString:@"emoji"]) {
        return KUSSatisfactionScaleTypeEmoji;
    } else if ([string isEqualToString:@"thumb"]) {
        return KUSSatisfactionScaleTypeThumb;
    }
    return KUSSatisfactionScaleTypeUnknown;
}

@end
