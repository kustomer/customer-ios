//
//  KUSChatMessageTableViewCell.m
//  Kustomer
//
//  Created by Daniel Amitay on 7/16/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSChatMessageTableViewCell.h"
#import <UIKit/UIKit.h>

#import <SDWebImage/UIImageView+WebCache.h>
#import <SDWebImage/UIView+WebCache.h>
#import <TTTAttributedLabel/TTTAttributedLabel.h>

#import "Kustomer_Private.h"
#import "KUSChatMessage.h"
#import "KUSColor.h"
#import "KUSDate.h"
#import "KUSImage.h"
#import "KUSText.h"
#import "KUSUserSession.h"
#import "KUSTimer.h"

#import "KUSAvatarImageView.h"

#import <QuickLook/QuickLook.h>

// If sending messages takes less than 750ms, we don't want to show the loading indicator
static NSTimeInterval kOptimisticSendLoadingDelay = 0.75;

static const CGFloat kBubbleTopPadding = 10.0;
static const CGFloat kBubbleSidePadding = 12.0;

static const CGFloat kRowSidePadding = 11.0;
static const CGFloat kRowTopPadding = 3.0;

static const CGFloat kMaxBubbleWidth = 250.0;
static const CGFloat kMinBubbleHeight = 38.0;

static const CGFloat kAvatarDiameter = 40.0;

static const CGFloat kTimestampTopPadding = 4.0;

@interface KUSChatMessageTableViewCell () <TTTAttributedLabelDelegate> {
    KUSUserSession *_userSession;
    KUSChatMessage *_chatMessage;
    BOOL _showsAvatar;
    BOOL _showsTimestamp;
    KUSTimer *_sendingFadeTimer;

    KUSAvatarImageView *_avatarImageView;
    UIView *_bubbleView;
    TTTAttributedLabel *_labelView;
    TTTAttributedLabel *_subLabelView;
    UIImageView *_imageView;
    UIButton *_errorButton;
    UILabel *_timestampLabel;
    UIImageView *_documentIcon;
}

@end

@implementation KUSChatMessageTableViewCell

#pragma mark - Class methods

+ (void)initialize
{
    if (self == [KUSChatMessageTableViewCell class]) {
        KUSChatMessageTableViewCell *appearance = [KUSChatMessageTableViewCell appearance];
        [appearance setTextFont:[UIFont systemFontOfSize:14.0]];
        [appearance setUserBubbleColor:[KUSColor blueColor]];
        [appearance setCompanyBubbleColor:[KUSColor lightGrayColor]];
        [appearance setUserTextColor:[UIColor whiteColor]];
        [appearance setCompanyTextColor:[UIColor blackColor]];
        [appearance setTimestampFont:[UIFont systemFontOfSize:11.0]];
        [appearance setTimestampTextColor:[UIColor grayColor]];
    }
}

+ (CGFloat)heightForChatMessage:(KUSChatMessage *)chatMessage maxWidth:(CGFloat)maxWidth
{
    CGFloat height = [self boundingSizeForMessage:chatMessage maxWidth:maxWidth].height;
    height += kBubbleTopPadding * 2.0;
    height = MAX(height, kMinBubbleHeight);
    height += kRowTopPadding * 2.0;
    if(chatMessage.type == KUSChatMessageTypeAttachment){
      height += 22;
    }
    return height;
}

+ (CGFloat)heightForTimestamp
{
    UIFont *font = [self timestampFont];
    if (font) {
        return font.lineHeight + kTimestampTopPadding;
    } else {
        return 0.0;
    }
}

+ (UIFont *)timestampFont
{
    KUSChatMessageTableViewCell *appearance = [KUSChatMessageTableViewCell appearance];
    return [appearance timestampFont];
}

+ (CGFloat)fontSize
{
    return [self messageFont].pointSize;
}

+ (UIFont *)messageFont
{
    KUSChatMessageTableViewCell *appearance = [KUSChatMessageTableViewCell appearance];
    return [appearance textFont];
}

