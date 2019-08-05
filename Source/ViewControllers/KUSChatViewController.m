//
//  KUSChatViewController.m
//  Kustomer
//
//  Created by Daniel Amitay on 7/16/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSChatViewController.h"

#import "NYTPhotoViewer/NYTPhotoViewerArrayDataSource.h"
#import <NYTPhotoViewer/NYTPhotosViewController.h>
#import <SafariServices/SafariServices.h>
#import <SDWebImage/UIImageView+WebCache.h>
#import "KUSChatMessagesDataSource_Private.h"
#import "KUSChatSession.h"
#import "KUSUserSession.h"

#import "KUSColor.h"
#import "KUSChatTableView.h"
#import "KUSAvatarImageView.h"
#import "KUSChatMessagesDataSource.h"
#import "KUSChatMessageTableViewCell.h"
#import "KUSEmailInputView.h"
#import "KUSImage.h"
#import "KUSInputBar.h"
#import "KUSLog.h"
#import "KUSOptionPickerView.h"
#import "KUSTeamsDataSource.h"
#import "KUSText.h"
#import "KUSPermissions.h"
#import "KUSNavigationBarView.h"
#import "KUSNYTChatMessagePhoto.h"
#import "KUSNYTImagePhoto.h"
#import "KUSClosedChatView.h"
#import "KUSEndChatButtonView.h"
#import "KUSChatEndedTableViewCell.h"
#import "KUSMLFormValuesPickerView.h"
#import "KUSNewSessionButton.h"
#import "KUSObjectDataSource.h"
#import "KUSSatisfactionFormTableViewCell.h"
#import "KUSEditFeedbackTableViewCell.h"
#import "KUSPushClient.h"
#import "KUSTypingIndicatorTableViewCell.h"
#import "KUSTypingIndicator.h"
#import "KUSTimer.h"

@interface KUSChatViewController () <KUSEmailInputViewDelegate, KUSInputBarDelegate, KUSOptionPickerViewDelegate,
                                     KUSChatMessagesDataSourceListener, KUSChatMessageTableViewCellDelegate,
                                     NYTPhotosViewControllerDelegate, UITableViewDataSource, UITableViewDelegate,
                                     UINavigationControllerDelegate, UIImagePickerControllerDelegate,
                                     KUSNavigationBarViewDelegate,KUSCloseChatButtonViewDelegate,
                                     KUSMLFormValuesPickerViewDelegate,
                                     KUSObjectDataSourceListener,KUSSatisfactionFormTableViewCellDelegate,
                                     KUSEditFeedbackTableViewCellDelegate> {
    KUSUserSession *_userSession;

    BOOL _showBackButton;
    BOOL _showNonBusinessHoursImage;
    NSString *_chatSessionId;
    KUSChatMessagesDataSource *_chatMessagesDataSource;
    KUSTypingIndicator *_typingIndicator;

    KUSTeamsDataSource *_teamOptionsDataSource;
    BOOL _showSatisfactionForm;
    CGFloat _keyboardHeight;
    BOOL satisfactionFormEditButtonPressed;
}

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIImageView *nonBusinessHourImageView;
@property (nonatomic, strong) KUSEmailInputView *emailInputView;
@property (nonatomic, strong) KUSInputBar *inputBarView;
@property (nonatomic, strong) KUSOptionPickerView *optionPickerView;
@property (nonatomic, strong) KUSNavigationBarView *fauxNavigationBar;
@property (nonatomic, strong) KUSClosedChatView *closedChatView;
@property (nonatomic, strong) KUSNewSessionButton *sessionButton;
@property (nonatomic, strong) KUSEndChatButtonView *closeChatButtonView;
@property (nonatomic, strong) KUSMLFormValuesPickerView *mlFormValuesPickerView;
@property (nonatomic, strong) NYTPhotoViewerArrayDataSource *nytPhotosDataSource;


@end

@implementation KUSChatViewController

#pragma mark - Lifecycle methods

- (instancetype)initWithUserSession:(KUSUserSession *)userSession forChatSession:(KUSChatSession *)session
{
    self = [super init];
    if (self) {
        _userSession = userSession;
        _chatSessionId = session.oid;
        _chatMessagesDataSource = [_userSession chatMessagesDataSourceForSessionId:_chatSessionId];
        [_chatMessagesDataSource mayGetSatisfactionFormIfAgentJoined];
        _showSatisfactionForm = [_chatMessagesDataSource shouldShowSatisfactionForm];
        KUSChatSettings *chatSettings = [[_userSession chatSettingsDataSource] object];
        _showBackButton = !chatSettings.noHistory;
    }
    return self;
}

- (instancetype)initWithUserSession:(KUSUserSession *)userSession forNewSessionWithBackButton:(BOOL)showBackButton
{
    self = [super init];
    if (self) {
        _userSession = userSession;
        _chatMessagesDataSource = [[KUSChatMessagesDataSource alloc] initForNewConversationWithUserSession:userSession formId:nil];
        _showBackButton = showBackButton;
        _showNonBusinessHoursImage = ![_userSession.scheduleDataSource isActiveBusinessHours];
    }
    return self;
}

