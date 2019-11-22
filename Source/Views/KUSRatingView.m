//
//  KUSRatingView.m
//  Kustomer
//
//  Created by BrainX Technologies on 12/04/2019.
//  Copyright © 2019 Kustomer. All rights reserved.
//

#import "KUSRatingView.h"
#import "KUSImage.h"
#import "KUSText.h"
#import "KUSColor.h"
#import "KUSLocalization.h"

static const CGFloat kKUSOptionButtonMaximumSize = 60.0;
static const CGFloat kKUSScaleLabelTopPadding = 11.0;

@interface KUSRatingView () {
    NSArray<UIButton *> *_optionButtons;
    UILabel *_lowScaleLabel;
    UILabel *_highScaleLabel;
    NSDictionary<NSString *,NSArray<NSString *> *> *ratingImagesCombination;
    NSDictionary<NSString *, NSArray<NSNumber *> *> *ratingValues;

}
@property (nonatomic, assign, readwrite) NSInteger selectedRating;
@property (nonatomic, assign, readwrite) NSInteger ratingOptions;
@property (nonatomic, assign, readwrite) KUSSatisfactionScaleType ratingType;
@property (nonatomic, copy) NSString *lowScaleLabelText;
@property (nonatomic, copy) NSString *highScaleLabelText;

@end

@implementation KUSRatingView

#pragma mark - Class methods

+ (void)initialize
{

    if (self == [KUSRatingView class]) {
        KUSRatingView *appearance = [KUSRatingView appearance];
        [appearance setLowScaleLabelColor:[[UIColor blackColor] colorWithAlphaComponent:0.7]];
        [appearance setHighScaleLabelColor:[[UIColor blackColor] colorWithAlphaComponent:0.7]];
        [appearance setHighScaleLabelFont:[UIFont systemFontOfSize:12.0]];
        [appearance setLowScaleLabelFont:[UIFont systemFontOfSize:12.0]];
    }
}

+ (CGFloat)heightOfRatingViewForForm:(KUSSatisfactionForm *)satisfactionForm maxWidth:(CGFloat)maxWidth
{
    CGFloat avaiableWidth = maxWidth;
    CGFloat buttonAvailableWidth = avaiableWidth / satisfactionForm.scaleOptions;
    CGFloat buttonWidth = MIN(buttonAvailableWidth , kKUSOptionButtonMaximumSize);
    // padding to label to align image and label as image has side padding of 20% of its width
    CGFloat scaleLabelSidePadding = buttonWidth * 0.125;
    CGFloat availableWidthForScaleLabel = (avaiableWidth/2) - (scaleLabelSidePadding * 2);
    KUSRatingView *appearance = [KUSRatingView appearance];
    
    CGFloat height = buttonWidth + kKUSScaleLabelTopPadding;
    
    CGFloat lowScaleLabelHeight = [self boundingSizeForText:satisfactionForm.scaleLabelLow
                                                   maxWidth:availableWidthForScaleLabel
                                                       font:appearance.lowScaleLabelFont].height;
    
    CGFloat highScaleLabelHeight = [self boundingSizeForText:satisfactionForm.scaleLabelHigh
                                                    maxWidth:availableWidthForScaleLabel
                                                        font:appearance.highScaleLabelFont].height;
    height += MAX(lowScaleLabelHeight, highScaleLabelHeight);
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

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        ratingValues = @{
          @"2": @[@1, @5],
          @"3": @[@1, @3, @5],
          @"5": @[@1, @2, @3, @4, @5]
        };
        
        ratingImagesCombination = @{
            @"0_5": @[@"number1", @"number2", @"number3", @"number4", @"number5"],
            @"1_5": @[@"emoji1", @"emoji2", @"emoji3", @"emoji4", @"emoji5"],
            @"1_3": @[@"emoji1", @"emoji3", @"emoji5"],
            @"1_2": @[@"emoji1", @"emoji5"],
            @"2_2": @[@"thumbsDown", @"thumbsUp"],
            @"2_3": @[@"thumbsDown", @"negative", @"thumbsUp"]
        };
        
        [super setBackgroundColor:[UIColor clearColor]];
        
        _lowScaleLabel = [[UILabel alloc] init];
        _lowScaleLabel.userInteractionEnabled = NO;
        _lowScaleLabel.adjustsFontSizeToFitWidth = YES;
        _lowScaleLabel.numberOfLines = 0;
        [self addSubview:_lowScaleLabel];
        
        _highScaleLabel = [[UILabel alloc] init];
        _highScaleLabel.userInteractionEnabled = NO;
        _highScaleLabel.numberOfLines = 0;
        _highScaleLabel.adjustsFontSizeToFitWidth = YES;
        [self addSubview:_highScaleLabel];
    }
    
    return self;
}