+ (CGSize)boundingSizeForMessage:(KUSChatMessage *)message maxWidth:(CGFloat)maxWidth
{
    switch (message.type) {
        default:
        case KUSChatMessageTypeText:
            return [self boundingSizeForText:message.body maxWidth:maxWidth];
        case KUSChatMessageTypeImage:
            return [self boundingSizeForImage:message.imageURL maxWidth:maxWidth];
        case KUSChatMessageTypeAttachment:
            return [self boundingSizeForText:[NSString stringWithFormat:@"ICO %@", message.displayAttachmentFileName] maxWidth:maxWidth];
    }
}

+ (CGSize)boundingSizeForImage:(NSURL *)imageURL maxWidth:(CGFloat)maxWidth
{
    CGFloat actualMaxWidth = MIN(kMaxBubbleWidth - kBubbleSidePadding * 2.0, maxWidth);
    CGFloat size = MIN(ceil([UIScreen mainScreen].bounds.size.width / 2.0), actualMaxWidth);
    return CGSizeMake(size, size);
}

+ (CGSize)boundingSizeForText:(NSString *)text maxWidth:(CGFloat)maxWidth
{
    CGFloat actualMaxWidth = MIN(kMaxBubbleWidth - kBubbleSidePadding * 2.0, maxWidth);

    NSAttributedString *attributedString = [KUSText attributedStringFromText:text fontSize:[self fontSize]+0.5];

    CGSize maxSize = CGSizeMake(actualMaxWidth, 1000.0);
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
        _avatarImageView = [[KUSAvatarImageView alloc] initWithUserSession:userSession];
        [self.contentView addSubview:_avatarImageView];

        _bubbleView = [[UIView alloc] init];
        _bubbleView.layer.masksToBounds = YES;
        [self.contentView addSubview:_bubbleView];

        _labelView = [[TTTAttributedLabel alloc] initWithFrame:self.bounds];
        _labelView.delegate = self;
        _labelView.enabledTextCheckingTypes = NSTextCheckingTypeLink;
        _labelView.textAlignment = NSTextAlignmentLeft;
        _labelView.numberOfLines = 0;
        _labelView.activeLinkAttributes = @{ NSBackgroundColorAttributeName: [UIColor colorWithWhite:0.0 alpha:0.2] };
        _labelView.linkAttributes = nil;
        _labelView.inactiveLinkAttributes = nil;
        [_bubbleView addSubview:_labelView];
      
        UITapGestureRecognizer *tapGestureRecognizerLabel = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_didTapLabel)];
        tapGestureRecognizerLabel.cancelsTouchesInView = NO;
        [_labelView addGestureRecognizer:tapGestureRecognizerLabel];
      
        
        _subLabelView = [[TTTAttributedLabel alloc] initWithFrame:self.bounds];
        _subLabelView.delegate = self;
        _subLabelView.textAlignment = NSTextAlignmentLeft;
        _subLabelView.numberOfLines = 0;
        _subLabelView.activeLinkAttributes = @{ NSBackgroundColorAttributeName: [UIColor colorWithWhite:0.0 alpha:0.2] };
        _subLabelView.linkAttributes = nil;
        _subLabelView.inactiveLinkAttributes = nil;
        _subLabelView.alpha = 0.7;
        
        [_bubbleView addSubview:_subLabelView];
      

        _imageView = [[UIImageView alloc] init];
        _imageView.userInteractionEnabled = YES;
        _imageView.backgroundColor = [UIColor clearColor];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.layer.cornerRadius = 4.0;
        _imageView.layer.masksToBounds = YES;
        [_bubbleView addSubview:_imageView];

        UITapGestureRecognizer *tapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_didTapImage)];
        [_imageView addGestureRecognizer:tapGestureRecognizer];
      
        
        _documentIcon = [[UIImageView alloc] init];
        _documentIcon.userInteractionEnabled = NO;
        _documentIcon.backgroundColor = [UIColor clearColor];
        _documentIcon.contentMode = UIViewContentModeScaleAspectFill;
        _documentIcon.layer.cornerRadius = 4.0;
        _documentIcon.layer.masksToBounds = YES;
        [_bubbleView addSubview:_documentIcon];

        _timestampLabel = [[UILabel alloc] init];
        _timestampLabel.userInteractionEnabled = NO;
        _timestampLabel.backgroundColor = self.backgroundColor;
        _timestampLabel.adjustsFontSizeToFitWidth = YES;
        _timestampLabel.minimumScaleFactor = 8.0 / 11.0;
        [self.contentView addSubview:_timestampLabel];
    }
    return self;
}

