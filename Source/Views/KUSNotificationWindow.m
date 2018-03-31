//
//  KUSNotificationWindow.m
//  Kustomer
//
//  Created by Daniel Amitay on 9/18/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSNotificationWindow.h"

#import "KUSChatSessionTableViewCell.h"
#import "KUSUserSession.h"
#import "Kustomer_Private.h"
#import "KUSWeakTimer.h"

static const CGFloat KUSNotificationWindowShowDuration = 0.3;
static const CGFloat KUSNotificationWindowHideDuration = 0.2;
static const CGFloat KUSNotificationWindowVisibleDuration = 3.0;

static const CGFloat KUSNotificationWindowMaxWidth = 400.0;

@interface KUSNotificationWindow () {
    KUSChatSessionTableViewCell *_sessionTableViewCell;
    KUSWeakTimer *_hideTimer;
}

@end

@implementation KUSNotificationWindow

#pragma mark - Lifecycle methods

+ (KUSNotificationWindow *)sharedInstance
{
    static KUSNotificationWindow *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[KUSNotificationWindow alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.windowLevel = UIWindowLevelStatusBar + 1.0;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOffset = CGSizeMake(0.0, 1.0);
        self.layer.shadowRadius = 3.0;
        self.layer.shadowOpacity = 0.4;
        
        UIViewController *viewController = [[UIViewController alloc] init];
        viewController.view.backgroundColor = [UIColor whiteColor];
        viewController.view.clipsToBounds = YES;
        self.rootViewController = viewController;
        
        [self _layoutWindow];
        
        self.alpha = 0.0;
        self.hidden = NO;
        self.transform = CGAffineTransformMakeTranslation(0.0, -KUSChatSessionTableViewCellHeight);
        
        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_didTap:)];
        [self addGestureRecognizer:tapGestureRecognizer];
        
        UISwipeGestureRecognizer *swipeGestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(hide)];
        swipeGestureRecognizer.direction = UISwipeGestureRecognizerDirectionUp;
        [self addGestureRecognizer:swipeGestureRecognizer];
    }
    return self;
}

- (void)_layoutWindow
{
    CGFloat safeAreaSize = 0;
    if (@available(iOS 11.0, *)) {
        UIWindow *window = UIApplication.sharedApplication.keyWindow;
        safeAreaSize = window.safeAreaInsets.top;
    }
    
    CGFloat windowWidth = MIN([UIScreen mainScreen].bounds.size.width, KUSNotificationWindowMaxWidth);
    CGFloat windowHeight = KUSChatSessionTableViewCellHeight + safeAreaSize;
    
    self.bounds = (CGRect) {
        .size.width = windowWidth,
        .size.height = windowHeight
    };
    self.center = (CGPoint) {
        .x = [UIScreen mainScreen].bounds.size.width / 2.0,
        .y = windowHeight / 2.0
    };
}

- (void)_didTap:(UITapGestureRecognizer *)tapGestureRecognizer
{
    [self hide];
    [[Kustomer sharedInstance].userSession.delegateProxy didTapOnInAppNotification];
}

#pragma mark - Public methods

- (void)showChatSession:(KUSChatSession *)chatSession autoDismiss:(BOOL)autoDismiss
{
    [self _layoutWindow];
    
    CGFloat safeAreaSize = 0;
    if (@available(iOS 11.0, *)) {
        UIWindow *window = UIApplication.sharedApplication.keyWindow;
        safeAreaSize = window.safeAreaInsets.top;
    }
    
    [_sessionTableViewCell removeFromSuperview];
    
    KUSUserSession *userSession = [Kustomer sharedInstance].userSession;
    _sessionTableViewCell = [[KUSChatSessionTableViewCell alloc] initWithReuseIdentifier:nil userSession:userSession];
    _sessionTableViewCell.frame = (CGRect) {
        .size.width = self.bounds.size.width,
        .size.height = KUSChatSessionTableViewCellHeight,
        .origin.x = self.bounds.origin.x,
        .origin.y = safeAreaSize
    };
    
    _sessionTableViewCell.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_sessionTableViewCell setChatSession:chatSession];
    [self addSubview:_sessionTableViewCell];
    
    [UIView
     animateWithDuration:KUSNotificationWindowShowDuration
     delay:0.0
     options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
     animations:^{
         self.alpha = 1.0;
         self.transform = CGAffineTransformIdentity;
     } completion:nil];
    
    [_hideTimer invalidate];
    if (autoDismiss) {
        _hideTimer = [KUSWeakTimer scheduledTimerWithTimeInterval:KUSNotificationWindowShowDuration + KUSNotificationWindowVisibleDuration
                                                           target:self
                                                         selector:@selector(hide)
                                                          repeats:NO];
    }
}

- (void)hide
{
    [_hideTimer invalidate];
    _hideTimer = nil;
    
    [UIView
     animateWithDuration:KUSNotificationWindowHideDuration
     delay:0.0
     options:UIViewAnimationOptionAllowUserInteraction
     animations:^{
         self.alpha = 0.0;
         self.transform = CGAffineTransformMakeTranslation(0.0, -KUSChatSessionTableViewCellHeight);
     } completion:^(BOOL finished) {
         if (finished) {
             [_sessionTableViewCell removeFromSuperview];
             _sessionTableViewCell = nil;
         }
     }];
}

@end
