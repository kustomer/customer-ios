//
//  KUSChatMessageTableViewCell.m
//  Kustomer
//
//  Created by Daniel Amitay on 7/16/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSChatMessageTableViewCell.h"

#import <SDWebImage/UIImageView+WebCache.h>
#import <SDWebImage/UIView+WebCache.h>
#import <TTTAttributedLabel/TTTAttributedLabel.h>

#import "KUSChatMessage.h"
#import "KUSColor.h"
#import "KUSDate.h"
#import "KUSImage.h"
#import "KUSText.h"
#import "KUSUserSession.h"
#import "KUSTimer.h"

#import "KUSAvatarImageView.h"

// If sending messages takes less than 750ms, we don't want to show the loading indicator
static NSTimeInterval kOptimisticSendLoadingDelay = 0.75;

static const CGFloat kBubbleTopPadding = 10.0;
static const CGFloat kBubbleSidePadding = 12.0;

static const CGFloat kRowSidePadding = 11.0;
static const CGFloat kRowTopPadding = 3.0;

static const CGFloat kMaxBubbleWidth = 250.0;
static const CGFloat kMinBubbleHeight = 38.0;

static const CGFloat kAvatarDiameter = 40.0;

static const CGFloat kTimestampTopPadding = 4.0;

@interface KUSChatMessageTableViewCell () <TTTAttributedLabelDelegate> {
    KUSUserSession *_userSession;
    KUSChatMessage *_chatMessage;
    BOOL _showsAvatar;
    BOOL _showsTimestamp;
    KUSTimer *_sendingFadeTimer;

    KUSAvatarImageView *_avatarImageView;
    UIView *_bubbleView;
    TTTAttributedLabel *_labelView;
    UIImageView *_imageView;
    UIButton *_errorButton;
    UILabel *_timestampLabel;
}

@end

@implementation KUSChatMessageTableViewCell

#pragma mark - Class methods

+ (void)initialize
{
    if (self == [KUSChatMessageTableViewCell class]) {
        KUSChatMessageTableViewCell *appearance = [KUSChatMessageTableViewCell appearance];
        [appearance setTextFont:[UIFont systemFontOfSize:14.0]];
        [appearance setUserBubbleColor:[KUSColor blueColor]];
        [appearance setCompanyBubbleColor:[KUSColor lightGrayColor]];
        [appearance setUserTextColor:[UIColor whiteColor]];
        [appearance setCompanyTextColor:[UIColor blackColor]];
        [appearance setTimestampFont:[UIFont systemFontOfSize:11.0]];
        [appearance setTimestampTextColor:[UIColor grayColor]];
    }
}

+ (CGFloat)heightForChatMessage:(KUSChatMessage *)chatMessage maxWidth:(CGFloat)maxWidth
{
    CGFloat height = [self boundingSizeForMessage:chatMessage maxWidth:maxWidth].height;
    height += kBubbleTopPadding * 2.0;
    height = MAX(height, kMinBubbleHeight);
    height += kRowTopPadding * 2.0;
    return height;
}

+ (CGFloat)heightForTimestamp
{
    UIFont *font = [self timestampFont];
    if (font) {
        return font.lineHeight + kTimestampTopPadding;
    } else {
        return 0.0;
    }
}

+ (UIFont *)timestampFont
{
    KUSChatMessageTableViewCell *appearance = [KUSChatMessageTableViewCell appearance];
    return [appearance timestampFont];
}

+ (CGFloat)fontSize
{
    return [self messageFont].pointSize;
}

+ (UIFont *)messageFont
{
    KUSChatMessageTableViewCell *appearance = [KUSChatMessageTableViewCell appearance];
    return [appearance textFont];
}

+ (CGSize)boundingSizeForMessage:(KUSChatMessage *)message maxWidth:(CGFloat)maxWidth
{
    switch (message.type) {
        default:
        case KUSChatMessageTypeText:
            return [self boundingSizeForText:message.body maxWidth:maxWidth];
        case KUSChatMessageTypeImage:
            return [self boundingSizeForImage:message.imageURL maxWidth:maxWidth];
    }
}

+ (CGSize)boundingSizeForImage:(NSURL *)imageURL maxWidth:(CGFloat)maxWidth
{
    CGFloat actualMaxWidth = MIN(kMaxBubbleWidth - kBubbleSidePadding * 2.0, maxWidth);
    CGFloat size = MIN(ceil([UIScreen mainScreen].bounds.size.width / 2.0), actualMaxWidth);
    return CGSizeMake(size, size);
}