- (void)dealloc
{
    _labelView.delegate = nil;
}

#pragma mark - Layout methods

- (void)layoutSubviews
{
    [super layoutSubviews];

    BOOL isRTL = [[KUSLocalization sharedInstance] isCurrentLanguageRTL];
    BOOL currentUser = KUSChatMessageSentByUser(_chatMessage);
  
    CGFloat kBubbleAttachmentFileSizeLabelPadding = 0.0;
    if(_chatMessage.type == KUSChatMessageTypeAttachment){
      kBubbleAttachmentFileSizeLabelPadding = 12.0;
    }

    CGSize boundingSizeForContent = [[self class] boundingSizeForMessage:_chatMessage maxWidth:self.contentView.bounds.size.width];
    CGSize bubbleViewSize = (CGSize) {
        .width = boundingSizeForContent.width + kBubbleSidePadding * 2.0,
        .height = boundingSizeForContent.height + kBubbleTopPadding * 2.0 + kBubbleAttachmentFileSizeLabelPadding
    };
    CGFloat bubbleCurrentX = isRTL ? kRowSidePadding : self.contentView.bounds.size.width - bubbleViewSize.width - kRowSidePadding;
    CGFloat bubbleOtherX = isRTL ? self.contentView.bounds.size.width - bubbleViewSize.width - 60.0 : 60.0;
    _bubbleView.frame = (CGRect) {
        .origin.x = currentUser ? bubbleCurrentX : bubbleOtherX,
        .origin.y = kRowTopPadding,
        .size = bubbleViewSize
    };
    _bubbleView.layer.cornerRadius = MIN(_bubbleView.frame.size.height / 2.0, 15.0);

    _avatarImageView.hidden = currentUser || !_showsAvatar;
    _avatarImageView.frame = (CGRect) {
        .origin.x = isRTL ? self.contentView.bounds.size.width - kRowSidePadding - 40.0 : kRowSidePadding,
        .origin.y = ((bubbleViewSize.height + kRowTopPadding * 2.0) - kAvatarDiameter) / 2.0,
        .size.width = kAvatarDiameter,
        .size.height = kAvatarDiameter
    };

    switch (_chatMessage.type) {
        default:
        case KUSChatMessageTypeText: {
            _labelView.verticalAlignment = TTTAttributedLabelVerticalAlignmentCenter;
            _labelView.frame = (CGRect) {
                .origin.x = (_bubbleView.bounds.size.width - boundingSizeForContent.width) / 2.0,
                .origin.y = (_bubbleView.bounds.size.height - boundingSizeForContent.height) / 2.0,
                .size = boundingSizeForContent
            };
        }   break;
        case KUSChatMessageTypeImage: {
            _imageView.frame = (CGRect) {
                .origin.x = (_bubbleView.bounds.size.width - boundingSizeForContent.width) / 2.0,
                .origin.y = (_bubbleView.bounds.size.height - boundingSizeForContent.height) / 2.0,
                .size = boundingSizeForContent
            };
        }   break;
        case KUSChatMessageTypeAttachment: {
          _labelView.verticalAlignment = TTTAttributedLabelVerticalAlignmentTop;
          _imageView.frame = (CGRect) {
              .origin.x = (_bubbleView.bounds.size.width - boundingSizeForContent.width) / 2.0,
              .origin.y = (_bubbleView.bounds.size.height - boundingSizeForContent.height) / 2.0,
              .size = boundingSizeForContent
          };
          
          _labelView.frame = (CGRect) {
              .origin.x = (_bubbleView.bounds.size.width - boundingSizeForContent.width) / 2.0 + 21.0,
              .origin.y = (_bubbleView.bounds.size.height - boundingSizeForContent.height - kBubbleAttachmentFileSizeLabelPadding) / 2.0,
              .size = CGSizeMake(boundingSizeForContent.width - 21.0, boundingSizeForContent.height)
          };
          _documentIcon.frame = (CGRect) {
              .origin.x = 9,
              .origin.y = 9,
              .size = CGSizeMake(18, 18)
          };
          _subLabelView.frame = (CGRect) {
              .origin.x = _labelView.frame.origin.x,
              .origin.y = _labelView.frame.origin.y + _labelView.frame.size.height + 2,
              .size = CGSizeMake(120, 12)
          };
          
          
        } break;
    }
    
    [_labelView setAccessibilityIdentifier:currentUser ? @"customerMessageLabel" : @"agentMessageLabel"];
    _errorButton.frame = (CGRect) {
        .origin.x = isRTL ? CGRectGetMaxX(_bubbleView.frame) + kMinBubbleHeight + 5.0 : _bubbleView.frame.origin.x - kMinBubbleHeight - 5.0,
        .origin.y = _bubbleView.frame.origin.y + (_bubbleView.frame.size.height - kMinBubbleHeight) / 2.0,
        .size.width = kMinBubbleHeight,
        .size.height = kMinBubbleHeight
    };

    _timestampLabel.hidden = !_showsTimestamp;
    CGFloat timestampInset = ceil(_bubbleView.layer.cornerRadius / 2.0);
    CGFloat timestampWidth = MAX(bubbleViewSize.width - timestampInset * 2.0, 200.0);
    CGFloat timestampCurrentX = isRTL ? _bubbleView.frame.origin.x + timestampInset : CGRectGetMaxX(_bubbleView.frame) - timestampWidth - timestampInset;
    CGFloat timestampOtherX = isRTL ? CGRectGetMaxX(_bubbleView.frame) - timestampWidth - timestampInset : _bubbleView.frame.origin.x + timestampInset;
    _timestampLabel.frame = (CGRect) {
        .origin.x = (currentUser ? timestampCurrentX : timestampOtherX),
        .origin.y = CGRectGetMaxY(_bubbleView.frame) + kTimestampTopPadding,
        .size.width = timestampWidth,
        .size.height = MAX([[self class] heightForTimestamp] - kTimestampTopPadding, 0.0)
    };
    [_timestampLabel setAccessibilityIdentifier:currentUser ? @"customerMessageTimestampLabel" : @"agentMessageTimestampLabel"];
}

