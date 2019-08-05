//
//  KUSMultipleAvatarsView.m
//  Kustomer
//
//  Created by Daniel Amitay on 1/1/18.
//  Copyright © 2018 Kustomer. All rights reserved.
//

#import "KUSMultipleAvatarsView.h"

#import "KUSAvatarImageView.h"
#import "KUSImage.h"
#import "KUSLocalization.h"

static const NSUInteger kKUSDefaultMaximumAvatarsToDisplay = 3;

@interface KUSMultipleAvatarsView () {
    __weak KUSUserSession *_userSession;

    NSArray<KUSAvatarImageView *> *_avatarViews;
}

@end

@implementation KUSMultipleAvatarsView

#pragma mark - Class methods

+ (void)initialize
{
    if (self == [KUSMultipleAvatarsView class]) {
        KUSMultipleAvatarsView *appearance = [KUSMultipleAvatarsView appearance];
        [appearance setMaximumAvatarsToDisplay:kKUSDefaultMaximumAvatarsToDisplay];
    }
}

#pragma mark - Lifecycle methods

- (instancetype)initWithUserSession:(KUSUserSession *)userSession
{
    self = [super init];
    if (self) {
        _userSession = userSession;
        self.clipsToBounds = YES;
        [self _rebuildAvatarViews];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    BOOL isRTL = [[KUSLocalization sharedInstance] isCurrentLanguageRTL];
    
    CGFloat height = self.bounds.size.height;
    CGFloat additionalItemGap = ceil(height * 0.1);
    CGFloat additionalItemWidth = height * 0.5 + additionalItemGap;
    CGFloat totalWidth = height + (_avatarViews.count - 1) * additionalItemWidth;
    CGFloat startingOffset = isRTL ? (self.bounds.size.width - totalWidth) / 2.0 + (_avatarViews.count - 1) * additionalItemWidth : (self.bounds.size.width - totalWidth) / 2.0;

    KUSAvatarImageView *previousAvatarView = nil;
    for (KUSAvatarImageView *avatarView in _avatarViews) {
        avatarView.frame = (CGRect) {
            .origin.x = startingOffset,
            .origin.y = 0.0,
            .size.width = height,
            .size.height = height
        };

        if (previousAvatarView) {
            UIBezierPath *outerPath = [UIBezierPath bezierPathWithRect:avatarView.bounds];
            [outerPath setUsesEvenOddFillRule:YES];
            CGRect maskRect = CGRectOffset(avatarView.bounds, isRTL ? additionalItemWidth : -additionalItemWidth, 0.0);
            maskRect = CGRectInset(maskRect, -additionalItemGap, -additionalItemGap);
            UIBezierPath *maskPath = [UIBezierPath bezierPathWithOvalInRect:maskRect];
            [outerPath appendPath:maskPath];

            CAShapeLayer *maskLayer = [CAShapeLayer layer];
            maskLayer.frame = avatarView.bounds;
            maskLayer.fillRule = kCAFillRuleEvenOdd;
            maskLayer.path = outerPath.CGPath;
            avatarView.layer.mask = maskLayer;
        }

        startingOffset += isRTL ? -additionalItemWidth : additionalItemWidth;
        previousAvatarView = avatarView;
    }
}

#pragma mark - Public methods

- (void)setUserIds:(NSArray<NSString *> *)userIds
{
    if ([_userIds isEqualToArray:userIds]) {
        return;
    }
    _userIds = userIds;
    [self _rebuildAvatarViews];
}

#pragma mark - Internal methods

- (void)_rebuildAvatarViews
{
    for (KUSAvatarImageView *avatarView in _avatarViews) {
        [avatarView removeFromSuperview];
    }

    NSMutableArray<KUSAvatarImageView *> *avatarViews = [[NSMutableArray alloc] initWithCapacity:_userIds.count + 1];

    for (NSUInteger i = 0; i < MIN(_userIds.count, self.maximumAvatarsToDisplay); i++) {
        NSString *userId = [_userIds objectAtIndex:i];
        KUSAvatarImageView *userAvatarView = [[KUSAvatarImageView alloc] initWithUserSession:_userSession];
        [userAvatarView setUserId:userId];
        [userAvatarView setAccessibilityIdentifier:@"agentAvatarImageView"];
        [avatarViews addObject:userAvatarView];
    }

    if (avatarViews.count < self.maximumAvatarsToDisplay) {
        KUSAvatarImageView *companyAvatarView = [[KUSAvatarImageView alloc] initWithUserSession:_userSession];
        [companyAvatarView setAccessibilityIdentifier:@"companyAvatarImageView"];
        [avatarViews addObject:companyAvatarView];
    }

    for (KUSAvatarImageView *avatarView in avatarViews.reverseObjectEnumerator) {
        [self addSubview:avatarView];
    }
    _avatarViews = avatarViews;
    [self setNeedsLayout];
}

#pragma mark - UIAppearance methods

- (void)setMaximumAvatarsToDisplay:(NSUInteger)maximumAvatarsToDisplay
{
    _maximumAvatarsToDisplay = MAX(maximumAvatarsToDisplay, 1);
    [self _rebuildAvatarViews];
}

@end
