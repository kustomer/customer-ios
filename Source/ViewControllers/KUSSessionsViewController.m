//
//  KUSSessionsViewController.m
//  Kustomer
//
//  Created by Daniel Amitay on 7/16/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSSessionsViewController.h"

#import "KUSChatSessionsDataSource.h"
#import "KUSChatViewController.h"
#import "KUSUserSession.h"

#import "KUSColor.h"
#import "KUSImage.h"
#import "KUSChatPlaceholderTableViewCell.h"
#import "KUSChatSessionTableViewCell.h"
#import "KUSNavigationBarView.h"
#import "KUSNewSessionButton.h"
#import "KUSSessionsTableView.h"

@interface KUSSessionsViewController () <KUSNavigationBarViewDelegate, KUSPaginatedDataSourceListener, UITableViewDataSource, UITableViewDelegate> {
    KUSUserSession *_userSession;

    KUSChatSessionsDataSource *_chatSessionsDataSource;
    BOOL _didHandleFirstLoad;
}

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) KUSNewSessionButton *createSessionButton;
@property (nonatomic, strong) KUSNavigationBarView *fauxNavigationBar;

@end

@implementation KUSSessionsViewController

#pragma mark - Lifecycle methods

- (instancetype)initWithUserSession:(KUSUserSession *)userSession
{
    self = [super init];
    if (self) {
        _userSession = userSession;
    }
    return self;
}

#pragma mark - UIViewController methods

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];
    self.edgesForExtendedLayout = UIRectEdgeTop;

    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@""
                                                                             style:self.navigationItem.backBarButtonItem.style
                                                                            target:nil
                                                                            action:nil];

    UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                                                   target:self
                                                                                   action:@selector(_dismiss)];
    barButtonItem.style = UIBarButtonItemStyleDone;
    self.navigationItem.rightBarButtonItem = barButtonItem;

    self.tableView = [[KUSSessionsTableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = KUSChatSessionTableViewCellHeight;
    self.tableView.tableFooterView = [[UIView alloc] init];
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

    self.fauxNavigationBar = [[KUSNavigationBarView alloc] initWithUserSession:_userSession];
    self.fauxNavigationBar.delegate = self;
    [self.fauxNavigationBar setShowsLabels:NO];
    [self.fauxNavigationBar setShowsDismissButton:YES];
    [self.view addSubview:self.fauxNavigationBar];

    self.createSessionButton = [[KUSNewSessionButton alloc] initWithUserSession:_userSession];
    self.createSessionButton.autoresizingMask = (UIViewAutoresizingFlexibleTopMargin
                                                 | UIViewAutoresizingFlexibleLeftMargin
                                                 | UIViewAutoresizingFlexibleRightMargin);
    [self.createSessionButton addTarget:self
                                 action:@selector(_createSession)
                       forControlEvents:UIControlEventTouchUpInside];
    [self.createSessionButton setAccessibilityIdentifier:@"createSessionButton"];
    [self.view addSubview:self.createSessionButton];
    
    _chatSessionsDataSource = _userSession.chatSessionsDataSource;
    [_chatSessionsDataSource addListener:self];
    [_chatSessionsDataSource fetchLatest];

    BOOL shouldCreateNewSessionWithMessage = _chatSessionsDataSource.messageToCreateNewChatSession != nil;
    
    if (_chatSessionsDataSource.didFetch || shouldCreateNewSessionWithMessage) {
        [self _handleFirstLoadIfNecessary];
    } else {
        self.tableView.hidden = YES;
        self.createSessionButton.hidden = YES;
        [self showLoadingIndicator];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [_createSessionButton updateButton];
    [_chatSessionsDataSource fetchLatest];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];

    self.tableView.frame = self.view.bounds;

    self.fauxNavigationBar.topInset = self.edgeInsets.top;
    self.fauxNavigationBar.frame = (CGRect) {
        .size.width = self.view.bounds.size.width,
        .size.height = [self.fauxNavigationBar desiredHeight]
    };

    CGSize createSessionButtonSize = self.createSessionButton.intrinsicContentSize;
    self.createSessionButton.frame = (CGRect) {
        .origin.x = (self.view.bounds.size.width - createSessionButtonSize.width) / 2.0,
        .origin.y = self.view.bounds.size.height - createSessionButtonSize.height - self.edgeInsets.bottom - 23.0,
        .size = createSessionButtonSize
    };

    CGFloat bottomPadding = self.view.bounds.size.height - CGRectGetMaxY(self.createSessionButton.frame);
    CGFloat bottomButtonPadding = (bottomPadding * 2.0) + createSessionButtonSize.height;
    CGPoint startingContentOffset = self.tableView.contentOffset;
    UIEdgeInsets startingContentInset = self.tableView.contentInset;
    self.tableView.contentInset = (UIEdgeInsets) {
        .top = self.fauxNavigationBar.bounds.size.height,
        .bottom = self.edgeInsets.bottom + bottomButtonPadding
    };
    self.tableView.scrollIndicatorInsets = (UIEdgeInsets) {
        .top = self.tableView.contentInset.top,
        .bottom = self.edgeInsets.bottom
    };
    self.tableView.contentOffset = (CGPoint) {
        .x = startingContentOffset.x,
        .y = startingContentOffset.y - (self.tableView.contentInset.top - startingContentInset.top)
    };
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
}

#pragma mark - Interface element methods

- (void)_createSession
{
    if ([self.createSessionButton isBackToChat]) {
        KUSChatSession *chatSession = [_chatSessionsDataSource mostRecentNonProactiveCampaignOpenSession];
        KUSChatViewController *chatViewController = [[KUSChatViewController alloc] initWithUserSession:_userSession forChatSession:chatSession];
        [self.navigationController pushViewController:chatViewController animated:YES];
    } else {
        KUSChatViewController *chatViewController = [[KUSChatViewController alloc] initWithUserSession:_userSession
                                                                           forNewSessionWithBackButton:YES];
        [self.navigationController pushViewController:chatViewController animated:YES];
    }
}

- (void)_dismiss
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)userTappedRetryButton
{
    [_chatSessionsDataSource fetchLatest];
    [self showLoadingIndicatorWithText:@"Loading..."];
}