#pragma mark - Internal logic methods

- (void)_updateAlphaForState
{
    [_sendingFadeTimer invalidate];
    _sendingFadeTimer = nil;

    switch(_chatMessage.state) {
        case KUSChatMessageStateSent: {
          [UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationOptionCurveLinear  animations:^{
              _bubbleView.alpha = 1.0;
          } completion:^(BOOL finished) {
              
          }];
        }   break;
        case KUSChatMessageStateSending: {
            NSTimeInterval timeElapsed = -[_chatMessage.createdAt timeIntervalSinceNow];
            if (timeElapsed >= kOptimisticSendLoadingDelay) {
              [UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationOptionCurveLinear  animations:^{
                  _bubbleView.alpha = 0.5;
              } completion:^(BOOL finished) {
                  
              }];
                
            } else {
              [UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationOptionCurveLinear  animations:^{
                  _bubbleView.alpha = 1.0;
              } completion:^(BOOL finished) {
                  
              }];

                NSTimeInterval timerInterval = kOptimisticSendLoadingDelay - timeElapsed;
                _sendingFadeTimer = [KUSTimer scheduledTimerWithTimeInterval:timerInterval
                                                                          target:self
                                                                        selector:_cmd
                                                                         repeats:NO];
            }
        }   break;
        case KUSChatMessageStateFailed: {
          [UIView animateWithDuration:0.4 delay:0 options:UIViewAnimationOptionCurveLinear  animations:^{
              _bubbleView.alpha = 0.5;
          } completion:^(BOOL finished) {
              
          }];
        }   break;
    }
}




