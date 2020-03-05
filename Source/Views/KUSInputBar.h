//
//  KUSInputBar.h
//  Kustomer
//
//  Created by Daniel Amitay on 7/21/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "KUSMediaAttachment.h"

@protocol KUSInputBarDelegate;
@class KUSUserSession;
@interface KUSInputBar : UIView

@property (nonatomic, strong) UIColor *separatorColor UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIColor *textColor UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIFont *textFont UI_APPEARANCE_SELECTOR;
@property (nonatomic, copy) NSString *placeholder UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIColor *placeholderColor UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIColor *sendButtonColor UI_APPEARANCE_SELECTOR;
@property (nonatomic, assign) UIKeyboardAppearance keyboardAppearance UI_APPEARANCE_SELECTOR;

@property (nonatomic, weak) id<KUSInputBarDelegate> delegate;

@property (nonatomic, strong, readonly) UIButton *attachmentButton;
@property (nonatomic, strong, readonly) UIButton *sendButton;

@property (nonatomic, copy) NSString *text;
@property (nonatomic, assign) BOOL allowsAttachments;
@property (nonatomic, copy) NSArray<KUSMediaAttachment *> *mediaAttachments;


- (instancetype)initWithUserSession:(KUSUserSession *)userSession;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;

- (void)attachImage:(UIImage *)image;
- (void)attachMedia:(KUSMediaAttachment *)mediaAttachment;

- (CGFloat)desiredHeight;

@end

@protocol KUSInputBarDelegate <NSObject>

@optional
- (BOOL)inputBarShouldEnableSend:(KUSInputBar *)inputBar;
- (void)inputBarDidPressSend:(KUSInputBar *)inputBar;
- (void)inputBarDidTapAttachment:(KUSInputBar *)inputBar;
- (void)inputBarTextDidChange:(KUSInputBar *)inputBar;
- (void)inputBarDesiredHeightDidChange:(KUSInputBar *)inputBar;
- (void)inputBar:(KUSInputBar *)inputBar wantsToPreviewAttachment:(KUSMediaAttachment *)attachment;
- (void)inputBarShowErrorPopUp:(KUSInputBar *)inputBar message:(NSString *)message title:(NSString *)title;

@end
