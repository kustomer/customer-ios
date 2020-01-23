//
//  KUSSatisfactionFormTableViewCell.m
//  Kustomer
//
//  Created by BrainX Technologies on 12/04/2019.
//  Copyright © 2019 Kustomer. All rights reserved.
//

#import "KUSSatisfactionFormTableViewCell.h"
#import "KUSSatisfactionForm.h"
#import "KUSText.h"
#import "KUSAvatarImageView.h"
#import "KUSRatingView.h"
#import "KUSColor.h"
#import "KUSChatMessageTableViewCell.h"

static const CGFloat kCellVerticalPadding = 11.0;
static const CGFloat kAvatarDiameter = 40.0;
static const CGFloat kFormPaddingFromCellOnAvatarSide = 60.0;
static const CGFloat kRowSidePadding = 11.0;
static const CGFloat kMaximumFormWidth = 300.0;
static const CGFloat kKUSCommentBoxHeight = 100.0;
static const CGFloat kKUSSubmitButtonHeight = 40.0;

@interface KUSSatisfactionFormTableViewCell () <KUSRatingViewDelegate> {
    
    KUSSatisfactionForm *_satisfactionForm;
    KUSAvatarImageView *_avatarImageView;
    UILabel *_satisfactionQuestion;
    UILabel *_introductionQuestion;
    UILabel *_commentQuestion;
    UITextView *_commentBox;
    UIButton *_submitButton;
    UIView *_formView;
    KUSRatingView *_ratingView;
}
@end

@implementation KUSSatisfactionFormTableViewCell

#pragma mark - Class methods

+ (void)initialize
{
    if (self == [KUSSatisfactionFormTableViewCell class]) {
        KUSSatisfactionFormTableViewCell *appearance = [KUSSatisfactionFormTableViewCell appearance];
        [appearance setSatisfactionQuestionColor:[UIColor blackColor]];
        [appearance setIntroductionQuestionColor:[UIColor blackColor]];
        [appearance setCommentQuestionColor:[UIColor blackColor]];
        [appearance setSubmitButtonTextColor:[UIColor whiteColor]];
        [appearance setSubmitButtonBackgroundColor:[KUSColor blueColor]];
        [appearance setCommentBoxTextColor:[UIColor blackColor]];
        [appearance setCommentBoxBorderColor:[[UIColor blackColor] colorWithAlphaComponent:0.2]];
        [appearance setSatisfactionQuestionFont:[UIFont systemFontOfSize:13.0]];
        [appearance setIntroductionQuestionFont:[UIFont boldSystemFontOfSize:15.0]];
        [appearance setCommentQuestionFont:[UIFont boldSystemFontOfSize:13.0]];
        [appearance setSubmitButtonFont:[UIFont boldSystemFontOfSize:14.0]];
    }
}

+ (CGFloat)heightForSatisfactionForm:(KUSSatisfactionForm *)satisfactionForm ratingOnly:(BOOL)ratingOnly maxWidth:(CGFloat)maxWidth
{
    CGFloat formAvailableWidth = maxWidth - kRowSidePadding - kFormPaddingFromCellOnAvatarSide;
    CGFloat actualFormWidth = MIN(formAvailableWidth, kMaximumFormWidth);
    CGFloat formContentMaxWidth = actualFormWidth - (kRowSidePadding * 2);
    CGFloat height = (kCellVerticalPadding * 3);
    
    KUSSatisfactionFormTableViewCell *appearance = [KUSSatisfactionFormTableViewCell appearance];
    
    height += [self boundingSizeForText:satisfactionForm.ratingPrompt
                               maxWidth:formContentMaxWidth - 1
                                   font:appearance.satisfactionQuestionFont].height;
    height += kCellVerticalPadding;
    height += [self boundingSizeForText:satisfactionForm.introduction
                              maxWidth:formContentMaxWidth - 1
                                  font:appearance.introductionQuestionFont].height;
    height += kCellVerticalPadding;
    height += [KUSRatingView heightOfRatingViewForForm:satisfactionForm maxWidth:formContentMaxWidth];
    height += kCellVerticalPadding;
    
    if (ratingOnly) {
        height += kCellVerticalPadding;
        return height;
    }
    height += kCellVerticalPadding;
    height += [self boundingSizeForText:satisfactionForm.questions.firstObject.prompt
                               maxWidth:formContentMaxWidth - 1
                                   font:appearance.commentQuestionFont].height;
    
    height += kCellVerticalPadding;
    height += kKUSCommentBoxHeight;
    height += kCellVerticalPadding;
    height += kKUSSubmitButtonHeight;
    height += (kCellVerticalPadding * 2);
    return height;
}