- (void)_updateBubbleForAttachment
{
  BOOL currentUser = KUSChatMessageSentByUser(_chatMessage);
  KUSChatMessageTableViewCell *appearance = [KUSChatMessageTableViewCell appearance];
  UIColor *textColor = (currentUser ? appearance.userTextColor : appearance.companyTextColor);
  
  NSAttributedString *attString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", _chatMessage.displayAttachmentFileName]
                                                                  attributes:@{
          (id)kCTForegroundColorAttributeName : textColor,
          NSFontAttributeName : [UIFont systemFontOfSize:[[self class] fontSize]],
          NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle)
  }];
  
  _labelView.text = attString;
  _subLabelView.text = [KUSText attributedStringFromText:[NSString stringWithFormat:@"%@", _chatMessage.displayAttachmentSize] fontSize:10 color:textColor];
  [self setNeedsLayout];
}

- (void)_doFirstImageOrAttachmentRequest
{
  NSInteger ndx = 0;
  NSString *orignalJsonId = _chatMessage.originalJSON[@"id"];
    
  if([orignalJsonId containsString:@"_"]){
    ndx = [orignalJsonId componentsSeparatedByString:@"_"][1].integerValue;
  }
  
  NSString *sessionIdOriginal = _chatMessage.originalJSON[@"relationships"][@"session"][@"data"][@"id"];
  NSString *activeAttachmentId = _chatMessage.attachmentIds.firstObject;
  NSString *trackingToken = [Kustomer sharedInstance].userSession.trackingTokenDataSource.currentTrackingToken;
  
  //a self published message, before it's been sent to the server. sessionIdOriginal will also be nil
  if([_chatMessage.originalJSON valueForKeyPath:@"relationships.attachments.links.self"] == nil){
    return;
  }
  NSString *attachmentInfoUrlString = [NSString stringWithFormat:@"%@/%@", [_chatMessage.originalJSON valueForKeyPath:@"relationships.attachments.links.self"], [_chatMessage.originalJSON valueForKeyPath:@"relationships.attachments.data.id"][ndx]];
  NSString *attachmentInfoFullUrlString = [NSString stringWithFormat:@"https://%@.api.%@/c/v1/chat/messages/%@/attachments/%@",
                              [Kustomer sharedInstance].userSession.orgName, [Kustomer hostDomain], _chatMessage.oid, activeAttachmentId];
  
  NSString *attachmentInfoUrl = [NSURL URLWithString:attachmentInfoUrlString];
  
  KUSChatMessage *startingChatMessage = _chatMessage;
  __weak KUSChatMessageTableViewCell *weakSelf = self;
    
  [[Kustomer sharedInstance].userSession.requestManager
  performRequestType:KUSRequestTypeGet
  endpoint:attachmentInfoUrlString
  params: @{ }
  authenticated:YES
  completion:^(NSError *error, NSDictionary *response) {
      if (error) {
          double delayInSeconds = 1.0;
          dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
          dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            __strong KUSChatMessageTableViewCell *strongSelf = weakSelf;
            if (strongSelf == nil) {
                return;
            }
            if ((strongSelf->_chatMessage != startingChatMessage)) {
                return;
            }
            [strongSelf _updateImageForMessage];
          });
          return;
      }
    
    dispatch_async(dispatch_get_main_queue(), ^{
      __strong KUSChatMessageTableViewCell *strongSelf = weakSelf;
      if (strongSelf == nil) {
          return;
      }
      if ((strongSelf->_chatMessage != startingChatMessage)) {
          return;
      }
      
      strongSelf->_chatMessage.attachmentMIMEType = [response valueForKeyPath:@"data.attributes.contentType"];
      strongSelf->_chatMessage.attachmentContentLength = [response valueForKeyPath:@"data.attributes.contentLength"];
      
      NSArray *imgMimes = @[@"image/jpeg", @"image/jpg", @"image/png", @"image/tiff", @"image/gif"];
      NSArray *videoMimes = @[@"video/quicktime", @"video/mp4"];
      if([imgMimes containsObject:(strongSelf->_chatMessage).attachmentMIMEType]){
        [strongSelf->_chatMessage setIsVerifiedAnImage:YES];
        [strongSelf->_chatMessage setIsVerifiedAnAttachment:NO];
        [strongSelf->_chatMessage setType:KUSChatMessageTypeImage];
        [strongSelf _updateImageForMessage];
      }else{ 
        [strongSelf->_chatMessage setIsVerifiedAnImage:NO];
        [strongSelf->_chatMessage setIsVerifiedAnAttachment:YES];
        [strongSelf->_chatMessage setType:KUSChatMessageTypeAttachment];
        (strongSelf->_chatMessage).attachmentFileName = [response valueForKeyPath:@"data.attributes.name"];
        
        BOOL isFromMe = (strongSelf->_chatMessage).direction == KUSChatMessageDirectionIn;
        BOOL isAVideoMIMEType = [videoMimes containsObject:(strongSelf->_chatMessage).attachmentMIMEType];
        BOOL hasLongName = [(strongSelf->_chatMessage).attachmentFileName length] > 24;
        
        if(isFromMe && isAVideoMIMEType && hasLongName){
          (strongSelf->_chatMessage).displayAttachmentFileName = [[KUSLocalization sharedInstance] localizedString:@"Tap to play"];
        }else{
          (strongSelf->_chatMessage).displayAttachmentFileName = (strongSelf->_chatMessage).attachmentFileName;
        }
      
        BOOL isRTL = [[KUSLocalization sharedInstance] isCurrentLanguageRTL];
        BOOL currentUser = KUSChatMessageSentByUser((strongSelf->_chatMessage));
        KUSChatMessageTableViewCell *appearance = [KUSChatMessageTableViewCell appearance];
        UIColor *textColor = (currentUser ? appearance.userTextColor : appearance.companyTextColor);
        
        NSAttributedString *attString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@", (strongSelf->_chatMessage).displayAttachmentFileName]
              attributes:@{
                (id)kCTForegroundColorAttributeName : textColor,
                NSFontAttributeName : [UIFont systemFontOfSize:[[strongSelf class] fontSize]],
                NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle)
        }];
        (strongSelf->_labelView).text = attString;
        
        
        (strongSelf->_subLabelView).text = [KUSText attributedStringFromText:[NSString stringWithFormat:@"%@", (strongSelf->_chatMessage).displayAttachmentSize] fontSize:12 color:textColor];
        [strongSelf _updateImageForMessage];
      }
      
      UITableView *parentTable = (UITableView *)strongSelf.superview;
      if (![parentTable isKindOfClass:[UITableView class]]) {
         parentTable = (UITableView *) parentTable.superview;
      }
      [parentTable reloadData];
    });
  }];
  
  
}
- (void)_updateImageForImageMessage
{
  BOOL currentUser = KUSChatMessageSentByUser(_chatMessage);

  [_imageView setContentMode:UIViewContentModeScaleAspectFill];
  _imageView.sd_imageIndicator = currentUser ? SDWebImageActivityIndicator.whiteIndicator : SDWebImageActivityIndicator.grayIndicator;
  SDWebImageOptions options = SDWebImageHighPriority | SDWebImageScaleDownLargeImages | SDWebImageRetryFailed;

  KUSChatMessage *startingChatMessage = _chatMessage;
  __weak KUSChatMessageTableViewCell *weakSelf = self;
  
  [_imageView
  sd_setImageWithURL:_chatMessage.imageURL
  placeholderImage:nil
  options:options
  completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, NSURL *imageURL) {
      __strong KUSChatMessageTableViewCell *strongSelf = weakSelf;
      if (strongSelf == nil) {
          return;
      }
      if (strongSelf->_chatMessage != startingChatMessage) {
          return;
      }
      if (error) {
          [strongSelf->_imageView setImage:[KUSImage errorImage]];
          [strongSelf->_imageView setContentMode:UIViewContentModeCenter];
      } else {
          [strongSelf->_imageView setContentMode:UIViewContentModeScaleAspectFill];
      }
  }];
}

