//
//  KUSSatisfactionFormTableViewCell.h
//  Kustomer
//
//  Created by BrainX Technologies on 12/04/2019.
//  Copyright © 2019 Kustomer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "KUSUserSession.h"

@protocol KUSSatisfactionFormTableViewCellDelegate;

@interface KUSSatisfactionFormTableViewCell : UITableViewCell

@property (nonatomic, strong) UIColor *satisfactionQuestionColor UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIColor *introductionQuestionColor UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIColor *commentQuestionColor UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIColor *commentBoxBorderColor UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIColor *commentBoxTextColor UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIColor *submitButtonBackgroundColor UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIColor *submitButtonTextColor UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIFont *satisfactionQuestionFont UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIFont *introductionQuestionFont UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIFont *commentQuestionFont UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIFont *submitButtonFont UI_APPEARANCE_SELECTOR;

@property (nonatomic, weak) id<KUSSatisfactionFormTableViewCellDelegate> delegate;

+ (CGFloat)heightForSatisfactionForm:(KUSSatisfactionForm *)satisfactionForm ratingOnly:(BOOL)ratingOnly maxWidth:(CGFloat)maxWidth;

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier userSession:(KUSUserSession *)userSession;
- (void)setSatisfactionForm:(KUSSatisfactionForm *)satisfactionForm rating:(NSInteger)rating;

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;
- (void)setBackgroundColor:(UIColor *)backgroundColor NS_UNAVAILABLE;

@end

@protocol KUSSatisfactionFormTableViewCellDelegate <NSObject>

@optional
- (void)satisfactionFormTableViewCell:(KUSSatisfactionFormTableViewCell *)cell didSelectRating:(NSInteger)rating;
- (void)satisfactionFormTableViewCell:(KUSSatisfactionFormTableViewCell *)cell didSubmitComment:(NSString *)comment;

@end