- (instancetype)initWithUserSession:(KUSUserSession *)userSession forNewSessionWithMessage:(NSString *)message andFormId:(NSString *)formId
{
    self = [super init];
    if (self) {
        _userSession = userSession;
        _chatMessagesDataSource = [[KUSChatMessagesDataSource alloc] initForNewConversationWithUserSession:userSession formId:formId];
        _showBackButton = NO;
        [_chatMessagesDataSource sendMessageWithText:message attachments:nil];
        [_userSession.chatSessionsDataSource setMessageToCreateNewChatSession:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UIViewController methods

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];
    self.edgesForExtendedLayout = UIRectEdgeTop;

    self.tableView = [[KUSChatTableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
    self.tableView.scrollsToTop = YES;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.transform = CGAffineTransformMakeScale(1.0, -1.0);
    [self.view addSubview:self.tableView];

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 110000
    if (@available(ios 11.0, *)) {
        self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    } else {
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
#else
    self.automaticallyAdjustsScrollViewInsets = NO;
#endif
    
    KUSChatSettings *chatSettings = _userSession.chatSettingsDataSource.object;
    self.nonBusinessHourImageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    self.nonBusinessHourImageView.contentMode = UIViewContentModeScaleAspectFit;
    if (chatSettings.offhoursImageUrl && ![chatSettings.offhoursImageUrl isEqualToString:@""]) {
        NSURL *imageUrl = [[NSURL alloc] initWithString:chatSettings.offhoursImageUrl];
        [self.nonBusinessHourImageView sd_setImageWithURL:imageUrl];
    }
    else {
        self.nonBusinessHourImageView.image = [KUSImage awayImage];
    }
    self.nonBusinessHourImageView.hidden = !_showNonBusinessHoursImage;
    [self.view addSubview:self.nonBusinessHourImageView];
    
    self.navigationController.interactivePopGestureRecognizer.enabled = _showBackButton;
    self.fauxNavigationBar = [[KUSNavigationBarView alloc] initWithUserSession:_userSession];
    self.fauxNavigationBar.delegate = self;
    [self.fauxNavigationBar setSessionId:_chatSessionId];
    [self.fauxNavigationBar setShowsLabels:YES];
    [self.fauxNavigationBar setShowsBackButton:_showBackButton];
    [self.fauxNavigationBar setShowsDismissButton:YES];
    [self.view addSubview:self.fauxNavigationBar];

    self.inputBarView = [[KUSInputBar alloc] initWithUserSession:_userSession];
    self.inputBarView.delegate = self;
    self.inputBarView.autoresizingMask = (UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth);
    
    self.inputBarView.allowsAttachments = [_chatMessagesDataSource shouldAllowAttachments];
    [self.view addSubview:self.inputBarView];

    [_chatMessagesDataSource addListener:self];
    [_chatMessagesDataSource fetchLatest];
    if (!_chatMessagesDataSource.didFetch) {
        [self showLoadingIndicator];
    }

    NSArray<NSString *> *keyboardNotificationNames = @[
        UIKeyboardWillShowNotification,
        UIKeyboardWillChangeFrameNotification,
        UIKeyboardWillHideNotification,
        UIKeyboardDidChangeFrameNotification
    ];
    for (NSString *notificationName in keyboardNotificationNames) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillChangeFrame:)
                                                     name:notificationName
                                                   object:nil];
    }

    [self _checkShouldShowEmailInput];
    [self _checkShouldUpdateInputView];
    [self _checkShouldShowCloseChatButtonView];

    // Force layout so that animated presentations start from the right state
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [_inputBarView setNeedsLayout];
    [self.view setNeedsLayout];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    // Only bring up the keyboard if the chat is being presented/pushed
    if (self.isBeingPresented || self.isMovingToParentViewController) {
        if (!_inputBarView.hidden && !_showNonBusinessHoursImage) {
            [_inputBarView becomeFirstResponder];
        }
    }

    [_userSession.chatSessionsDataSource updateLastSeenAtForSessionId:_chatSessionId completion:nil];
    [_chatMessagesDataSource startListeningForTypingUpdate];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    [_inputBarView resignFirstResponder];

    [_userSession.chatSessionsDataSource updateLastSeenAtForSessionId:_chatSessionId completion:nil];
    [_chatMessagesDataSource stopListeningForTypingUpdate];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];

    [self.fauxNavigationBar setExtraLarge:_chatMessagesDataSource.count == 0];
    self.fauxNavigationBar.topInset = self.edgeInsets.top;
    CGFloat navigationBarHeight = [self.fauxNavigationBar desiredHeight];

    CGFloat inputBarHeight = [self.inputBarView desiredHeight];
    CGFloat inputBarY = self.view.bounds.size.height - MAX(self.edgeInsets.bottom, _keyboardHeight) - inputBarHeight;
    self.inputBarView.frame = (CGRect) {
        .origin.y = inputBarY,
        .size.width = self.view.bounds.size.width,
        .size.height = inputBarHeight
    };

    CGFloat optionPickerHeight = [self.optionPickerView desiredHeight];
    CGFloat optionPickerY = self.view.bounds.size.height - MAX(self.edgeInsets.bottom, _keyboardHeight) - optionPickerHeight;
    self.optionPickerView.frame = (CGRect) {
        .origin.y = optionPickerY,
        .size.width = self.view.bounds.size.width,
        .size.height = optionPickerHeight
    };
    
    CGFloat mlFormValuesViewHeight = [self.mlFormValuesPickerView desiredHeight];
    CGFloat mlFormValuesViewY = self.view.bounds.size.height - MAX(self.edgeInsets.bottom, _keyboardHeight) - mlFormValuesViewHeight;
    self.mlFormValuesPickerView.frame = (CGRect) {
        .origin.y = mlFormValuesViewY,
        .size.width = self.view.bounds.size.width,
        .size.height = mlFormValuesViewHeight
    };
    
    CGFloat closedChatViewHeight = 50.0;
    CGFloat closedChatViewY = self.view.bounds.size.height - MAX(self.edgeInsets.bottom, _keyboardHeight) - closedChatViewHeight;
    self.closedChatView.frame = (CGRect) {
        .origin.y = closedChatViewY,
        .size.width = self.view.bounds.size.width,
        .size.height = closedChatViewHeight
    };
    
    self.sessionButton.frame = (CGRect) {
        .origin.y = self.view.bounds.size.height - MAX(self.edgeInsets.bottom, _keyboardHeight) - 50.0,
        .size.width = self.view.bounds.size.width,
        .size.height = 50.0
    };

    self.fauxNavigationBar.frame = (CGRect) {
        .size.width = self.view.bounds.size.width,
        .size.height = navigationBarHeight
    };

    // Hide the email input view in landscape to save space on iPhones
    BOOL isIphone = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone;
    BOOL isLandscape = UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation);
    CGFloat emailInputHeight = (isIphone && isLandscape ? 0.0 : 80.0);
    self.emailInputView.frame = (CGRect) {
        .origin.y = self.fauxNavigationBar.frame.size.height,
        .size.width = self.view.bounds.size.width,
        .size.height = emailInputHeight
    };

    self.closeChatButtonView.frame = (CGRect) {
        .origin.y = self.fauxNavigationBar.frame.size.height,
        .size.width = self.view.bounds.size.width,
        .size.height = 46
    };
    
    // Update table view frame if "Start New Conversation" is hidden
    KUSChatSession *session = [_userSession.chatSessionsDataSource objectWithId:[self getValidChatSessionId]];
    BOOL shouldHideStartNewConversation = session.lockedAt && _userSession.userDefaults.shouldHideNewConversationButtonInClosedChat;
    
    self.tableView.frame = (CGRect) {
        .size.width = self.view.bounds.size.width,
        .size.height = shouldHideStartNewConversation ? self.view.frame.size.height : MIN(inputBarY, MIN(optionPickerY, mlFormValuesViewY))
    };

    self.tableView.contentInset = (UIEdgeInsets) {
        .top = 4.0,
        .bottom = navigationBarHeight + MAX(self.emailInputView.frame.size.height, self.closeChatButtonView.frame.size.height) + 4.0
    };
    self.tableView.scrollIndicatorInsets = (UIEdgeInsets) {
        .bottom = navigationBarHeight + self.emailInputView.frame.size.height
    };
    
    CGFloat nonBusinessHourImagePadding = 50;
    self.nonBusinessHourImageView.frame = (CGRect) {
        .origin.x = nonBusinessHourImagePadding,
        .origin.y = self.fauxNavigationBar.frame.size.height + nonBusinessHourImagePadding,
        .size.width = self.view.bounds.size.width - (nonBusinessHourImagePadding * 2),
        .size.height = self.view.bounds.size.height - self.fauxNavigationBar.frame.size.height - 50 - (nonBusinessHourImagePadding * 2)
    };
}