- (void)_updateImageForMessage
{
  if(_chatMessage.attachmentIds.count == 0){
    //do not download attachment -- it's in the body
    NSString* imageUrl = _chatMessage.body;
    
  }else{
    if((_chatMessage.isVerifiedAnImage == NO || _chatMessage.isVerifiedAnImage == nil) && (_chatMessage.isVerifiedAnAttachment == NO || _chatMessage.isVerifiedAnAttachment == nil)){
      [self _doFirstImageOrAttachmentRequest];
    }else if(_chatMessage.isVerifiedAnImage){
      [self _updateImageForImageMessage];
    }else if(_chatMessage.isVerifiedAnAttachment){
      [self _updateBubbleForAttachment];
    }
  }
}

#pragma mark - Property methods

- (void)setChatMessage:(KUSChatMessage *)chatMessage
{
    _chatMessage = chatMessage;

    BOOL isRTL = [[KUSLocalization sharedInstance] isCurrentLanguageRTL];
    BOOL currentUser = KUSChatMessageSentByUser(_chatMessage);

    KUSChatMessageTableViewCell *appearance = [KUSChatMessageTableViewCell appearance];
    UIColor *bubbleColor = (currentUser ? appearance.userBubbleColor : appearance.companyBubbleColor);
    UIColor *textColor = (currentUser ? appearance.userTextColor : appearance.companyTextColor);

    _bubbleView.backgroundColor = bubbleColor;
    _imageView.backgroundColor = bubbleColor;
    _labelView.backgroundColor = bubbleColor;
    _labelView.textColor = textColor;
    _subLabelView.backgroundColor = bubbleColor;
    _subLabelView.textColor = textColor;

    _labelView.hidden = _chatMessage.type != KUSChatMessageTypeText;
    _imageView.hidden = _chatMessage.type != KUSChatMessageTypeImage;
    
    if(_chatMessage.type == KUSChatMessageTypeAttachment){
      _labelView.hidden = false;
      _imageView.hidden = true;
      _documentIcon.hidden = false;
      _subLabelView.hidden = false;
    }else{
      _documentIcon.hidden = YES;
      _subLabelView.hidden = YES;
    }

    switch (_chatMessage.type) {
        case KUSChatMessageTypeText: {
            _labelView.text = [KUSText attributedStringFromText:_chatMessage.body fontSize:[[self class] fontSize] color:textColor];
            _imageView.image = nil;
            _documentIcon.image = nil;
            _subLabelView.text = nil;
            [_imageView sd_setImageWithURL:nil];
        }   break;
        case KUSChatMessageTypeImage: {
            _labelView.text = nil;
            _imageView.image = nil;
            _documentIcon.image = nil;
            _subLabelView.text = nil;
            _bubbleView.backgroundColor = bubbleColor;
            _imageView.sd_imageIndicator = currentUser ? SDWebImageActivityIndicator.whiteIndicator : SDWebImageActivityIndicator.grayIndicator;
            [_imageView.sd_imageIndicator startAnimatingIndicator];
            if(_chatMessage.attachmentIds.count == 0){
              [_imageView sd_setImageWithURL:[[NSURL alloc] initWithString:_chatMessage.body]];
            }else{
              [self _updateImageForMessage];
            }
        }   break;
        case KUSChatMessageTypeAttachment: {
          _imageView.image = nil;
          [_imageView sd_setImageWithURL:nil];
          _imageView.sd_imageIndicator = currentUser ? SDWebImageActivityIndicator.whiteIndicator : SDWebImageActivityIndicator.grayIndicator;
          [_imageView.sd_imageIndicator startAnimatingIndicator];
          _documentIcon.image = [self getAttachmentIcon];
          [self _updateImageForMessage];
        } break;
    }

    [_avatarImageView setUserId:(currentUser ? nil : _chatMessage.sentById)];

    if (_chatMessage.state == KUSChatMessageStateFailed) {
        if (_errorButton == nil) {
            _errorButton = [[UIButton alloc] init];
            [_errorButton setImage:[KUSImage errorImage] forState:UIControlStateNormal];
            [_errorButton addTarget:self
                             action:@selector(_didTapError)
                   forControlEvents:UIControlEventTouchUpInside];
            [self.contentView addSubview:_errorButton];
        }
        _errorButton.hidden = NO;
    } else {
        _errorButton.hidden = YES;
    }

    _timestampLabel.textAlignment = (currentUser ? isRTL ? NSTextAlignmentLeft : NSTextAlignmentRight : isRTL ?  NSTextAlignmentRight : NSTextAlignmentLeft);
    _timestampLabel.text = [KUSDate messageTimestampTextFromDate:_chatMessage.createdAt];

    [self _updateAlphaForState];
    [self setNeedsLayout];
}