+ (CGSize)boundingSizeForText:(NSString *)text maxWidth:(CGFloat)maxWidth font:(UIFont *)font
{
    
    NSAttributedString *attributedString = [KUSText attributedStringFromText:text fontSize:font.pointSize];
    
    CGSize maxSize = CGSizeMake(maxWidth, 1000.0);
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
        
        [super setBackgroundColor:[[KUSChatMessageTableViewCell appearance] backgroundColor]];
        
        _formView = [[UIView alloc] init];
        _formView.layer.masksToBounds = true;
        [_formView setBackgroundColor:[[KUSChatMessageTableViewCell appearance] companyBubbleColor]];
        [self.contentView addSubview:_formView];
        
        _satisfactionQuestion = [[UILabel alloc] init];
        _satisfactionQuestion.userInteractionEnabled = NO;
        _satisfactionQuestion.numberOfLines = 0;
        _satisfactionQuestion.textAlignment = NSTextAlignmentCenter;
        [_formView addSubview:_satisfactionQuestion];
      
        _introductionQuestion = [[UILabel alloc] init];
        _introductionQuestion.userInteractionEnabled = NO;
        _introductionQuestion.numberOfLines = 0;
        _introductionQuestion.textAlignment = NSTextAlignmentCenter;
        [_formView addSubview:_introductionQuestion];
        
        _ratingView = [[KUSRatingView alloc] init];
        _ratingView.delegate = self;
        [_formView addSubview:_ratingView];
        
        _commentQuestion = [[UILabel alloc] init];
        _commentQuestion.userInteractionEnabled = NO;
        _commentQuestion.textAlignment = NSTextAlignmentCenter;
        _commentQuestion.numberOfLines = 0;
        [_formView addSubview:_commentQuestion];
        
        _commentBox = [[UITextView alloc] init];
        _commentBox.userInteractionEnabled = true;
        _commentBox.layer.masksToBounds = YES;
        _commentBox.layer.cornerRadius = 4.0;
        _commentBox.layer.borderWidth = 0.5f;
        [_commentBox setBackgroundColor:[UIColor clearColor]];
        [_formView addSubview:_commentBox];

        _submitButton = [[UIButton alloc] init];
        _submitButton.layer.masksToBounds = YES;
        _submitButton.layer.cornerRadius = 4;
        [_submitButton setTitle:[[KUSLocalization sharedInstance] localizedString:@"Submit"]
                       forState:UIControlStateNormal];
        [_submitButton addTarget:self
                          action:@selector(_onSubmitPress:)
                forControlEvents:UIControlEventTouchUpInside];
        [_formView addSubview:_submitButton];
        
        _avatarImageView = [[KUSAvatarImageView alloc] initWithUserSession:userSession];
        [self.contentView addSubview:_avatarImageView];
    }
    return self;
}