#pragma mark - View methods

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    BOOL isRTL = [[KUSLocalization sharedInstance] isCurrentLanguageRTL];
    
    CGFloat avaiableWidth = self.frame.size.width;
    CGFloat buttonAvailableWidth = avaiableWidth / _ratingOptions;
    CGFloat buttonWidth = MIN(buttonAvailableWidth , kKUSOptionButtonMaximumSize);
    CGFloat positionX = (avaiableWidth - (buttonWidth * _ratingOptions)) / 2;
    
    CGFloat scaleLabelSidePadding = buttonWidth * 0.125;
    for (UIButton *button in _optionButtons) {
        CGFloat positionXForRTL = avaiableWidth - positionX - buttonWidth;
        button.frame = (CGRect) {
            .size = CGSizeMake(buttonWidth, buttonWidth),
            .origin.x = isRTL ? positionXForRTL : positionX,
            .origin.y = 0
        };
        positionX += buttonWidth;
    }
    
    CGFloat availableWidthForScaleLabel = (avaiableWidth/2) - (scaleLabelSidePadding * 2);
    CGSize boundingSizeForLowScaleLabel = [[self class] boundingSizeForText:_lowScaleLabel.text
                                                           maxWidth:availableWidthForScaleLabel
                                                               font:_lowScaleLabelFont];
    BOOL scaleLabelsAlignToSides = _ratingOptions > 3;
    
    CGFloat lowScaleLabelOriginX;
    CGFloat lowScaleLabelOriginXForRTL;
    CGRect firstButtonFrame = _optionButtons.firstObject.frame;
    if (scaleLabelsAlignToSides) {
        lowScaleLabelOriginXForRTL = (firstButtonFrame.origin.x + firstButtonFrame.size.width) - scaleLabelSidePadding - boundingSizeForLowScaleLabel.width;
        lowScaleLabelOriginX = firstButtonFrame.origin.x + scaleLabelSidePadding;
        [_lowScaleLabel setTextAlignment:NSTextAlignmentLeft];
    } else {
        lowScaleLabelOriginXForRTL = (avaiableWidth/2) + scaleLabelSidePadding;;
        lowScaleLabelOriginX = (avaiableWidth/2) - scaleLabelSidePadding - boundingSizeForLowScaleLabel.width;
        [_lowScaleLabel setTextAlignment:NSTextAlignmentRight];
    }
    
    _lowScaleLabel.frame = (CGRect) {
        .origin.x = isRTL ? lowScaleLabelOriginXForRTL : lowScaleLabelOriginX,
        .origin.y = buttonWidth + kKUSScaleLabelTopPadding,
        .size = boundingSizeForLowScaleLabel
    };
    
    CGSize boundingSizeForHighScaleLabel = [[self class] boundingSizeForText:_highScaleLabel.text
                                                                    maxWidth:availableWidthForScaleLabel
                                                                        font:_highScaleLabelFont];
    CGFloat highScaleLabelOriginX;
    CGFloat highScaleLabelOriginXForRTL;
    CGRect lastButtonFrame = _optionButtons.lastObject.frame;
    if (scaleLabelsAlignToSides) {
        highScaleLabelOriginXForRTL = lastButtonFrame.origin.x + scaleLabelSidePadding;
        highScaleLabelOriginX = (lastButtonFrame.origin.x + lastButtonFrame.size.width) - boundingSizeForHighScaleLabel.width - scaleLabelSidePadding;
        [_highScaleLabel setTextAlignment:NSTextAlignmentRight];
    } else {
        highScaleLabelOriginXForRTL = (avaiableWidth/2) - scaleLabelSidePadding - boundingSizeForHighScaleLabel.width;
        highScaleLabelOriginX = (avaiableWidth/2) + scaleLabelSidePadding;
        [_highScaleLabel setTextAlignment:NSTextAlignmentLeft];
    }

    _highScaleLabel.frame = (CGRect) {
        .origin.x = isRTL ? highScaleLabelOriginXForRTL : highScaleLabelOriginX,
        .origin.y = buttonWidth + kKUSScaleLabelTopPadding,
        .size = boundingSizeForHighScaleLabel
    };
    
}

