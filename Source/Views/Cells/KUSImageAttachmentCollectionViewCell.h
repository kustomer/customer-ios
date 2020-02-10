//
//  KUSImageAttachmentCollectionViewCell.h
//  Kustomer
//
//  Created by Daniel Amitay on 12/30/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "KUSMediaAttachment.h"

@class KUSImageAttachmentCollectionViewCell;
@protocol KUSImageAttachmentCollectionViewCellDelegate <NSObject>

@optional
- (void)imageAttachmentCollectionViewCellDidTapRemove:(KUSImageAttachmentCollectionViewCell *)cell;

@end

@interface KUSImageAttachmentCollectionViewCell : UICollectionViewCell

@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) KUSMediaAttachment *mediaAttachment;
@property (nonatomic, weak) id<KUSImageAttachmentCollectionViewCellDelegate> delegate;

@end