#pragma mark - Internal logic methods

- (NSString *)getValidChatSessionId
{
    return [_chatSessionId isEqual:kKUSTempSessionId] ? nil : _chatSessionId;
}

- (void)_checkShouldShowCloseChatButtonView
{
    KUSChatSettings *settings = [_userSession.chatSettingsDataSource object];
    if (settings != nil && settings.closableChat) {
        if ([self getValidChatSessionId]) {
            KUSChatSession *session = [_userSession.chatSessionsDataSource objectWithId:[self getValidChatSessionId]];
            if (!session.lockedAt) {
                if ([_chatMessagesDataSource isAnyMessageByCurrentUser]) {
                    if (!self.closeChatButtonView) {
                        self.closeChatButtonView = [[KUSEndChatButtonView alloc] init];
                        self.closeChatButtonView.delegate = self;
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                            [self.view addSubview:self.closeChatButtonView];
                            [self.view setNeedsLayout];
                        });
                    }
                    return;
                }
            }
        }
    }
    
    [self.closeChatButtonView removeFromSuperview];
    self.closeChatButtonView = nil;
    [self.view setNeedsLayout];
}

- (void)_checkShouldShowEmailInput
{
    KUSChatSettings *settings = [_userSession.chatSettingsDataSource object];
    BOOL isChatCloseable = settings != nil && settings.closableChat;
    BOOL shouldShowEmailInput = [_userSession shouldCaptureEmail] &&
                                [self getValidChatSessionId] != nil &&
                                !isChatCloseable;
    if (shouldShowEmailInput) {
        if (self.emailInputView == nil) {
            self.emailInputView = [[KUSEmailInputView alloc] init];
            self.emailInputView.delegate = self;
            [self.view addSubview:self.emailInputView];
            [self.view setNeedsLayout];
        }
    } else {
        [self.emailInputView removeFromSuperview];
        self.emailInputView = nil;
        [self.view setNeedsLayout];
    }
}

- (void)_showMLFormValuePickerWithValue:(KUSMLFormValue *)mlFormValue
{
    [self.optionPickerView removeFromSuperview];
    self.optionPickerView = nil;
    
    [self.closedChatView removeFromSuperview];
    self.closedChatView = nil;
    
    self.inputBarView.hidden = YES;
    if ([self.inputBarView isFirstResponder]) {
        [self.inputBarView resignFirstResponder];
    }
    
    if (self.mlFormValuesPickerView == nil) {
        self.mlFormValuesPickerView = [[KUSMLFormValuesPickerView alloc] init];
        self.mlFormValuesPickerView.delegate = self;
        self.mlFormValuesPickerView.autoresizingMask = (UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth);
        [self.view addSubview:self.mlFormValuesPickerView];
        [self.mlFormValuesPickerView setMLFormValuesPicker:mlFormValue.mlNodes with:mlFormValue.lastNodeRequired];
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    }
}

- (void)_showOptionPickerView
{
    [self.closedChatView removeFromSuperview];
    self.closedChatView = nil;
    
    [self.mlFormValuesPickerView removeFromSuperview];
    self.mlFormValuesPickerView = nil;
    
    self.inputBarView.hidden = YES;
    if ([self.inputBarView isFirstResponder]) {
        [self.inputBarView resignFirstResponder];
    }
    
    if (self.optionPickerView == nil) {
        self.optionPickerView = [[KUSOptionPickerView alloc] init];
        self.optionPickerView.autoresizingMask = (UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth);
        self.optionPickerView.delegate = self;
        [self.view addSubview:self.optionPickerView];
        
        [self _updateOptionsPickerOptions];
    }
    
}


- (void)_showSessionButton
{
    self.inputBarView.hidden = YES;
    if ([self.inputBarView isFirstResponder]) {
        [self.inputBarView resignFirstResponder];
    }
    
    [self.optionPickerView removeFromSuperview];
    self.optionPickerView = nil;
    
    [self.closedChatView removeFromSuperview];
    self.closedChatView = nil;
    
    [self.mlFormValuesPickerView removeFromSuperview];
    self.mlFormValuesPickerView = nil;
    
    if (_userSession.userDefaults.shouldHideNewConversationButtonInClosedChat) {
        if (self.sessionButton != nil) {
            [self.sessionButton removeFromSuperview];
            self.sessionButton = nil;
        }
        [self.view setNeedsLayout];
    }
    else {
        if (self.sessionButton == nil) {
            
            self.sessionButton = [[KUSNewSessionButton alloc] initWithUserSession:_userSession];
            [self.sessionButton setTextColor:[KUSColor blueColor]];
            [self.sessionButton setBackgroundColor:[UIColor whiteColor]];
            [self.sessionButton setColor:nil];
            [self.sessionButton setHasShadow:NO];
            [self.sessionButton setText:[[KUSLocalization sharedInstance] localizedString:@"Start a New Conversation"]];
            [self.sessionButton setImage:[KUSImage noImage]];
            [self.sessionButton setTextFont:[UIFont boldSystemFontOfSize:14.0]];
            [self.sessionButton setTitleColor:[[KUSColor blueColor] colorWithAlphaComponent:0.5] forState:UIControlStateHighlighted];
            
            self.sessionButton.autoresizingMask = (UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth);
            [self.sessionButton addTarget:self
                                   action:@selector(_createSession)
                         forControlEvents:UIControlEventTouchUpInside];
            [self.view addSubview:self.sessionButton];
            [self.view setNeedsLayout];
        }
    }
}

- (void)_showClosedChatView
{
    self.inputBarView.hidden = YES;
    if ([self.inputBarView isFirstResponder]) {
        [self.inputBarView resignFirstResponder];
    }
    
    [self.optionPickerView removeFromSuperview];
    self.optionPickerView = nil;
    
    [self.mlFormValuesPickerView removeFromSuperview];
    self.mlFormValuesPickerView = nil;
    
    if (self.closedChatView == nil) {
        self.closedChatView = [[KUSClosedChatView alloc] init];
        self.closedChatView.autoresizingMask = (UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth);
        [self.view addSubview:self.closedChatView];
        [self.view setNeedsLayout];
    }
}