#pragma mark - Internal methods

- (void)_handleFirstLoadIfNecessary
{
    if (_didHandleFirstLoad) {
        return;
    }
    _didHandleFirstLoad = YES;
    
    BOOL shouldCreateNewSessionWithMessage = _chatSessionsDataSource.messageToCreateNewChatSession != nil;
    if (shouldCreateNewSessionWithMessage) {
        KUSChatViewController *chatViewController = [[KUSChatViewController alloc] initWithUserSession:_userSession forNewSessionWithMessage:_chatSessionsDataSource.messageToCreateNewChatSession];
        [self.navigationController pushViewController:chatViewController animated:NO];
        return;
    }
    
    if (_chatSessionsDataSource.count == 0 || _chatSessionsDataSource.openChatSessionsCount == 0) {
        // If there are no existing chat sessions, go directly to new chat screen
        KUSChatViewController *chatViewController = [[KUSChatViewController alloc] initWithUserSession:_userSession
                                                                           forNewSessionWithBackButton:NO];
        [self.navigationController pushViewController:chatViewController animated:NO];
    } else {
        // Go directly to the most recent chat session
        KUSChatSession *chatSession = [_chatSessionsDataSource mostRecentSession];
        KUSChatViewController *chatViewController = [[KUSChatViewController alloc] initWithUserSession:_userSession forChatSession:chatSession];
        [self.navigationController pushViewController:chatViewController animated:NO];
    }
}

#pragma mark - KUSNavigationBarViewDelegate methods

- (void)navigationBarViewDidTapDismiss:(KUSNavigationBarView *)navigationBarView
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - KUSPaginatedDataSourceListener methods

- (void)paginatedDataSourceDidChangeContent:(KUSPaginatedDataSource *)dataSource
{
    [self.tableView reloadData];
}

- (void)paginatedDataSourceDidLoad:(KUSPaginatedDataSource *)dataSource
{
    [self hideLoadingIndicator];
    [self _handleFirstLoadIfNecessary];
    self.tableView.hidden = NO;
    self.createSessionButton.hidden = NO;
}

- (void)paginatedDataSource:(KUSPaginatedDataSource *)dataSource didReceiveError:(NSError *)error
{
    NSString *errorText = error.localizedDescription ?: [[KUSLocalization sharedInstance] localizedString:@"Something went wrong. Please try again."];
    [self showErrorWithText:errorText];
    self.tableView.hidden = YES;
    self.createSessionButton.hidden = YES;
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    CGFloat visibleTableHeight = tableView.bounds.size.height - tableView.contentInset.top - tableView.contentInset.bottom;
    CGFloat rowCountThatFitsHeight = visibleTableHeight / tableView.rowHeight;
    NSUInteger minimumRowCount = (NSUInteger)floor(rowCountThatFitsHeight);
    return MAX(_chatSessionsDataSource.count, minimumRowCount);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL isSessionRow = indexPath.row < _chatSessionsDataSource.count;
    if (isSessionRow) {
        static NSString *kSessionCellIdentifier = @"SessionCell";
        KUSChatSessionTableViewCell *cell = (KUSChatSessionTableViewCell *)[tableView dequeueReusableCellWithIdentifier:kSessionCellIdentifier];
        if (cell == nil) {
            cell = [[KUSChatSessionTableViewCell alloc] initWithReuseIdentifier:kSessionCellIdentifier userSession:_userSession];
        }

        KUSChatSession *chatSession = [_chatSessionsDataSource objectAtIndex:indexPath.row];
        [cell setChatSession:chatSession];

        return cell;
    }

    static NSString *kPlaceholderCellIdentifier = @"PlaceholderCell";
    KUSChatPlaceholderTableViewCell *cell = (KUSChatPlaceholderTableViewCell *)[tableView dequeueReusableCellWithIdentifier:kPlaceholderCellIdentifier];
    if (cell == nil) {
        cell = [[KUSChatPlaceholderTableViewCell alloc] initWithReuseIdentifier:kPlaceholderCellIdentifier];
    }
    return cell;
}

#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    KUSChatSession *chatSession = [_chatSessionsDataSource objectAtIndex:indexPath.row];
    KUSChatViewController *chatViewController = [[KUSChatViewController alloc] initWithUserSession:_userSession forChatSession:chatSession];
    [self.navigationController pushViewController:chatViewController animated:YES];
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath
{
    BOOL isSessionRow = indexPath.row < _chatSessionsDataSource.count;
    return isSessionRow;
}

@end
