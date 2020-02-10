//
//  KUSChatMessageTableViewCell.h
//  Kustomer
//
//  Created by Daniel Amitay on 7/16/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import <UIKit/UIKit.h>

@class KUSChatMessage;
@class KUSUserSession;
@protocol KUSChatMessageTableViewCellDelegate;
@interface KUSChatMessageTableViewCell : UITableViewCell

@property (nonatomic, strong) UIFont *textFont UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIColor *userBubbleColor UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIColor *companyBubbleColor UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIColor *userTextColor UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIColor *companyTextColor UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIFont *timestampFont UI_APPEARANCE_SELECTOR;
@property (nonatomic, strong) UIColor *timestampTextColor UI_APPEARANCE_SELECTOR;

@property (nonatomic, weak) id<KUSChatMessageTableViewCellDelegate> delegate;

+ (CGFloat)heightForChatMessage:(KUSChatMessage *)chatMessage maxWidth:(CGFloat)maxWidth;
+ (CGFloat)heightForTimestamp;

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier userSession:(KUSUserSession *)userSession;

- (void)setChatMessage:(KUSChatMessage *)chatMessage;
- (void)setShowsAvatar:(BOOL)showsAvatar;
- (void)setShowsTimestamp:(BOOL)showsTimestamp;

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;

@end

@protocol KUSChatMessageTableViewCellDelegate <NSObject>

@optional

- (void)chatMessageTableViewCell:(KUSChatMessageTableViewCell *)cell didTapLink:(NSURL *)URL;
- (void)chatMessageTableViewCellDidTapImage:(KUSChatMessageTableViewCell *)cell forMessage:(KUSChatMessage *)message;
- (void)chatMessageTableViewCellDidTapError:(KUSChatMessageTableViewCell *)cell forMessage:(KUSChatMessage *)message;
- (void)chatMessageTableViewCellDidTapAttachment:(KUSChatMessageTableViewCell *)cell forMessage:(KUSChatMessage *)message;

@end
