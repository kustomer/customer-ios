//
//  KUSTypingIndicatorTableViewCell.m
//  Kustomer
//
//  Created by Hunain Shahid on 17/04/2019.
//  Copyright © 2019 Kustomer. All rights reserved.
//

#import "RTSpinKitView.h"
#import "KUSTypingIndicatorTableViewCell.h"
#import "KUSChatMessageTableViewCell.h"


#import "KUSAvatarImageView.h"

static const CGFloat kSpinnerSize = 25.0;
static const CGFloat kBubbleSidePadding = 12.0;

static const CGFloat kRowSidePadding = 11.0;
static const CGFloat kRowTopPadding = 3.0;

static const CGFloat kMinBubbleHeight = 38.0;

static const CGFloat kAvatarDiameter = 40.0;

@interface KUSTypingIndicatorTableViewCell () {
    KUSUserSession *_userSession;
    
    KUSAvatarImageView *_avatarImageView;
    UIView *_bubbleView;
    RTSpinKitView *spinner;
}

@end

@implementation KUSTypingIndicatorTableViewCell

#pragma mark - Class methods

+ (void)initialize
{
    if (self == [KUSTypingIndicatorTableViewCell class]) {
        KUSTypingIndicatorTableViewCell *appearance = [KUSTypingIndicatorTableViewCell appearance];
        [appearance setTypingIndicatorColor:[UIColor grayColor]];
    }
}

+ (CGFloat)heightForBubble
{
    return kMinBubbleHeight + kRowTopPadding * 2.0;
}


#pragma mark - Lifecycle methods

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier userSession:(KUSUserSession *)userSession
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setBackgroundColor:[[KUSChatMessageTableViewCell appearance] backgroundColor]];
        
        _avatarImageView = [[KUSAvatarImageView alloc] initWithUserSession:userSession];
        [self.contentView addSubview:_avatarImageView];
        
        _bubbleView = [[UIView alloc] init];
        _bubbleView.layer.masksToBounds = YES;
        [_bubbleView setBackgroundColor:[[KUSChatMessageTableViewCell appearance] companyBubbleColor]];
        [self.contentView addSubview:_bubbleView];
        
        spinner = [[RTSpinKitView alloc] initWithStyle:RTSpinKitViewStyleThreeBounce];
        [spinner setSpinnerSize:kSpinnerSize];
        [spinner sizeToFit];
        [_bubbleView addSubview:spinner];
    }
    return self;
}

#pragma mark - Property methods

- (void)setTypingIndicator:(KUSTypingIndicator *)typingIndicator
{
    [_avatarImageView setUserId:typingIndicator.userId];
}

#pragma mark - Layout methods

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    BOOL isRTL = [[KUSLocalization sharedInstance] isCurrentLanguageRTL];
    CGSize bubbleViewSize = (CGSize) {
        .width = kSpinnerSize + kBubbleSidePadding * 2.0,
        .height = kMinBubbleHeight
    };
    CGFloat bubbleX = isRTL ? self.contentView.bounds.size.width - bubbleViewSize.width - 60.0 : 60.0;
    _bubbleView.frame = (CGRect) {
        .origin.x = bubbleX,
        .origin.y = kRowTopPadding,
        .size = bubbleViewSize
    };
    _bubbleView.layer.cornerRadius = MIN(_bubbleView.frame.size.height / 2.0, 15.0);
    
    _avatarImageView.frame = (CGRect) {
        .origin.x = isRTL ? self.contentView.bounds.size.width - kRowSidePadding - 40.0 : kRowSidePadding,
        .origin.y = ((bubbleViewSize.height + kRowTopPadding * 2.0) - kAvatarDiameter) / 2.0,
        .size.width = kAvatarDiameter,
        .size.height = kAvatarDiameter
    };
    
    // Aligning the three bounce animation at the center
    CGFloat spinnerYDif = kSpinnerSize / 8;
    spinner.frame = (CGRect) {
        .origin.x = kBubbleSidePadding,
        .origin.y = (bubbleViewSize.height - kSpinnerSize) / 2.0 - spinnerYDif,
        .size.width = kSpinnerSize,
        .size.height = kSpinnerSize
    };
}

#pragma mark - UIAppearance methods

- (void)setTypingIndicatorColor:(UIColor *)color
{
    _typingIndicatorColor = color;
    [spinner setColor:_typingIndicatorColor];
}

@end