#pragma mark - Layout methods

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    BOOL isRTL = [[KUSLocalization sharedInstance] isCurrentLanguageRTL];
    
    CGFloat availableFormWidth = self.contentView.bounds.size.width - kRowSidePadding - kFormPaddingFromCellOnAvatarSide;
    CGFloat actualFormWidth = MIN(availableFormWidth, kMaximumFormWidth);
    
    CGFloat formViewOriginXForRTL = self.contentView.bounds.size.width - actualFormWidth - kFormPaddingFromCellOnAvatarSide;
    _formView.frame = (CGRect) {
        .origin.x = isRTL ? formViewOriginXForRTL : kFormPaddingFromCellOnAvatarSide,
        .origin.y = (kCellVerticalPadding * 2),
        .size.width = actualFormWidth,
        .size.height = self.contentView.bounds.size.height - (kCellVerticalPadding * 3)
    };
    _formView.layer.cornerRadius = 15.0;
    
    CGFloat maxContentWidth = _formView.bounds.size.width - (kRowSidePadding * 2);
    
    CGSize boundingSizeForIntroductionQuestion = [[self class] boundingSizeForText:_introductionQuestion.text
                                                                          maxWidth:maxContentWidth - 1
                                                                              font:_introductionQuestionFont];
    
    _introductionQuestion.frame = (CGRect) {
        .origin.x = kRowSidePadding,
        .origin.y = kCellVerticalPadding,
        .size.height = boundingSizeForIntroductionQuestion.height,
        .size.width = maxContentWidth
    };
    
    CGFloat satisfactionQuestionOriginY = _introductionQuestion.frame.origin.y + boundingSizeForIntroductionQuestion.height + kCellVerticalPadding;
    CGSize boundingSizeForSatisfactionQuestion = [[self class] boundingSizeForText:_satisfactionQuestion.text
                                                                          maxWidth:maxContentWidth - 1
                                                                              font:_satisfactionQuestionFont];
    
    _satisfactionQuestion.frame = (CGRect) {
        .origin.x = kRowSidePadding,
        .origin.y = satisfactionQuestionOriginY,
        .size.height = boundingSizeForSatisfactionQuestion.height,
        .size.width = maxContentWidth
    };
    
    CGFloat ratingViewOriginY = _satisfactionQuestion.frame.origin.y + boundingSizeForSatisfactionQuestion.height + kCellVerticalPadding;
    CGFloat ratingViewHeight = [KUSRatingView heightOfRatingViewForForm:_satisfactionForm maxWidth:maxContentWidth];
    _ratingView.frame = (CGRect) {
        .origin.x = kRowSidePadding,
        .origin.y = ratingViewOriginY,
        .size.width = maxContentWidth,
        .size.height = ratingViewHeight
    };
    
    CGSize boundingSizeForCommentQuestion = [[self class] boundingSizeForText:_commentQuestion.text
                                                                     maxWidth:maxContentWidth - 1
                                                                         font:_commentQuestionFont];
    CGFloat commentQuestionOriginY = _ratingView.frame.origin.y + _ratingView.frame.size.height + (kCellVerticalPadding * 2);
    _commentQuestion.frame = (CGRect) {
        .origin.x = kRowSidePadding,
        .origin.y = commentQuestionOriginY,
        .size.height = boundingSizeForCommentQuestion.height,
        .size.width = maxContentWidth
    };
    
    CGFloat commentBoxOriginY = _commentQuestion.frame.origin.y + _commentQuestion.frame.size.height + kCellVerticalPadding;
    _commentBox.frame = (CGRect) {
        .origin.x = kRowSidePadding,
        .origin.y = commentBoxOriginY,
        .size.width = maxContentWidth,
        .size.height = kKUSCommentBoxHeight
    };
    
    _submitButton.frame = (CGRect) {
        .origin.x = kRowSidePadding,
        .origin.y = _commentBox.frame.origin.y + _commentBox.frame.size.height + kCellVerticalPadding,
        .size.width = maxContentWidth,
        .size.height = kKUSSubmitButtonHeight
    };
    
    CGFloat avatarOriginXForRTL = self.contentView.bounds.size.width - kRowSidePadding - kAvatarDiameter;
    _avatarImageView.frame = (CGRect) {
        .origin.x = isRTL ? avatarOriginXForRTL : kRowSidePadding,
        .origin.y = self.contentView.bounds.size.height - kAvatarDiameter - kCellVerticalPadding,
        .size.width = kAvatarDiameter,
        .size.height = kAvatarDiameter
    };
}

#pragma mark - Public methods