+ (CGSize)boundingSizeForText:(NSString *)text maxWidth:(CGFloat)maxWidth
{
    CGFloat actualMaxWidth = MIN(kMaxBubbleWidth - kBubbleSidePadding * 2.0, maxWidth);

    NSAttributedString *attributedString = [KUSText attributedStringFromText:text fontSize:[self fontSize]];

    CGSize maxSize = CGSizeMake(actualMaxWidth, 1000.0);
    CGRect boundingRect = [attributedString boundingRectWithSize:maxSize
                                                         options:(NSStringDrawingUsesLineFragmentOrigin
                                                                  | NSStringDrawingUsesFontLeading)
                                                         context:nil];

    CGFloat scale = [UIScreen mainScreen].scale;
    CGSize boundingSize = boundingRect.size;
    boundingSize.width = ceil(boundingSize.width * scale) / scale;
    boundingSize.height = ceil(boundingSize.height * scale) / scale;
    return boundingSize;
}

#pragma mark - Lifecycle methods

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier userSession:(KUSUserSession *)userSession
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        _avatarImageView = [[KUSAvatarImageView alloc] initWithUserSession:userSession];
        [self.contentView addSubview:_avatarImageView];

        _bubbleView = [[UIView alloc] init];
        _bubbleView.layer.masksToBounds = YES;
        [self.contentView addSubview:_bubbleView];

        _labelView = [[TTTAttributedLabel alloc] initWithFrame:self.bounds];
        _labelView.delegate = self;
        _labelView.enabledTextCheckingTypes = NSTextCheckingTypeLink;
        _labelView.textAlignment = NSTextAlignmentLeft;
        _labelView.numberOfLines = 0;
        _labelView.activeLinkAttributes = @{ NSBackgroundColorAttributeName: [UIColor colorWithWhite:0.0 alpha:0.2] };
        _labelView.linkAttributes = nil;
        _labelView.inactiveLinkAttributes = nil;
        [_bubbleView addSubview:_labelView];

        _imageView = [[UIImageView alloc] init];
        _imageView.userInteractionEnabled = YES;
        _imageView.backgroundColor = [UIColor clearColor];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.layer.cornerRadius = 4.0;
        _imageView.layer.masksToBounds = YES;
        [_bubbleView addSubview:_imageView];

        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_didTapImage)];
        [_imageView addGestureRecognizer:tapGestureRecognizer];

        _timestampLabel = [[UILabel alloc] init];
        _timestampLabel.userInteractionEnabled = NO;
        _timestampLabel.backgroundColor = self.backgroundColor;
        _timestampLabel.adjustsFontSizeToFitWidth = YES;
        _timestampLabel.minimumScaleFactor = 8.0 / 11.0;
        [self.contentView addSubview:_timestampLabel];
    }
    return self;
}

- (void)dealloc
{
    _labelView.delegate = nil;
}

#pragma mark - Layout methods