- (void)_checkShouldUpdateInputView
{
    KUSChatSession *session = [_userSession.chatSessionsDataSource objectWithId:[self getValidChatSessionId]];
    BOOL isSessionLocked = session.lockedAt != nil;
    if (isSessionLocked) {
        [self _showSessionButton];
        return;
    }
    
    BOOL wantsClosedView = _chatMessagesDataSource.isChatClosed && ([_chatMessagesDataSource otherUserIds].count == 0);
    if (wantsClosedView) {
        [self _showClosedChatView];
        return;
    }
    
    if ([self _isCurrentFormQuestionInserted]) {
        KUSFormQuestion *vcCurrentQuestion = _chatMessagesDataSource.volumeControlCurrentQuestion;
        KUSFormQuestion *currentQuestion = _chatMessagesDataSource.currentQuestion;
        
        BOOL isFollowupChannelQuestion = (vcCurrentQuestion
                                            && vcCurrentQuestion.property == KUSFormQuestionPropertyFollowupChannel
                                            && vcCurrentQuestion.values.count > 0);
        BOOL isPropertyValueQuestion = (currentQuestion
                                            && currentQuestion.property == KUSFormQuestionPropertyValues
                                            && currentQuestion.values.count > 0);
        BOOL isConversationTeamQuestion = (currentQuestion
                                               && currentQuestion.property == KUSFormQuestionPropertyConversationTeam
                                               && currentQuestion.values.count > 0);
        
        BOOL teamOptionsDidFail = NO;
        if (isConversationTeamQuestion) {
            teamOptionsDidFail = _teamOptionsDataSource.error || (_teamOptionsDataSource.didFetch
                                                                  && _teamOptionsDataSource.count == 0);
            if (!teamOptionsDidFail) {
                NSArray<NSString *> *teamIds = currentQuestion.values;
                if (_teamOptionsDataSource == nil || ![_teamOptionsDataSource.teamIds isEqual:teamIds]) {
                    _teamOptionsDataSource = [[KUSTeamsDataSource alloc] initWithUserSession:_userSession teamIds:teamIds];
                    [_teamOptionsDataSource addListener:self];
                    [_teamOptionsDataSource fetchLatest];
                }
            }
        }
        
        BOOL wantsOptionPicker = isFollowupChannelQuestion
                                    || isPropertyValueQuestion
                                    || (isConversationTeamQuestion && !teamOptionsDidFail);
        if (wantsOptionPicker) {
            [self _showOptionPickerView];
            return;
        }
        
        BOOL isMLVPropertyFormQuestion = (currentQuestion
                                          && currentQuestion.property == KUSFormQuestionPropertyMLV);
        BOOL hasMLFormValues = currentQuestion.mlFormValues
                                && currentQuestion.mlFormValues.mlNodes
                                && currentQuestion.mlFormValues.mlNodes.count > 0;
        BOOL wantsMultiLevelValuesPicker = isMLVPropertyFormQuestion && hasMLFormValues;
        
        if (wantsMultiLevelValuesPicker) {
            [self _showMLFormValuePickerWithValue: currentQuestion.mlFormValues];
            return;
        }
        
    }
    
    _teamOptionsDataSource = nil;
    
    self.inputBarView.hidden = NO;
    [self inputBarShouldEnableSend:self.inputBarView];
    
    [self.optionPickerView removeFromSuperview];
    self.optionPickerView = nil;
    
    [self.closedChatView removeFromSuperview];
    self.closedChatView = nil;
    
    [self.mlFormValuesPickerView removeFromSuperview];
    self.mlFormValuesPickerView = nil;
    
    [self.view setNeedsLayout];
}

- (void)_checkShouldDisconnectTypingListener
{
    NSString *sessionId = [self getValidChatSessionId];
    if (!sessionId) {
        return;
    }
    
    KUSChatSession *session = [_userSession.chatSessionsDataSource objectWithId:sessionId];
    
    BOOL isSessionLocked = session && session.lockedAt;
    if (isSessionLocked) {
        [_chatMessagesDataSource stopListeningForTypingUpdate];
    }
}

- (void)_updateOptionsPickerOptions
{
    KUSFormQuestion *vcCurrentQuestion = _chatMessagesDataSource.volumeControlCurrentQuestion;
    BOOL wantsOptionPicker = (vcCurrentQuestion
                              && vcCurrentQuestion.property == KUSFormQuestionPropertyFollowupChannel
                              && vcCurrentQuestion.values.count > 0);
    if (wantsOptionPicker) {
        [self.optionPickerView setOptions:vcCurrentQuestion.values];
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
        
        return;
    }
    
    KUSFormQuestion *currentQuestion = _chatMessagesDataSource.currentQuestion;
    wantsOptionPicker = (currentQuestion
                         && currentQuestion.property == KUSFormQuestionPropertyValues
                         && currentQuestion.values.count > 0);
    if (wantsOptionPicker) {
        [self.optionPickerView setOptions:currentQuestion.values];
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
        
        return;
    }
    
    NSMutableArray<NSString *> *options = [[NSMutableArray alloc] init];
    for (KUSTeam *team in _teamOptionsDataSource.allObjects) {
        [options addObject:team.fullDisplay];
    }
    [self.optionPickerView setOptions:options];

    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
}

- (void)_createSession
{
    [_chatMessagesDataSource removeListener:self];
    
    if ([self.sessionButton isBackToChat])
    {
        KUSChatSession *chatSession = [_userSession.chatSessionsDataSource mostRecentNonProactiveCampaignOpenSession];
        _chatSessionId = chatSession.oid;
        _chatMessagesDataSource = [_userSession chatMessagesDataSourceForSessionId:_chatSessionId];
    } else {
        _chatMessagesDataSource = [[KUSChatMessagesDataSource alloc] initForNewConversationWithUserSession:_userSession formId:nil];
        _chatSessionId = nil;
        self.inputBarView.allowsAttachments = NO;
        
        _showNonBusinessHoursImage = ![_userSession.scheduleDataSource isActiveBusinessHours];
        self.nonBusinessHourImageView.hidden = !_showNonBusinessHoursImage;
    }
    
    [_chatMessagesDataSource addListener:self];
    _showSatisfactionForm = [_chatMessagesDataSource shouldShowSatisfactionForm];
    [self.tableView reloadData];
    self.inputBarView.hidden = NO;
    [self.sessionButton removeFromSuperview];
    self.sessionButton = nil;
    
    [self.fauxNavigationBar setSessionId:_chatSessionId];
    [self _checkShouldShowEmailInput];
    [self _checkShouldShowCloseChatButtonView];
    [self _checkShouldUpdateInputView];
    
    [UIView animateWithDuration:0.2 animations:^{
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    }];
    
}