- (void)setSatisfactionForm:(KUSSatisfactionForm *)satisfactionForm rating:(NSInteger)rating
{
    _satisfactionForm = satisfactionForm;
    [_satisfactionQuestion setText:satisfactionForm.ratingPrompt];
    [_introductionQuestion setText:satisfactionForm.introduction];
    [_commentQuestion setText:satisfactionForm.questions.firstObject.prompt];
    [_ratingView setRatingOptions:satisfactionForm.scaleType
                     optionsCount:satisfactionForm.scaleOptions
                   highScaleLabel:satisfactionForm.scaleLabelHigh
                    lowScaleLabel:satisfactionForm.scaleLabelLow
                   selectedRating:rating];
    [_commentBox setText:@""];
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

#pragma mark - Internal methods

- (void)_onSubmitPress:(UIButton *)button
{
    //Change to thanks view
    if ([self.delegate respondsToSelector:@selector(satisfactionFormTableViewCell:didSubmitComment:)]) {
        [self.delegate satisfactionFormTableViewCell:self didSubmitComment:_commentBox.text];
    }
}

#pragma mark - Rating View delegate methods

- (void)ratingView:(KUSRatingView *)ratingView didSelectRating:(NSInteger)rating
{
    if ([self.delegate respondsToSelector:@selector(satisfactionFormTableViewCell:didSelectRating:)]) {
        [self.delegate satisfactionFormTableViewCell:self didSelectRating:rating];
    }
}

#pragma mark - UIAppearance methods

- (void)setSatisfactionQuestionFont:(UIFont *)satisfactionQuestionFont
{
    _satisfactionQuestionFont = satisfactionQuestionFont;
    [_satisfactionQuestion setFont:_satisfactionQuestionFont];
}

- (void)setIntroductionQuestionFont:(UIFont *)introductionQuestionFont
{
    _introductionQuestionFont = introductionQuestionFont;
    [_introductionQuestion setFont:_introductionQuestionFont];
}

- (void)setCommentQuestionFont:(UIFont *)commentQuestionFont
{
    _commentQuestionFont = commentQuestionFont;
    [_commentQuestion setFont:_commentQuestionFont];
}

- (void)setSubmitButtonFont:(UIFont *)submitButtonFont
{
    _submitButtonFont = submitButtonFont;
    [_submitButton.titleLabel setFont:_submitButtonFont];
}

- (void)setSatisfactionQuestionColor:(UIColor *)satisfactionQuestionColor
{
    _satisfactionQuestionColor = satisfactionQuestionColor;
    [_satisfactionQuestion setTextColor:_satisfactionQuestionColor];
}

- (void)setIntroductionQuestionColor:(UIColor *)introductionQuestionColor
{
    _introductionQuestionColor = introductionQuestionColor;
    [_introductionQuestion setTextColor:_introductionQuestionColor];
}

- (void)setCommentQuestionColor:(UIColor *)commentQuestionColor
{
    _commentQuestionColor = commentQuestionColor;
    [_commentQuestion setTextColor:_commentQuestionColor];
}

- (void)setCommentBoxBorderColor:(UIColor *)commentBoxBorderColor
{
    _commentBoxBorderColor = commentBoxBorderColor;
    [_commentBox.layer setBorderColor:_commentBoxBorderColor.CGColor];
}

- (void)setCommentBoxTextColor:(UIColor *)commentBoxTextColor
{
    _commentBoxTextColor = commentBoxTextColor;
    [_commentBox setTextColor:_commentBoxTextColor];
}

- (void)setSubmitButtonBackgroundColor:(UIColor *)submitButtonBackgroundColor
{
    _submitButtonBackgroundColor = submitButtonBackgroundColor;
    [_submitButton setBackgroundColor:_submitButtonBackgroundColor];
}

- (void)setSubmitButtonTextColor:(UIColor *)submitButtonTextColor
{
    _submitButtonTextColor = submitButtonTextColor;
    [_submitButton setTitleColor:_submitButtonTextColor forState:UIControlStateNormal];
}

@end