- (void)layoutSubviews
{
    [super layoutSubviews];

    BOOL isRTL = [[KUSLocalization sharedInstance] isCurrentLanguageRTL];
    BOOL currentUser = KUSChatMessageSentByUser(_chatMessage);

    CGSize boundingSizeForContent = [[self class] boundingSizeForMessage:_chatMessage maxWidth:self.contentView.bounds.size.width];
    CGSize bubbleViewSize = (CGSize) {
        .width = boundingSizeForContent.width + kBubbleSidePadding * 2.0,
        .height = boundingSizeForContent.height + kBubbleTopPadding * 2.0
    };
    CGFloat bubbleCurrentX = isRTL ? kRowSidePadding : self.contentView.bounds.size.width - bubbleViewSize.width - kRowSidePadding;
    CGFloat bubbleOtherX = isRTL ? self.contentView.bounds.size.width - bubbleViewSize.width - 60.0 : 60.0;
    _bubbleView.frame = (CGRect) {
        .origin.x = currentUser ? bubbleCurrentX : bubbleOtherX,
        .origin.y = kRowTopPadding,
        .size = bubbleViewSize
    };
    _bubbleView.layer.cornerRadius = MIN(_bubbleView.frame.size.height / 2.0, 15.0);

    _avatarImageView.hidden = currentUser || !_showsAvatar;
    _avatarImageView.frame = (CGRect) {
        .origin.x = isRTL ? self.contentView.bounds.size.width - kRowSidePadding - 40.0 : kRowSidePadding,
        .origin.y = ((bubbleViewSize.height + kRowTopPadding * 2.0) - kAvatarDiameter) / 2.0,
        .size.width = kAvatarDiameter,
        .size.height = kAvatarDiameter
    };

    switch (_chatMessage.type) {
        default:
        case KUSChatMessageTypeText: {
            _labelView.frame = (CGRect) {
                .origin.x = (_bubbleView.bounds.size.width - boundingSizeForContent.width) / 2.0,
                .origin.y = (_bubbleView.bounds.size.height - boundingSizeForContent.height) / 2.0,
                .size = boundingSizeForContent
            };
        }   break;
        case KUSChatMessageTypeImage: {
            _imageView.frame = (CGRect) {
                .origin.x = (_bubbleView.bounds.size.width - boundingSizeForContent.width) / 2.0,
                .origin.y = (_bubbleView.bounds.size.height - boundingSizeForContent.height) / 2.0,
                .size = boundingSizeForContent
            };
        }   break;
    }

    [_labelView setAccessibilityIdentifier:currentUser ? @"customerMessageLabel" : @"agentMessageLabel"];
    _errorButton.frame = (CGRect) {
        .origin.x = isRTL ? CGRectGetMaxX(_bubbleView.frame) + kMinBubbleHeight + 5.0 : _bubbleView.frame.origin.x - kMinBubbleHeight - 5.0,
        .origin.y = _bubbleView.frame.origin.y + (_bubbleView.frame.size.height - kMinBubbleHeight) / 2.0,
        .size.width = kMinBubbleHeight,
        .size.height = kMinBubbleHeight
    };

    _timestampLabel.hidden = !_showsTimestamp;
    CGFloat timestampInset = ceil(_bubbleView.layer.cornerRadius / 2.0);
    CGFloat timestampWidth = MAX(bubbleViewSize.width - timestampInset * 2.0, 200.0);
    CGFloat timestampCurrentX = isRTL ? _bubbleView.frame.origin.x + timestampInset : CGRectGetMaxX(_bubbleView.frame) - timestampWidth - timestampInset;
    CGFloat timestampOtherX = isRTL ? CGRectGetMaxX(_bubbleView.frame) - timestampWidth - timestampInset : _bubbleView.frame.origin.x + timestampInset;
    _timestampLabel.frame = (CGRect) {
        .origin.x = (currentUser ? timestampCurrentX : timestampOtherX),
        .origin.y = CGRectGetMaxY(_bubbleView.frame) + kTimestampTopPadding,
        .size.width = timestampWidth,
        .size.height = MAX([[self class] heightForTimestamp] - kTimestampTopPadding, 0.0)
    };
    [_timestampLabel setAccessibilityIdentifier:currentUser ? @"customerMessageTimestampLabel" : @"agentMessageTimestampLabel"];
}

#pragma mark - Internal logic methods

- (void)_updateAlphaForState
{
    [_sendingFadeTimer invalidate];
    _sendingFadeTimer = nil;

    switch(_chatMessage.state) {
        case KUSChatMessageStateSent: {
            _bubbleView.alpha = 1.0;
        }   break;
        case KUSChatMessageStateSending: {
            NSTimeInterval timeElapsed = -[_chatMessage.createdAt timeIntervalSinceNow];
            if (timeElapsed >= kOptimisticSendLoadingDelay) {
                _bubbleView.alpha = 0.5;
            } else {
                _bubbleView.alpha = 1.0;

                NSTimeInterval timerInterval = kOptimisticSendLoadingDelay - timeElapsed;
                _sendingFadeTimer = [KUSTimer scheduledTimerWithTimeInterval:timerInterval
                                                                          target:self
                                                                        selector:_cmd
                                                                         repeats:NO];
            }
        }   break;
        case KUSChatMessageStateFailed: {
            _bubbleView.alpha = 0.5;
        }   break;
    }
}

- (void)_updateImageForMessage
{
    BOOL currentUser = KUSChatMessageSentByUser(_chatMessage);

    [_imageView setContentMode:UIViewContentModeScaleAspectFill];
    [_imageView sd_setShowActivityIndicatorView:YES];
    [_imageView sd_setIndicatorStyle:(currentUser ? UIActivityIndicatorViewStyleWhite : UIActivityIndicatorViewStyleGray)];
    SDWebImageOptions options = SDWebImageHighPriority | SDWebImageScaleDownLargeImages | SDWebImageRetryFailed;

    KUSChatMessage *startingChatMessage = _chatMessage;
    __weak KUSChatMessageTableViewCell *weakSelf = self;
    [_imageView
     sd_setImageWithURL:_chatMessage.imageURL
     placeholderImage:nil
     options:options
     completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
         __strong KUSChatMessageTableViewCell *strongSelf = weakSelf;
         if (strongSelf == nil) {
             return;
         }
         if (strongSelf->_chatMessage != startingChatMessage) {
             return;
         }
         if (error) {
             [strongSelf->_imageView setImage:[KUSImage errorImage]];
             [strongSelf->_imageView setContentMode:UIViewContentModeCenter];
         }
     }];
}

