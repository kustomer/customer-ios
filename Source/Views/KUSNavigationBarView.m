//
//  KUSNavigationBarView.m
//  Kustomer
//
//  Created by Daniel Amitay on 8/16/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSNavigationBarView.h"

#import "KUSMultipleAvatarsView.h"
#import "KUSColor.h"
#import "KUSImage.h"
#import "KUSFadingButton.h"
#import "KUSUserSession.h"
#import "KUSSessionQueuePollingManager.h"
#import "KUSDate.h"
#import "KUSText.h"

typedef NS_ENUM(NSInteger, KUSMessageLabel) {
    KUSMessageLabelGreeting,
    KUSMessageLabelWaiting,
    KUSMessageLabelAll,
    KUSMessageLabelNone
};

static const CGFloat kKUSNavigationBarHeight = 44.0;
static const CGFloat kKUSLabelSidePadding = 10.0;

static const CGSize kKUSNavigationBarBackButtonSize = { 40.0, kKUSNavigationBarHeight };
static const CGSize kKUSNavigationBarBackImageSize = { 12.0, 21.0 };
static const CGSize kKUSNavigationBarDismissButtonSize = { 49.0, kKUSNavigationBarHeight };
static const CGSize kKUSNavigationBarDismissImageSize = { 17.0, 17.0 };

@interface KUSNavigationBarView () <KUSObjectDataSourceListener, KUSChatMessagesDataSourceListener, KUSSessionQueuePollingListener> {
    KUSUserSession *_userSession;
    KUSChatMessagesDataSource *_chatMessagesDataSource;
    KUSUserDataSource *_userDataSource;

    KUSMultipleAvatarsView *_avatarsView;
    UILabel *_nameLabel;
    UILabel *_greetingLabel;
    UILabel *_waitingLabel;
    UIView *_separatorView;

    UIButton *_backButton;
    UILabel *_unreadCountLabel;
    UIButton *_dismissButton;
    
    NSString *_waitingMessage;
}

@end

@implementation KUSNavigationBarView

#pragma mark - Class methods