- (void)setShowsAvatar:(BOOL)showsAvatar
{
    _showsAvatar = showsAvatar;
    [self setNeedsLayout];
}

- (void)setShowsTimestamp:(BOOL)showsTimestamp
{
    _showsTimestamp = showsTimestamp;
    [self setNeedsLayout];
}

#pragma mark - Interface element methods

- (void)_didTapError
{
    if ([self.delegate respondsToSelector:@selector(chatMessageTableViewCellDidTapError:forMessage:)]) {
        [self.delegate chatMessageTableViewCellDidTapError:self forMessage:_chatMessage];
    }
}

#pragma mark - TTTAttributedLabelDelegate methods

- (void)attributedLabel:(TTTAttributedLabel *)label didSelectLinkWithURL:(NSURL *)url
{
    if ([self.delegate respondsToSelector:@selector(chatMessageTableViewCell:didTapLink:)]) {
        [self.delegate chatMessageTableViewCell:self didTapLink:url];
    }
}

#pragma mark - icon methods

- (UIImage*)getAttachmentIcon
{
  UIImage *icon = @{
    @"application/msword": KUSImage.docIconWord,
    @"application/vnd.openxmlformats-officedocument.wordprocessingml.document": KUSImage.docIconWord,
    @"text/plain": KUSImage.docIconText,
    @"application/pdf": KUSImage.docIconPdf,
    @"video/mp4": KUSImage.docIconVideo,
    @"video/quicktime": KUSImage.docIconVideo,
    @"application/vnd.ms-excel": KUSImage.docIconExcel,
    @"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": KUSImage.docIconExcel,
    @"application/zip":KUSImage.docIconZip,
  }[_chatMessage.attachmentMIMEType];
  
  if(icon == NULL){
    icon = KUSImage.docIconOther;
  }
  
  return icon;
}