- (BOOL)_isCurrentFormQuestionInserted
{
    KUSChatMessage *latestMessage = _chatMessagesDataSource.allObjects.firstObject;
    KUSFormQuestion *vcCurrentQuestion = _chatMessagesDataSource.volumeControlCurrentQuestion;
    if (vcCurrentQuestion) {
        return [vcCurrentQuestion.oid isEqualToString:latestMessage.oid];
    }
    
    KUSFormQuestion *currentQuestion = _chatMessagesDataSource.currentQuestion;
    if (currentQuestion) {
        NSString *questionId = [NSString stringWithFormat:@"question_%@", currentQuestion.oid];
        return [questionId isEqualToString:latestMessage.oid];
    }
    
    return NO;
}

#pragma mark - KUSChatMessagesDataSourceListener methods

- (void)paginatedDataSourceDidLoad:(KUSPaginatedDataSource *)dataSource
{
    if (dataSource == _chatMessagesDataSource) {
        [self hideLoadingIndicator];
        [self _checkShouldShowCloseChatButtonView];
        
        [self.tableView reloadData];
        
        _showNonBusinessHoursImage = NO;
        self.nonBusinessHourImageView.hidden = !_showNonBusinessHoursImage;
    }
}

- (void)paginatedDataSourceDidChangeContent:(KUSPaginatedDataSource *)dataSource
{
    if (dataSource == _chatMessagesDataSource) {
        [self.tableView reloadData];
        [self _checkShouldUpdateInputView];
        [self _checkShouldShowCloseChatButtonView];
        [self _checkShouldDisconnectTypingListener];
        
        [self.view setNeedsLayout];
        BOOL shouldAllowAttachments = [_chatMessagesDataSource shouldAllowAttachments];
        if (!shouldAllowAttachments) {
            [_inputBarView setImageAttachments:nil];
        }
        self.inputBarView.allowsAttachments = shouldAllowAttachments;
        
        _showNonBusinessHoursImage = NO;
        self.nonBusinessHourImageView.hidden = !_showNonBusinessHoursImage;
        
    } else if (dataSource == _teamOptionsDataSource) {
        [self _checkShouldUpdateInputView];
        [self _updateOptionsPickerOptions];
    }
}

- (void)paginatedDataSource:(KUSPaginatedDataSource *)dataSource didReceiveError:(NSError *)error
{
    if (dataSource == _chatMessagesDataSource && !_chatMessagesDataSource.didFetch) {
        __weak KUSChatViewController *weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong KUSChatViewController *strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf->_chatMessagesDataSource fetchLatest];
            }
        });
    } else if (dataSource == _teamOptionsDataSource) {
        [self _checkShouldUpdateInputView];
    }
}

- (void)chatMessagesDataSource:(KUSChatMessagesDataSource *)dataSource didCreateSessionId:(NSString *)sessionId
{
    _chatSessionId = sessionId;
    self.inputBarView.allowsAttachments = [self getValidChatSessionId] != nil;
    [self.fauxNavigationBar setSessionId:_chatSessionId];
    
    KUSChatSettings *chatSettings = [[_userSession chatSettingsDataSource] object];
    _showBackButton = !chatSettings.noHistory;

    self.navigationController.interactivePopGestureRecognizer.enabled = _showBackButton;
    [self.fauxNavigationBar setShowsBackButton:_showBackButton];
    [self _checkShouldShowEmailInput];
    [self _checkShouldShowCloseChatButtonView];
    [_chatMessagesDataSource startListeningForTypingUpdate];
    
    [self.view setNeedsLayout];
}

- (void)chatMessagesDataSourceDidFetchSatisfactionForm:(KUSChatMessagesDataSource *)dataSource
{
    _showSatisfactionForm = [_chatMessagesDataSource shouldShowSatisfactionForm];
    [self.tableView reloadData];
}

- (void)chatMessagesDataSource:(KUSChatMessagesDataSource *)dataSource didReceiveTypingUpdate:(KUSTypingIndicator *)typingIndicator
{
    _typingIndicator = typingIndicator;
    [self.tableView reloadData];
}

- (void)chatMessagesDataSourceDidEndChatSession:(KUSChatMessagesDataSource *)dataSource
{
    if (dataSource == _chatMessagesDataSource) {
        [self.tableView reloadData];
        [self _checkShouldUpdateInputView];
        [self _checkShouldShowCloseChatButtonView];
        [self _checkShouldDisconnectTypingListener];
        [self.view setNeedsLayout];
    }
}

#pragma mark - NSNotification methods

