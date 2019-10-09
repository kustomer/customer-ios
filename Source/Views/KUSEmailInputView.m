//
//  KUSEmailInputView.m
//  Kustomer
//
//  Created by Daniel Amitay on 8/26/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSEmailInputView.h"

#import "KUSColor.h"
#import "KUSImage.h"
#import "KUSText.h"
#import "KUSLocalization.h"

@interface KUSEmailInputView () <UITextFieldDelegate>

@property (nonatomic, strong) UILabel *infoLabel;
@property (nonatomic, strong) UITextField *textField;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong) UIView *separatorView;

@end

@implementation KUSEmailInputView

#pragma mark - Class methods

+ (void)initialize
{
    if (self == [KUSEmailInputView class]) {
        KUSEmailInputView *appearance = [KUSEmailInputView appearance];
        [appearance setBackgroundColor:[KUSColor lightGrayColor]];
        [appearance setPrompt:[[KUSLocalization sharedInstance] localizedString:@"Don't miss a response! Get notified by email:"]];
        [appearance setPromptColor:[KUSColor darkGrayColor]];
        [appearance setPromptFont:[UIFont systemFontOfSize:12.0]];
        [appearance setPlaceholder:[[KUSLocalization sharedInstance] localizedString:@"example@domain.com"]];
        [appearance setPlaceholderFont:[UIFont systemFontOfSize:14.0]];
        [appearance setSeparatorColor:[KUSColor grayColor]];
        [appearance setBorderColor:[KUSColor greenColor]];
        [appearance setInputBackgroundColor:[UIColor whiteColor]];
    }
}

#pragma mark - Lifecycle methods

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = YES;

        self.infoLabel = [[UILabel alloc] init];
        self.infoLabel.textAlignment = NSTextAlignmentCenter;
        self.infoLabel.adjustsFontSizeToFitWidth = YES;
        self.infoLabel.minimumScaleFactor = 10.0 / 12.0;
        [self.infoLabel setAccessibilityIdentifier:@"emailInfoLabel"];
        [self addSubview:self.infoLabel];

        self.textField = [[UITextField alloc] init];
        self.textField.textAlignment = NSTextAlignmentCenter;
        self.textField.delegate = self;
        self.textField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 10.0, 0.0)];
        self.textField.leftViewMode = UITextFieldViewModeAlways;
        self.textField.rightView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 25.0, 0.0)];
        self.textField.rightViewMode = UITextFieldViewModeAlways;
        self.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textField.returnKeyType = UIReturnKeySend;
        self.textField.layer.borderWidth = 1.0;
        self.textField.layer.masksToBounds = YES;
        [self.textField setAccessibilityIdentifier:@"emailTextField"];
        [self addSubview:self.textField];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_updateSubmitButton)
                                                     name:UITextFieldTextDidChangeNotification
                                                   object:self.textField];

        self.submitButton = [[UIButton alloc] init];
        [self.submitButton addTarget:self
                              action:@selector(_userWantsToSubmit)
                    forControlEvents:UIControlEventTouchUpInside];
        [self.submitButton setAccessibilityIdentifier:@"emailSubmitButton"];
        [self addSubview:self.submitButton];

        self.separatorView = [[UIView alloc] init];
        [self addSubview:self.separatorView];

        [self _updateSubmitButton];
    }
    return self;
}

#pragma mark - View methods

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat sidePadding = 20.0;
    self.infoLabel.frame = (CGRect) {
        .origin.x = sidePadding,
        .origin.y = sidePadding / 2.0,
        .size.width = self.bounds.size.width - (sidePadding * 2.0),
        .size.height = sidePadding
    };

    self.textField.frame = (CGRect) {
        .origin.x = sidePadding,
        .origin.y = CGRectGetMaxY(self.infoLabel.frame) + 5.0,
        .size.width = self.bounds.size.width - (sidePadding * 2.0),
        .size.height = 30.0
    };
    self.textField.layer.cornerRadius = self.textField.frame.size.height / 2.0;

    BOOL isRTL = [[KUSLocalization sharedInstance] isCurrentLanguageRTL];
    self.submitButton.frame = (CGRect) {
        .origin.x = isRTL ? sidePadding : CGRectGetMaxX(self.textField.frame) - 30.0,
        .origin.y = CGRectGetMaxY(self.textField.frame) - 30.0,
        .size.width = 30.0,
        .size.height = 30.0
    };

    self.separatorView.frame = (CGRect) {
        .origin.y = self.bounds.size.height - 0.5,
        .size.width = self.bounds.size.width,
        .size.height = 0.5
    };
}

#pragma mark - Interface element methods

- (void)_userWantsToSubmit
{
    BOOL isValidEmail = [KUSText isValidEmail:[self _sanitizedText]];
    if (isValidEmail) {
        [self.delegate emailInputView:self didSubmitEmail:[self _sanitizedText]];
        [self.textField resignFirstResponder];
    }
}

- (NSString *)_sanitizedText
{
    return [self.textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)_updateSubmitButton
{
    BOOL isValidEmail = [KUSText isValidEmail:[self _sanitizedText]];
    self.submitButton.userInteractionEnabled = isValidEmail;
    self.submitButton.alpha = (isValidEmail ? 1.0 : 0.5);
}

#pragma mark - UITextFieldDelegate methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self _userWantsToSubmit];
    return NO;
}

#pragma mark - UIAppearance methods

- (void)setPrompt:(NSString *)prompt
{
    _prompt = prompt;
    self.infoLabel.text = _prompt;
}

- (void)setPromptColor:(UIColor *)promptColor
{
    _promptColor = promptColor;
    self.infoLabel.textColor = _promptColor;
}

- (void)setPromptFont:(UIFont *)promptFont
{
    _promptFont = promptFont;
    self.infoLabel.font = _promptFont;
}

- (void)setPlaceholder:(NSString *)placeholder
{
    _placeholder = placeholder;
    self.textField.placeholder = _placeholder;
}

- (void)setPlaceholderFont:(UIFont *)placeholderFont
{
    _placeholderFont = placeholderFont;
    self.textField.font = _placeholderFont;
}

- (void)setSeparatorColor:(UIColor *)separatorColor
{
    _separatorColor = separatorColor;
    self.separatorView.backgroundColor = _separatorColor;
}

- (void)setBorderColor:(UIColor *)borderColor
{
    _borderColor = borderColor;
    self.textField.layer.borderColor = _borderColor.CGColor;

    UIImage *submitImage = [KUSImage submitImageWithSize:CGSizeMake(24.0, 24.0) color:_borderColor];
    [self.submitButton setImage:submitImage forState:UIControlStateNormal];
}

- (void)setInputBackgroundColor:(UIColor *)inputBackgroundColor
{
    _inputBackgroundColor = inputBackgroundColor;
    self.textField.backgroundColor = _inputBackgroundColor;
}

@end