#pragma mark - UIGestureRecognizer methods

- (void)_didTapLabel
{
  if(_chatMessage.type==KUSChatMessageTypeAttachment){
    if ([self.delegate respondsToSelector:@selector(chatMessageTableViewCellDidTapAttachment:forMessage:)]) {
       [self.delegate chatMessageTableViewCellDidTapAttachment:self forMessage:_chatMessage];
    }
    
      
  }
}
- (void)_didTapImage
{
  if ([_imageView.image isEqual:[KUSImage errorImage]]) {
    [_chatMessage setIsVerifiedAnAttachment:false];
    [_chatMessage setIsVerifiedAnImage:false];
    [self _updateImageForMessage];
    return;
  }
  
  if(_chatMessage.type == KUSChatMessageTypeAttachment){
    if ([self.delegate respondsToSelector:@selector(chatMessageTableViewCellDidTapAttachment:forMessage:)]) {
      [self.delegate chatMessageTableViewCellDidTapAttachment:self forMessage:_chatMessage];
    }
  }else if(_chatMessage.type == KUSChatMessageTypeImage){
    if ([self.delegate respondsToSelector:@selector(chatMessageTableViewCellDidTapImage:forMessage:)]) {
      [self.delegate chatMessageTableViewCellDidTapImage:self forMessage:_chatMessage];
    }
  }
  
  
  
  
}

#pragma mark - UIAppearance methods

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    _timestampLabel.backgroundColor = backgroundColor;
}

- (void)setTimestampFont:(UIFont *)timestampFont
{
    _timestampFont = timestampFont;
    _timestampLabel.font = _timestampFont;
}

- (void)setTimestampTextColor:(UIColor *)timestampTextColor
{
    _timestampTextColor = timestampTextColor;
    _timestampLabel.textColor = _timestampTextColor;
}

@end