- (void)keyboardWillChangeFrame:(NSNotification *)notification
{
    CGRect keyboardEndFrameWindow;
    [[notification.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue:&keyboardEndFrameWindow];

    double keyboardTransitionDuration;
    [[notification.userInfo valueForKey:UIKeyboardAnimationDurationUserInfoKey] getValue:&keyboardTransitionDuration];

    UIViewAnimationCurve keyboardTransitionAnimationCurve;
    [[notification.userInfo valueForKey:UIKeyboardAnimationCurveUserInfoKey] getValue:&keyboardTransitionAnimationCurve];

    CGRect keyboardEndFrameView = [self.view convertRect:keyboardEndFrameWindow fromView:nil];
    _keyboardHeight = self.view.frame.size.height - keyboardEndFrameView.origin.y;

    UIViewAnimationOptions options = keyboardTransitionAnimationCurve << 16 | UIViewAnimationOptionBeginFromCurrentState;

    BOOL shouldAnimate = keyboardTransitionDuration > 0.0 && self.optionPickerView == nil;
    if (shouldAnimate) {
        [UIView animateWithDuration:keyboardTransitionDuration
                              delay:0.0
                            options:options
                         animations:^{
                             [self.view setNeedsLayout];
                             [self.view layoutIfNeeded];
                         }
                         completion:nil];
    } else {
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    }
}


#pragma mark - UIScrollViewDelegate Methods

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView
{
    if (scrollView == self.tableView) {
        CGPoint offset = CGPointMake(0.0,
                                     scrollView.contentSize.height
                                     - scrollView.bounds.size.height
                                     + scrollView.contentInset.bottom);
        [scrollView setContentOffset:offset animated:YES];
    }
    return NO;
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    KUSChatSession *session = [_userSession.chatSessionsDataSource objectWithId:[self getValidChatSessionId]];
    if (session.lockedAt) {
        NSInteger satisfactionFormRowCount = _showSatisfactionForm ? 1 : 0;
        return [_chatMessagesDataSource count] + 1 + satisfactionFormRowCount;
    } else if (_typingIndicator && _typingIndicator.typingStatus == KUSTyping) {
        return [_chatMessagesDataSource count] + 1;
    }
    return [_chatMessagesDataSource count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    KUSChatSession *session = [_userSession.chatSessionsDataSource objectWithId:[self getValidChatSessionId]];
    BOOL shouldShowSatisfactionCell = _showSatisfactionForm && session.lockedAt && indexPath.row == 0;
    if (shouldShowSatisfactionCell) {
        KUSSatisfactionResponse *satisfactionResponse = (KUSSatisfactionResponse *)_chatMessagesDataSource.satisfactionResponseDataSource.object;
        
        KUSSatisfactionResponseStatus satisfactionStatus = [_chatMessagesDataSource.satisfactionResponseDataSource satisfactionFormCurrentStatus];
        BOOL isSatisfactionFormCell = satisfactionStatus != KUSSatisfactionResponseStatusCommented || satisfactionFormEditButtonPressed;
        
        if (isSatisfactionFormCell) {
            KUSSatisfactionFormTableViewCell *cell = (KUSSatisfactionFormTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"satisfactionFormCell"];
            if (cell == nil) {
                cell = [[KUSSatisfactionFormTableViewCell alloc] initWithReuseIdentifier:@"satisfactionFormCell" userSession:_userSession];
                cell.transform = tableView.transform;
                cell.delegate = self;
            }
            NSInteger selectedRating = satisfactionFormEditButtonPressed ? 0 : satisfactionResponse.rating;
            [cell setSatisfactionForm:satisfactionResponse.satisfactionForm rating:selectedRating];
            return cell;
        } else {
            KUSEditFeedbackTableViewCell *cell = (KUSEditFeedbackTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"editFeedbackCell"];
            if (cell == nil)
            {
                cell = [[KUSEditFeedbackTableViewCell alloc] initWithReuseIdentifier:@"editFeedbackCell" userSession:_userSession];
                cell.delegate = self;
                cell.transform = tableView.transform;
            }
            BOOL showEditButton = NO;
            if (satisfactionResponse.lockedAt) {
                showEditButton = [[NSDate date] compare:satisfactionResponse.lockedAt] == NSOrderedAscending;
            }
            [cell setEditButtonShow:showEditButton];
            return cell;
        }
    }
    NSInteger chatEndedCellAdjustedIndex = _showSatisfactionForm ? 1 : 0;
    BOOL isChatEndedCell = session.lockedAt && indexPath.row == chatEndedCellAdjustedIndex;
    if (isChatEndedCell) {
        KUSChatEndedTableViewCell *cell = (KUSChatEndedTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"chatEndedCell"];
        if (cell == nil) {
            cell = [[KUSChatEndedTableViewCell alloc] initWithReuseIdentifier:@"chatEndedCell"];
            cell.transform = tableView.transform;
        }
        return cell;
    }
    
    BOOL isTypingIndicatorCell = _typingIndicator && _typingIndicator.typingStatus == KUSTyping && indexPath.row == 0;
    if (isTypingIndicatorCell) {
        KUSTypingIndicatorTableViewCell *cell = (KUSTypingIndicatorTableViewCell *)[tableView dequeueReusableCellWithIdentifier:@"typingIndicatorCell"];
        if (cell == nil) {
            cell = [[KUSTypingIndicatorTableViewCell alloc] initWithReuseIdentifier:@"typingIndicatorCell" userSession:_userSession];
            [cell setTypingIndicator:_typingIndicator];
            cell.transform = tableView.transform;
        }
        return cell;
    }
    
    int adjustRowCount = 0;
    if (session.lockedAt) {
        adjustRowCount = -1;
        adjustRowCount += _showSatisfactionForm ? -1 : 0;
    }
    else if (_typingIndicator && _typingIndicator.typingStatus == KUSTyping) {
        adjustRowCount = -1;
    }

    KUSChatMessage *chatMessage = [self messageForRow:indexPath.row+adjustRowCount];
    KUSChatMessage *previousChatMessage = [self messageBeforeRow:indexPath.row+adjustRowCount];
    KUSChatMessage *nextChatMessage = [self messageAfterRow:indexPath.row+adjustRowCount];
    BOOL currentUser = KUSChatMessageSentByUser(chatMessage);

    NSString *messageCellIdentifier = (currentUser ? @"CurrentUserMessageCell" : @"OtherUserMessageCell");
    KUSChatMessageTableViewCell *cell = (KUSChatMessageTableViewCell *)[tableView dequeueReusableCellWithIdentifier:messageCellIdentifier];
    if (cell == nil) {
        cell = [[KUSChatMessageTableViewCell alloc] initWithReuseIdentifier:messageCellIdentifier userSession:_userSession];
        cell.transform = tableView.transform;
        cell.delegate = self;
    }

    [cell setChatMessage:chatMessage];

    BOOL previousMessageDiffSender = !KUSChatMessagesSameSender(previousChatMessage, chatMessage);
    BOOL nextMessageOlderThan5Min = nextChatMessage == nil || [nextChatMessage.createdAt timeIntervalSinceDate:chatMessage.createdAt] > 5.0 * 60.0;
    [cell setShowsAvatar:previousMessageDiffSender];
    [cell setShowsTimestamp:nextMessageOlderThan5Min];

    // Make sure that we've fetched all of the latest messages by loading the next page
    static NSUInteger kPrefetchPadding = 20;
    if (!_chatMessagesDataSource.didFetchAll && indexPath.row >= _chatMessagesDataSource.count - 1 - kPrefetchPadding) {
        [_chatMessagesDataSource fetchNext];
    }

    return cell;
}

#pragma mark - UITableViewDelegate methods

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    KUSChatSession *session = [_userSession.chatSessionsDataSource objectWithId:[self getValidChatSessionId]];
    BOOL shouldShowSatisfactionCell = _showSatisfactionForm &&
                                            session.lockedAt && indexPath.row == 0;
    if (shouldShowSatisfactionCell) {
        KUSSatisfactionResponse *satisfactionResponse = (KUSSatisfactionResponse *)_chatMessagesDataSource.satisfactionResponseDataSource.object;
        
        KUSSatisfactionResponseStatus satisfactionStatus = [_chatMessagesDataSource.satisfactionResponseDataSource satisfactionFormCurrentStatus];
        
        BOOL isSatisfactionFormWithRatingOnly = satisfactionStatus == KUSSatisfactionResponseStatusOffered || satisfactionFormEditButtonPressed;
        
        BOOL isSatisfactionFormWithComment = satisfactionStatus == KUSSatisfactionResponseStatusRated;
        
        if (isSatisfactionFormWithRatingOnly) {
            CGFloat formHeight = [KUSSatisfactionFormTableViewCell
                                  heightForSatisfactionForm:satisfactionResponse.satisfactionForm ratingOnly:YES
                                  maxWidth:tableView.bounds.size.width];
            return formHeight;
            
        } else if (isSatisfactionFormWithComment) {
            CGFloat formHeight = [KUSSatisfactionFormTableViewCell
                                  heightForSatisfactionForm:satisfactionResponse.satisfactionForm ratingOnly:NO
                                  maxWidth:tableView.bounds.size.width];
            return formHeight;
            
        } else {
            BOOL showEditButton = NO;
            if (satisfactionResponse.lockedAt) {
                showEditButton = [[NSDate date] compare:satisfactionResponse.lockedAt] == NSOrderedAscending;
            }
            CGFloat feedbackCellHeight = [KUSEditFeedbackTableViewCell heightForEditFeedbackCellWithEditButton:showEditButton maxWidth:tableView.bounds.size.width];
            return feedbackCellHeight;
        }
    
    }
    NSInteger chatEndedCellAdjustedIndex = _showSatisfactionForm ? 1 : 0;
    BOOL isChatEndedCell = session.lockedAt && indexPath.row == chatEndedCellAdjustedIndex;
    if (isChatEndedCell) {
        return 50;
    }
    
    BOOL isTypingIndicatorCell = _typingIndicator && _typingIndicator.typingStatus == KUSTyping && indexPath.row == 0;
    if (isTypingIndicatorCell) {
        return [KUSTypingIndicatorTableViewCell heightForBubble];
    }

    int adjustRowCount = 0;
    if (session.lockedAt) {
        adjustRowCount = -1;
        adjustRowCount += _showSatisfactionForm ? -1 : 0;
    }
    else if (_typingIndicator && _typingIndicator.typingStatus == KUSTyping) {
        adjustRowCount = -1;
    }

    KUSChatMessage *chatMessage = [self messageForRow:indexPath.row+adjustRowCount];
    KUSChatMessage *nextChatMessage = [self messageAfterRow:indexPath.row+adjustRowCount];
    BOOL nextMessageOlderThan5Min = nextChatMessage == nil || [nextChatMessage.createdAt timeIntervalSinceDate:chatMessage.createdAt] > 5.0 * 60.0;
    CGFloat messageHeight = [KUSChatMessageTableViewCell heightForChatMessage:chatMessage maxWidth:tableView.bounds.size.width];
    if (nextMessageOlderThan5Min) {
        return messageHeight + [KUSChatMessageTableViewCell heightForTimestamp];
    } else {
        return messageHeight;
    }
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

#pragma mark - UITableView high-level helpers

- (KUSChatMessage *)messageForRow:(NSInteger)row
{
    return [_chatMessagesDataSource objectAtIndex:row];
}

- (KUSChatMessage *)messageBeforeRow:(NSInteger)row
{
    if (row < [_chatMessagesDataSource count] - 1 && row >= 0) {
        return [self messageForRow:row + 1];
    } else {
        return nil;
    }
}

- (KUSChatMessage *)messageAfterRow:(NSInteger)row
{
    if (row > 0 && row < [_chatMessagesDataSource count]) {
        return [self messageForRow:row - 1];
    } else {
        return nil;
    }
}

#pragma mark - KUSChatMessageTableViewCellDelegate methods

- (void)chatMessageTableViewCell:(KUSChatMessageTableViewCell *)cell didTapLink:(NSURL *)URL
{
    if ([URL.scheme isEqualToString:@"http"] || [URL.scheme isEqualToString:@"https"]) {
        SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:URL];
        [self presentViewController:safariViewController animated:YES completion:nil];
    } else {
        [[UIApplication sharedApplication] openURL:URL];
    }
}

- (void)chatMessageTableViewCellDidTapError:(KUSChatMessageTableViewCell *)cell forMessage:(KUSChatMessage *)message
{
    [_chatMessagesDataSource resendMessage:message];
}

- (void)chatMessageTableViewCellDidTapImage:(KUSChatMessageTableViewCell *)cell forMessage:(KUSChatMessage *)message
{
    id<NYTPhoto> initialPhoto = nil;
    NSMutableArray<id<NYTPhoto>> *photos = [[NSMutableArray alloc] init];

    for (KUSChatMessage *chatMessage in [_chatMessagesDataSource.allObjects reverseObjectEnumerator]) {
        if (chatMessage.type == KUSChatMessageTypeImage) {
            KUSNYTChatMessagePhoto *messagePhoto = [[KUSNYTChatMessagePhoto alloc] initWithChatMessage:chatMessage];
            [photos addObject:messagePhoto];

            if ([chatMessage.oid isEqualToString:message.oid]) {
                initialPhoto = messagePhoto;
            }
        }
    }

    [_inputBarView resignFirstResponder];
    _nytPhotosDataSource = [[NYTPhotoViewerArrayDataSource alloc] initWithPhotos:photos];
    NYTPhotosViewController *photosViewController = [[NYTPhotosViewController alloc] initWithDataSource:_nytPhotosDataSource initialPhoto:initialPhoto delegate:self];
    [self presentViewController:photosViewController animated:YES completion:nil];
}

#pragma mark - KUSNavigationBarViewDelegate methods

- (void)navigationBarViewDidTapBack:(KUSNavigationBarView *)navigationBarView
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)navigationBarViewDidTapDismiss:(KUSNavigationBarView *)navigationBarView
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - KUSEmailInputViewDelegate methods