+ (void)initialize
{
    if (self == [KUSNavigationBarView class]) {
        KUSNavigationBarView *appearance = [KUSNavigationBarView appearance];
        [appearance setBackgroundColor:[KUSColor lightGrayColor]];
        [appearance setNameColor:[UIColor darkGrayColor]];
        [appearance setWaitingColor:[KUSColor darkGrayColor]];
        [appearance setGreetingColor:[KUSColor darkGrayColor]];
        [appearance setSeparatorColor:[KUSColor grayColor]];
        [appearance setTintColor:[KUSColor darkGrayColor]];
        [appearance setUnreadColor:[UIColor whiteColor]];
        [appearance setUnreadBackgroundColor:[KUSColor redColor]];
        [appearance setUnreadFont:[UIFont systemFontOfSize:10.0]];

        BOOL isRTL = [[KUSLocalization sharedInstance] isCurrentLanguageRTL];
        if (isRTL) {
            UIImage *backButtonImage = [KUSImage rightChevronWithColor:[UIColor blackColor] size:kKUSNavigationBarBackImageSize lineWidth:2.5];
            appearance.backButtonImage = [backButtonImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        } else {
            UIImage *backButtonImage = [KUSImage leftChevronWithColor:[UIColor blackColor] size:kKUSNavigationBarBackImageSize lineWidth:2.5];
            appearance.backButtonImage = [backButtonImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        UIImage *dismissButtonImage = [KUSImage xImageWithColor:[UIColor blackColor] size:kKUSNavigationBarDismissImageSize lineWidth:2.0];
        appearance.dismissButtonImage = [dismissButtonImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
}

#pragma mark - Lifecycle methods

- (instancetype)initWithUserSession:(KUSUserSession *)userSession
{
    self = [super init];
    if (self) {
        _userSession = userSession;

        _avatarsView = [[KUSMultipleAvatarsView alloc] initWithUserSession:_userSession];
        [_avatarsView setAccessibilityIdentifier:@"avatarsView"];
        [self addSubview:_avatarsView];

        _nameLabel = [[UILabel alloc] init];
        _nameLabel.textAlignment = NSTextAlignmentCenter;
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        _nameLabel.numberOfLines = 1;
        [_nameLabel setAccessibilityIdentifier:@"nameLabel"];
        [self addSubview:_nameLabel];
        
        _waitingLabel = [[UILabel alloc] init];
        _waitingLabel.textAlignment = NSTextAlignmentCenter;
        _waitingLabel.lineBreakMode = NSLineBreakByWordWrapping;
        _waitingLabel.numberOfLines = 0;
        [_waitingLabel setAccessibilityIdentifier:@"waitingLabel"];
        [self addSubview:_waitingLabel];
        
        _greetingLabel = [[UILabel alloc] init];
        _greetingLabel.textAlignment = NSTextAlignmentCenter;
        _greetingLabel.lineBreakMode = NSLineBreakByWordWrapping;
        _greetingLabel.numberOfLines = 0;
        [_greetingLabel setAccessibilityIdentifier:@"greetingLabel"];
        [self addSubview:_greetingLabel];
        
        _separatorView = [[UIView alloc] init];
        [self addSubview:_separatorView];

        _backButton = [[KUSFadingButton alloc] init];
        _backButton.hidden = YES;
        [_backButton addTarget:self action:@selector(_onBackButton:) forControlEvents:UIControlEventTouchUpInside];
        [_backButton setAccessibilityIdentifier:@"backButton"];
        [self addSubview:_backButton];

        _unreadCountLabel = [[UILabel alloc] init];
        _unreadCountLabel.textAlignment = NSTextAlignmentCenter;
        _unreadCountLabel.layer.masksToBounds = YES;
        _unreadCountLabel.layer.cornerRadius = 4.0;
        [_unreadCountLabel setAccessibilityIdentifier:@"unreadCountLabel"];
        [_backButton addSubview:_unreadCountLabel];
        
        _dismissButton = [[KUSFadingButton alloc] init];
        _dismissButton.hidden = YES;
        [_dismissButton addTarget:self action:@selector(_onDismissButton:) forControlEvents:UIControlEventTouchUpInside];
        [_dismissButton setAccessibilityIdentifier:@"dismissButton"];
        [self addSubview:_dismissButton];
        
        [_userSession.chatSessionsDataSource addListener:self];
        [_userSession.chatSettingsDataSource addListener:self];
        [_userSession.scheduleDataSource addListener:self];
        [self _updateTextLabels];
        [self _updateBackButtonBadge];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGSize avatarSize = CGSizeMake(self.bounds.size.width - 150.0, 30.0);
    CGFloat statusBarHeight = self.topInset;
    CGFloat greetingLabelHeight = [self _messageLabelBoundingSize:[self _greetingLabelText]
                                                             font:_greetingLabel.font].height;
    CGFloat waitLabelHeight = [self _messageLabelBoundingSize:[self _waitingLabelText]
                                                         font:_waitingLabel.font].height;
    
    if (self.showsLabels) {
        _nameLabel.font = [UIFont boldSystemFontOfSize:[self _nameLabelFontSize]];
        _greetingLabel.font = [UIFont systemFontOfSize:[self _messageLabelFontSize]];
        _waitingLabel.font = [UIFont systemFontOfSize:[self _messageLabelFontSize]];
        
        _avatarsView.frame = (CGRect) {
            .origin.x = (self.bounds.size.width - avatarSize.width) / 2.0,
            .origin.y = (self.bounds.size.height - [self _extraNavigationBarHeight] - avatarSize.height - statusBarHeight) / 2.0 + statusBarHeight + [self _avatarExtraTopPadding],
            .size = avatarSize
        };
        _nameLabel.frame = (CGRect) {
            .origin.x = kKUSLabelSidePadding,
            .origin.y = _avatarsView.frame.origin.y + _avatarsView.frame.size.height + [self _nameLabelTopPadding],
            .size.width = self.bounds.size.width - kKUSLabelSidePadding * 2.0,
            .size.height = [self _nameLabelFontSize]
        };
        
        KUSMessageLabel messageLabel = [self _messageLabelsToShow];
        if (messageLabel == KUSMessageLabelAll) {
            _waitingLabel.hidden = NO;
            _greetingLabel.hidden = NO;
            _waitingLabel.frame = (CGRect) {
                .origin.x = kKUSLabelSidePadding,
                .origin.y = _nameLabel.frame.origin.y + _nameLabel.frame.size.height + [self _messageLabelTopPadding],
                .size.width = self.bounds.size.width - kKUSLabelSidePadding * 2.0,
                .size.height = waitLabelHeight
            };
            
            _greetingLabel.frame = (CGRect) {
                .origin.x = kKUSLabelSidePadding,
                .origin.y = _waitingLabel.frame.origin.y + _waitingLabel.frame.size.height + [self _messageLabelTopPadding],
                .size.width = self.bounds.size.width - kKUSLabelSidePadding * 2.0,
                .size.height = greetingLabelHeight
            };
        } else if (messageLabel == KUSMessageLabelWaiting) {
            _waitingLabel.hidden = NO;
            _greetingLabel.hidden = YES;
            _waitingLabel.frame = (CGRect) {
                .origin.x = kKUSLabelSidePadding,
                .origin.y = _nameLabel.frame.origin.y + _nameLabel.frame.size.height + [self _messageLabelTopPadding],
                .size.width = self.bounds.size.width - kKUSLabelSidePadding * 2.0,
                .size.height = waitLabelHeight
            };
        } else {
            _greetingLabel.hidden = NO;
            _waitingLabel.hidden = YES;
            _greetingLabel.frame = (CGRect) {
                .origin.x = kKUSLabelSidePadding,
                .origin.y = _nameLabel.frame.origin.y + _nameLabel.frame.size.height + [self _messageLabelTopPadding],
                .size.width = self.bounds.size.width - kKUSLabelSidePadding * 2.0,
                .size.height = greetingLabelHeight
            };
        }
    } else {
        _avatarsView.frame = (CGRect) {
            .origin.x = (self.bounds.size.width - avatarSize.width) / 2.0,
            .origin.y = (self.bounds.size.height - avatarSize.height - statusBarHeight) / 2.0 + statusBarHeight,
            .size = avatarSize
        };
    }
    _separatorView.frame = (CGRect) {
        .origin.y = self.bounds.size.height - 0.5,
        .size.width = self.bounds.size.width,
        .size.height = 0.5
    };
    
    BOOL isRTL = [[KUSLocalization sharedInstance] isCurrentLanguageRTL];
    _backButton.frame = (CGRect) {
        .origin.x = isRTL ? self.bounds.size.width - kKUSNavigationBarBackButtonSize.width : 0.0,
        .origin.y = _topInset,
        .size = kKUSNavigationBarBackButtonSize
    };
    CGSize unreadSize = [_unreadCountLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, 15.0)];
    unreadSize.height = MAX(ceil(unreadSize.height + 4.0), 15.0);
    unreadSize.width = MAX(ceil(unreadSize.width + 4.0), 15.0);
    CGFloat unreadCountHorizontalPadding = _backButton.frame.size.width / 2.0 + _backButtonImage.size.width / 2.0 + 4.0;
    CGFloat unreadCountOriginX = isRTL ? _backButton.frame.size.width - unreadCountHorizontalPadding - unreadSize.width : unreadCountHorizontalPadding;
    _unreadCountLabel.frame = (CGRect) {
        .origin.x = unreadCountOriginX,
        .origin.y = (_backButton.frame.size.height - unreadSize.height) / 2.0,
        .size = unreadSize
    };
    _dismissButton.frame = (CGRect) {
        .origin.x = isRTL ? 0.0 : self.bounds.size.width - kKUSNavigationBarDismissButtonSize.width,
        .origin.y = _topInset,
        .size = kKUSNavigationBarDismissButtonSize
    };
    
    [self _updateTextLabels];
}

#pragma mark - Internal methods

- (CGFloat)_navigationBarBottomPadding
{
    return self.extraLarge ? 20.0 : 4.0;
}

- (CGFloat)_nameLabelFontSize
{
    return self.extraLarge ? 15.0 : 13.0;
}

- (CGFloat)_messageLabelFontSize
{
    return self.extraLarge ? 13.0 : 11.0;
}

- (CGFloat)_nameLabelTopPadding
{
    return self.extraLarge ? 8.0 : 4.0;
}

- (CGFloat)_messageLabelTopPadding
{
    return self.extraLarge ? 8.0 : 4.0;
}

- (CGFloat)_avatarExtraTopPadding
{
    return self.extraLarge ? 40.0 : 0.0;
}

- (CGFloat)_extraNavigationBarHeight
{
    CGFloat verticalPaddings = [self _navigationBarBottomPadding];
    verticalPaddings += [self _avatarExtraTopPadding];
    
    BOOL showAllMessageLabels = [self _messageLabelsToShow] == KUSMessageLabelAll;
    verticalPaddings += showAllMessageLabels ? [self _messageLabelTopPadding] * 2 : [self _messageLabelTopPadding];
    
    CGFloat messageLabelHeight = 0;
    
    KUSMessageLabel messageLabel = [self _messageLabelsToShow];
    if (messageLabel == KUSMessageLabelGreeting) {
        messageLabelHeight = [self _messageLabelBoundingSize:[self _greetingLabelText]
                                                        font:_greetingLabel.font].height;
    } else if (messageLabel == KUSMessageLabelWaiting) {
        messageLabelHeight = [self _messageLabelBoundingSize:[self _waitingLabelText]
                                                        font:_waitingLabel.font].height;
    } else if (messageLabel == KUSMessageLabelAll){
        messageLabelHeight = [self _messageLabelBoundingSize:[self _greetingLabelText]
                                                        font:_greetingLabel.font].height;
        messageLabelHeight += [self _messageLabelBoundingSize:[self _waitingLabelText]
                                                         font:_waitingLabel.font].height;
    }
    return verticalPaddings + [self _nameLabelFontSize] + messageLabelHeight;
}

- (NSString *)_greetingLabelText
{
    KUSChatSettings *chatSettings = [_userSession.chatSettingsDataSource object];
    NSString *greetingLabelText;
    if (self.extraLarge) {
        if (![_userSession.scheduleDataSource isActiveBusinessHours]) {
            greetingLabelText = chatSettings.offhoursMessage;
        } else {
            greetingLabelText = chatSettings.greeting;
        }
    }
    return greetingLabelText;
}

- (NSString *)_waitingLabelText
{
    KUSChatSettings *chatSettings = [_userSession.chatSettingsDataSource object];
    NSString *waitingLabelText;
    
    if (!self.extraLarge && ![_userSession.scheduleDataSource isActiveBusinessHours]) {
        waitingLabelText = chatSettings.offhoursMessage;
    } else if (chatSettings.volumeControlEnabled) {
        if (_waitingMessage) {
            waitingLabelText = _waitingMessage;
        } else if (chatSettings.useDynamicWaitMessage) {
            waitingLabelText = chatSettings.waitMessage;
        } else {
            waitingLabelText = chatSettings.customWaitMessage;
        }
    }
    return waitingLabelText;
}

- (KUSMessageLabel)_messageLabelsToShow
{
    if (self.showsLabels) {
        
        if (self.extraLarge) {
            if (![self _shouldShowWaitingLabel]) {
                return KUSMessageLabelGreeting;
            }
            return KUSMessageLabelAll;
        } else {
            
            if ([self _shouldShowWaitingLabel]) {
                return KUSMessageLabelWaiting;
            } else {
                return KUSMessageLabelNone;
            }
        }
    }
    return KUSMessageLabelNone;
}

- (BOOL)_shouldShowWaitingLabel
{
    KUSChatSettings *chatSettings = [_userSession.chatSettingsDataSource object];
    BOOL shouldShowWaitingLabel = chatSettings.enabled && (chatSettings.volumeControlEnabled || ![_userSession.scheduleDataSource isActiveBusinessHours]);
    
    if(_chatMessagesDataSource) {
        shouldShowWaitingLabel = shouldShowWaitingLabel && !_chatMessagesDataSource.didAgentReply;
    }
    
    return shouldShowWaitingLabel;
}

- (void)_updateTextLabels
{
    [_userDataSource removeListener:self];
    _userDataSource = [_userSession userDataSourceForUserId:_chatMessagesDataSource.firstOtherUserId];
    [_userDataSource addListener:self];
    
    // Title text (from last responder, chat settings, or organization name)
    KUSChatSettings *chatSettings = [_userSession.chatSettingsDataSource object];
    KUSUser *firstOtherUser = _userDataSource.object;
    NSString *responderName = firstOtherUser.displayName;
    if (responderName.length == 0) {
        responderName = chatSettings.teamName.length ? chatSettings.teamName : _userSession.organizationName;
    }
    _nameLabel.text = responderName;
    _waitingLabel.text = [self _waitingLabelText];
    _greetingLabel.text = [self _greetingLabelText];
}

- (void)_updateBackButtonBadge
{
    NSUInteger unreadCount = [_userSession.chatSessionsDataSource totalUnreadCountExcludingSessionId:_sessionId];
    if (unreadCount > 0) {
        _unreadCountLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)unreadCount];
        _unreadCountLabel.hidden = NO;
    } else {
        _unreadCountLabel.hidden = YES;
    }
    [self setNeedsLayout];
}

- (CGSize)_messageLabelBoundingSize:(NSString *)text font:(UIFont *)font
{
    if (!text || [text isEqualToString:@""]) {
        return CGSizeZero;
    }
    
    CGSize maxSize = CGSizeMake(self.bounds.size.width - kKUSLabelSidePadding * 2.0, MAXFLOAT);
    
    CGRect boundingRect = [text boundingRectWithSize:maxSize
                                             options:NSStringDrawingUsesLineFragmentOrigin
                                          attributes:@{NSFontAttributeName : font}
                                             context:nil];
    
    CGFloat scale = [UIScreen mainScreen].scale;
    CGSize boundingSize = boundingRect.size;
    boundingSize.width = ceil(boundingSize.width * scale) / scale;
    boundingSize.height = ceil(boundingSize.height * scale) / scale;
    
    // To be uncommented if the subtitle text number of lines needs to be kept fixed
    //boundingSize.height = MIN(boundingSize.height, [UIFont systemFontOfSize:height].lineHeight * 2);
    
    return boundingSize;
}

#pragma mark - Interface element methods

- (void)_onBackButton:(UIButton *)button
{
    if ([self.delegate respondsToSelector:@selector(navigationBarViewDidTapBack:)]) {
        [self.delegate navigationBarViewDidTapBack:self];
    }
}

- (void)_onDismissButton:(UIButton *)button
{
    if ([self.delegate respondsToSelector:@selector(navigationBarViewDidTapDismiss:)]) {
        [self.delegate navigationBarViewDidTapDismiss:self];
    }
}

#pragma mark - Public methods

- (CGFloat)desiredHeight
{
    if (self.showsLabels) {
        return [self _extraNavigationBarHeight] + self.topInset + kKUSNavigationBarHeight;
    } else {
        return self.topInset + kKUSNavigationBarHeight;
    }
}

- (void)setSessionId:(NSString *)sessionId
{
    if (_sessionId == sessionId || [_sessionId isEqualToString:sessionId]) {
        return;
    }
    _sessionId = [sessionId copy];
    [self setNeedsLayout];
    
    [_chatMessagesDataSource.sessionQueuePollingManager removeListener:self];
    [_chatMessagesDataSource removeListener:self];
    
    _chatMessagesDataSource = [_userSession chatMessagesDataSourceForSessionId:_sessionId];
    [_chatMessagesDataSource addListener:self];
    [_chatMessagesDataSource.sessionQueuePollingManager addListener:self];
    [_avatarsView setUserIds:_chatMessagesDataSource.otherUserIds];
    
    BOOL isVolumeControlPollingActive = _chatMessagesDataSource.sessionQueuePollingManager != nil &&
    _chatMessagesDataSource.sessionQueuePollingManager.isPollingStarted &&
    !_chatMessagesDataSource.sessionQueuePollingManager.isPollingCanceled;
    if (isVolumeControlPollingActive) {
        KUSSessionQueue *sessionQueue = [_chatMessagesDataSource.sessionQueuePollingManager sessionQueue];
        _waitingMessage = [KUSDate volumeControlExpectedWaitTimeMessageForSeconds:sessionQueue.estimatedWaitTimeSeconds];
    }
    
    [self _updateTextLabels];
    [self _updateBackButtonBadge];
}

- (void)setShowsLabels:(BOOL)showsLabels
{
    _showsLabels = showsLabels;
    [self setNeedsLayout];
}

- (void)setShowsBackButton:(BOOL)showsBackButton
{
    _showsBackButton = showsBackButton;
    _backButton.hidden = !_showsBackButton;
}

- (void)setShowsDismissButton:(BOOL)showsDismissButton
{
    _showsDismissButton = showsDismissButton;
    _dismissButton.hidden = !_showsDismissButton;
}

#pragma mark - KUSObjectDataSourceListener

- (void)objectDataSourceDidLoad:(KUSObjectDataSource *)dataSource
{
    [self _updateTextLabels];
}

#pragma mark - KUSPaginatedDataSourceListener methods

- (void)paginatedDataSourceDidChangeContent:(KUSPaginatedDataSource *)dataSource
{
    if (dataSource == _chatMessagesDataSource) {
        [_avatarsView setUserIds:_chatMessagesDataSource.otherUserIds];
        [self _updateTextLabels];
    } else if (dataSource == _userSession.chatSessionsDataSource) {
        [self _updateBackButtonBadge];
    }
}

#pragma mark - KUSPaginatedDataSourceListener methods
- (void)sessionQueuePollingManager:(KUSSessionQueuePollingManager *)manager didUpdateSessionQueue:(KUSSessionQueue *)sessionQueue
{
    _waitingMessage = [KUSDate volumeControlExpectedWaitTimeMessageForSeconds:sessionQueue.estimatedWaitTimeSeconds];
    [self _updateTextLabels];
}

- (void)sessionQueuePollingManagerDidCancelPolling:(KUSSessionQueuePollingManager *)manager
{
    _waitingMessage = nil;
    [self _updateTextLabels];
}

#pragma mark - UIAppearance methods

- (void)setNameColor:(UIColor *)nameColor
{
    _nameColor = nameColor;
    _nameLabel.textColor = _nameColor;
}

- (void)setGreetingColor:(UIColor *)greetingColor
{
    _greetingColor = greetingColor;
    _greetingLabel.textColor = _greetingColor;
}

- (void)setWaitingColor:(UIColor *)waitingColor
{
    _waitingColor = waitingColor;
    _waitingLabel.textColor = _waitingColor;
}

- (void)setSeparatorColor:(UIColor *)separatorColor
{
    _separatorColor = separatorColor;
    _separatorView.backgroundColor = _separatorColor;
}

- (void)setBackButtonImage:(UIImage *)backButtonImage
{
    _backButtonImage = backButtonImage;
    [_backButton setImage:backButtonImage forState:UIControlStateNormal];
}

- (void)setDismissButtonImage:(UIImage *)dismissButtonImage
{
    _dismissButtonImage = dismissButtonImage;
    [_dismissButton setImage:dismissButtonImage forState:UIControlStateNormal];
}

- (void)setUnreadColor:(UIColor *)unreadColor
{
    _unreadColor = unreadColor;
    _unreadCountLabel.textColor = [UIColor whiteColor];
}

- (void)setUnreadBackgroundColor:(UIColor *)unreadBackgroundColor
{
    _unreadBackgroundColor = unreadBackgroundColor;
    _unreadCountLabel.layer.backgroundColor = _unreadBackgroundColor.CGColor;
}

- (void)setUnreadFont:(UIFont *)unreadFont
{
    _unreadFont = unreadFont;
    _unreadCountLabel.font = _unreadFont;
}

@end