#pragma mark - Public methods

- (void)setRatingOptions:(KUSSatisfactionScaleType)type optionsCount:(NSInteger)count highScaleLabel:(NSString *)highScale lowScaleLabel:(NSString *)lowScale selectedRating:(NSInteger)rating
{
    _ratingType = type;
    _ratingOptions = count;
    NSInteger scaledRating = [[ratingValues objectForKey:[NSString stringWithFormat:@"%ld",(long)_ratingOptions]] indexOfObject:[NSNumber numberWithInteger:rating]];
    _selectedRating = scaledRating;
    [self setHighScaleLabelText:highScale];
    [self setLowScaleLabelText:lowScale];
    [self rebuildRatingView];
}

#pragma mark - Internal methods

- (void)rebuildRatingView
{
    for (UIButton *button in _optionButtons) {
        [button removeFromSuperview];
    }
    
    NSArray *ratingButtonImages = [ratingImagesCombination objectForKey: [NSString stringWithFormat:@"%ld_%ld",(long)_ratingType,(long)_ratingOptions]];
    
    if (ratingButtonImages.count != _ratingOptions) {
        ratingButtonImages = [ratingImagesCombination objectForKey: [NSString stringWithFormat:@"%d_%ld", 0,(long)_ratingOptions]];
    }
    
    NSMutableArray<UIButton *> *optionButtons = [[NSMutableArray alloc] initWithCapacity:_ratingOptions];
    
    for (int i = 0; i < _ratingOptions; i++) {
        UIButton *button = [[UIButton alloc] init];
        NSString *imageNamePostfix = _selectedRating == i ? @"Color" : @"Gray";
        NSString *ratingImageName = [NSString stringWithFormat:@"%@%@",ratingButtonImages[i],imageNamePostfix];
        [button setImage:[KUSImage imageNamed:ratingImageName] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(_onButtonPress:) forControlEvents:UIControlEventTouchUpInside];
        [optionButtons addObject:button];
        [self addSubview:button];
    }
    
    _optionButtons = optionButtons;
    [self setNeedsLayout];
}

- (void)_onButtonPress:(UIButton *)button
{
    NSInteger indexOfButton = [_optionButtons indexOfObject:button];
    if (indexOfButton != NSNotFound) {
        if ([self.delegate respondsToSelector:@selector(ratingView:didSelectRating:)]) {
            NSInteger rating = [ratingValues objectForKey:[NSString stringWithFormat:@"%ld",(long)_ratingOptions]][indexOfButton].integerValue;
            [self.delegate ratingView:self didSelectRating:rating];
        }
    }
}

- (void)setLowScaleLabelText:(NSString *)lowScaleLabelText
{
    _lowScaleLabelText = lowScaleLabelText;
    [_lowScaleLabel setText:_lowScaleLabelText];
}

- (void)setHighScaleLabelText:(NSString *)highScaleLabelText
{
    _highScaleLabelText = highScaleLabelText;
    [_highScaleLabel setText:_highScaleLabelText];
}

#pragma mark - UIAppearance methods

- (void)setLowScaleLabelFont:(UIFont *)lowScaleLabelFont
{
    _lowScaleLabelFont = lowScaleLabelFont;
    [_lowScaleLabel setFont:_lowScaleLabelFont];
}

- (void)setHighScaleLabelFont:(UIFont *)highScaleLabelFont
{
    _highScaleLabelFont = highScaleLabelFont;
    [_highScaleLabel setFont:_highScaleLabelFont];
}

- (void)setLowScaleLabelColor:(UIColor *)lowScaleLabelColor
{
    _lowScaleLabelColor = lowScaleLabelColor;
    [_lowScaleLabel setTextColor:_lowScaleLabelColor];
}

- (void)setHighScaleLabelColor:(UIColor *)highScaleLabelColor
{
    _highScaleLabelColor = highScaleLabelColor;
    [_highScaleLabel setTextColor:_highScaleLabelColor];
}

@end