#pragma mark - Property methods

- (void)setChatMessage:(KUSChatMessage *)chatMessage
{
    _chatMessage = chatMessage;

    BOOL isRTL = [[KUSLocalization sharedInstance] isCurrentLanguageRTL];
    BOOL currentUser = KUSChatMessageSentByUser(_chatMessage);

    KUSChatMessageTableViewCell *appearance = [KUSChatMessageTableViewCell appearance];
    UIColor *bubbleColor = (currentUser ? appearance.userBubbleColor : appearance.companyBubbleColor);
    UIColor *textColor = (currentUser ? appearance.userTextColor : appearance.companyTextColor);

    _bubbleView.backgroundColor = bubbleColor;
    _imageView.backgroundColor = bubbleColor;
    _labelView.backgroundColor = bubbleColor;
    _labelView.textColor = textColor;

    _labelView.hidden = _chatMessage.type != KUSChatMessageTypeText;
    _imageView.hidden = _chatMessage.type != KUSChatMessageTypeImage;

    switch (_chatMessage.type) {
        case KUSChatMessageTypeText: {
            _labelView.text = [KUSText attributedStringFromText:_chatMessage.body fontSize:[[self class] fontSize] color:textColor];

            _imageView.image = nil;
            [_imageView sd_setImageWithURL:nil];
        }   break;
        case KUSChatMessageTypeImage: {
            _labelView.text = nil;

            [self _updateImageForMessage];
        }   break;
    }

    [_avatarImageView setUserId:(currentUser ? nil : _chatMessage.sentById)];

    if (_chatMessage.state == KUSChatMessageStateFailed) {
        if (_errorButton == nil) {
            _errorButton = [[UIButton alloc] init];
            [_errorButton setImage:[KUSImage errorImage] forState:UIControlStateNormal];
            [_errorButton addTarget:self
                             action:@selector(_didTapError)
                   forControlEvents:UIControlEventTouchUpInside];
            [self.contentView addSubview:_errorButton];
        }
        _errorButton.hidden = NO;
    } else {
        _errorButton.hidden = YES;
    }

    _timestampLabel.textAlignment = (currentUser ? isRTL ? NSTextAlignmentLeft : NSTextAlignmentRight : isRTL ?  NSTextAlignmentRight : NSTextAlignmentLeft);
    _timestampLabel.text = [KUSDate messageTimestampTextFromDate:_chatMessage.createdAt];

    [self _updateAlphaForState];
    [self setNeedsLayout];
}

- (void)setShowsAvatar:(BOOL)showsAvatar
{
    _showsAvatar = showsAvatar;
    [self setNeedsLayout];
}

- (void)setShowsTimestamp:(BOOL)showsTimestamp
{
    _showsTimestamp = showsTimestamp;
    [self setNeedsLayout];
}

#pragma mark - Interface element methods

- (void)_didTapError
{
    if ([self.delegate respondsToSelector:@selector(chatMessageTableViewCellDidTapError:forMessage:)]) {
        [self.delegate chatMessageTableViewCellDidTapError:self forMessage:_chatMessage];
    }
}

#pragma mark - TTTAttributedLabelDelegate methods

- (void)attributedLabel:(TTTAttributedLabel *)label didSelectLinkWithURL:(NSURL *)url
{
    if ([self.delegate respondsToSelector:@selector(chatMessageTableViewCell:didTapLink:)]) {
        [self.delegate chatMessageTableViewCell:self didTapLink:url];
    }
}

#pragma mark - UIGestureRecognizer methods

- (void)_didTapImage
{
    if ([_imageView.image isEqual:[KUSImage errorImage]]) {
        [self _updateImageForMessage];
        return;
    }

    if ([self.delegate respondsToSelector:@selector(chatMessageTableViewCellDidTapImage:forMessage:)]) {
        [self.delegate chatMessageTableViewCellDidTapImage:self forMessage:_chatMessage];
    }
}

#pragma mark - UIAppearance methods

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    _timestampLabel.backgroundColor = backgroundColor;
}

- (void)setTimestampFont:(UIFont *)timestampFont
{
    _timestampFont = timestampFont;
    _timestampLabel.font = _timestampFont;
}

- (void)setTimestampTextColor:(UIColor *)timestampTextColor
{
    _timestampTextColor = timestampTextColor;
    _timestampLabel.textColor = _timestampTextColor;
}

@end