- (void)emailInputView:(KUSEmailInputView *)inputView didSubmitEmail:(NSString *)email
{
    [_userSession submitEmail:email];
    [self _checkShouldShowEmailInput];
}

#pragma mark - KUSOptionPickerViewDelegate methods

- (void)optionPickerView:(KUSOptionPickerView *)pickerView didSelectOption:(NSString *)option
{
    KUSTeam *team = nil;
    NSUInteger optionIndex = [pickerView.options indexOfObject:option];
    KUSFormQuestion *currentQuestion = _chatMessagesDataSource.currentQuestion;
    if (optionIndex != NSNotFound && currentQuestion.property == KUSFormQuestionPropertyConversationTeam && optionIndex < _teamOptionsDataSource.count) {
        team = [_teamOptionsDataSource objectAtIndex:optionIndex];
    }
    [_chatMessagesDataSource sendMessageWithText:team.displayName ?: option attachments:nil value: team.oid] ;
}

#pragma mark - KUSInputBarDelegate methods

- (BOOL)inputBarShouldEnableSend:(KUSInputBar *)inputBar
{
    KUSFormQuestion *question = _chatMessagesDataSource.volumeControlCurrentQuestion;
    if (!question) {
        question = _chatMessagesDataSource.currentQuestion;
        if (question && !KUSFormQuestionRequiresResponse(question)) {
            return NO;
        }
    }
    
    if (question && question.property == KUSFormQuestionPropertyCustomerEmail) {
        return [KUSText isValidEmail:inputBar.text];
    } else if (question && question.property == KUSFormQuestionPropertyCustomerPhone) {
        return [KUSText isValidPhone:inputBar.text];
    }
    
    return YES;
}

- (void)inputBarDidPressSend:(KUSInputBar *)inputBar
{
    // Disallow message sending while autoreply/form messages are being delayed
    if ([_chatMessagesDataSource shouldPreventSendingMessage]) {
        return;
    }

    [_chatMessagesDataSource sendTypingStatusToPusher:KUSTypingEnded];
    [_chatMessagesDataSource sendMessageWithText:inputBar.text attachments:inputBar.imageAttachments];
    [_inputBarView setText:nil];
    [_inputBarView setImageAttachments:nil];
}

- (void)inputBarDidTapAttachment:(KUSInputBar *)inputBar
{
    [self.view endEditing:YES];

    UIAlertController *actionController = [UIAlertController alertControllerWithTitle:nil
                                                                              message:nil
                                                                       preferredStyle:UIAlertControllerStyleActionSheet];

    if ([KUSPermissions cameraAccessIsAvailable]) {
        
        UIAlertAction *cameraAction = [UIAlertAction actionWithTitle:[[KUSLocalization sharedInstance] localizedString:@"Camera"]
                                                               style:UIAlertActionStyleDefault
                                                             handler:^(UIAlertAction *action) {
                                                                 [self _presentImagePickerWithSourceType:UIImagePickerControllerSourceTypeCamera];
                                                             }];
        [actionController addAction:cameraAction];
    }

    if ([KUSPermissions photoLibraryAccessIsAvailable]) {
        UIAlertAction *photoAction = [UIAlertAction actionWithTitle:[[KUSLocalization sharedInstance]
                                                                     localizedString:@"Photo Library"]
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
                                                                [self _presentImagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
                                                            }];
        [actionController addAction:photoAction];
    }

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[[KUSLocalization sharedInstance] localizedString:@"Cancel"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    [actionController addAction:cancelAction];
    [self presentViewController:actionController animated:YES completion:nil];
}

- (void)_presentImagePickerWithSourceType:(UIImagePickerControllerSourceType)sourceType
{
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.delegate = self;
    imagePickerController.sourceType = sourceType;

    UIModalPresentationStyle presentationStyle = (sourceType == UIImagePickerControllerSourceTypeCamera
                                                  ? UIModalPresentationFullScreen
                                                  : UIModalPresentationPopover);
    imagePickerController.modalPresentationStyle = presentationStyle;

    UIPopoverPresentationController *presentationController = imagePickerController.popoverPresentationController;
    presentationController.sourceView = self.inputBarView.attachmentButton;
    presentationController.sourceRect = self.inputBarView.attachmentButton.bounds;
    presentationController.permittedArrowDirections = UIPopoverArrowDirectionDown;

    imagePickerController.view.backgroundColor = [UIColor whiteColor];
    [self presentViewController:imagePickerController animated:YES completion:nil];
}

- (void)inputBarDesiredHeightDidChange:(KUSInputBar *)inputBar
{
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
}

- (void)inputBar:(KUSInputBar *)inputBar wantsToPreviewImage:(UIImage *)image
{
    [_inputBarView resignFirstResponder];

    NSMutableArray<id<NYTPhoto>> *photos = [[NSMutableArray alloc] init];
    id<NYTPhoto> initialPhoto = nil;

    for (UIImage *imageAttachment in inputBar.imageAttachments) {
        id<NYTPhoto> photo = [[KUSNYTImagePhoto alloc] initWithImage:imageAttachment];
        [photos addObject:photo];
        if (image == imageAttachment) {
            initialPhoto = photo;
        }
    }

    _nytPhotosDataSource = [[NYTPhotoViewerArrayDataSource alloc] initWithPhotos:photos];
    NYTPhotosViewController *photosViewController = [[NYTPhotosViewController alloc] initWithDataSource:_nytPhotosDataSource initialPhoto:initialPhoto delegate:self];
    [self presentViewController:photosViewController animated:YES completion:nil];
}

- (void)inputBarTextDidChange:(KUSInputBar *)inputBar
{
    NSString *trimmedText = [inputBar.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    BOOL isEmpty = [trimmedText isEqualToString:@""];
    
    if (!isEmpty) {
        [_chatMessagesDataSource sendTypingStatusToPusher:KUSTyping];
    }
}

#pragma mark - NYTPhotosViewControllerDelegate methods

- (UIView *)photosViewController:(NYTPhotosViewController *)photosViewController loadingViewForPhoto:(id <NYTPhoto>)photo
{
    UIActivityIndicatorView *activityIndicatorView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [activityIndicatorView startAnimating];
    return activityIndicatorView;
}

- (void)photosViewControllerWillDismiss:(NYTPhotosViewController *)photosViewController
{
    [self.view setNeedsLayout];
}

#pragma mark - UIImagePickerControllerDelegate methods

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
{
    [picker dismissViewControllerAnimated:YES completion:^ {
        UIImage *originalImage = [info valueForKey:UIImagePickerControllerOriginalImage];
        UIImage *editedImage = [info valueForKey:UIImagePickerControllerEditedImage];
        UIImage *chosenImage = editedImage ?: originalImage;
    
        if (chosenImage != nil) {
            [self.inputBarView attachImage:chosenImage];
        }
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - KUSCloseChatButtonViewDelegate methods

-(void)closeChatButtonTapped:(KUSEndChatButtonView *) closeChatButtonView
{
    [self showLoadingIndicator];
    [_chatMessagesDataSource endChat:@"customer_ended" withCompletion:^(BOOL status) {
        [self hideLoadingIndicator];
    }];
}

#pragma mark - KUSMLFormValuesPickerViewDelegate methods

- (void)mlFormValuesPickerView:(KUSMLFormValuesPickerView *)mlFormValuesPickerView didSelect:(NSString *)option with:(NSString *)optionId
{
    [_chatMessagesDataSource sendMessageWithText:option attachments:nil value:optionId];
    [_inputBarView setText:nil];
    [_inputBarView setImageAttachments:nil];
}

- (void)mlFormValuesPickerViewHeightDidChange:(KUSMLFormValuesPickerView *)mlFormValuesPickerView
{
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
}

#pragma mark - KUSSatisfactionFormTableViewCellDelegate methods

- (void)satisfactionFormTableViewCell:(KUSSatisfactionFormTableViewCell *)cell didSubmitComment:(NSString *)comment
{
    [_chatMessagesDataSource.satisfactionResponseDataSource submitComment:comment];
    [self.tableView reloadData];
}

- (void)satisfactionFormTableViewCell:(KUSSatisfactionFormTableViewCell *)cell didSelectRating:(NSInteger)rating
{
    satisfactionFormEditButtonPressed = NO;
    [_chatMessagesDataSource.satisfactionResponseDataSource submitRating:rating];
    [self.tableView reloadData];
}

#pragma mark - KUSEditFeedbackTableViewCellDelegate methods

- (void)editFeedbackTableViewCellDidEditButtonPressed:(KUSEditFeedbackTableViewCell *)cell
{
    satisfactionFormEditButtonPressed = YES;
    [self.tableView reloadData];
}


@end
