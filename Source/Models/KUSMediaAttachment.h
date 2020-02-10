//
//  KUSMediaAttachment.h
//  Kustomer
//
//  Created by Will Jessop on 1/31/20.
//  Copyright © 2020 Kustomer. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface KUSMediaAttachment : NSObject

// @property (nonatomic, copy, readonly) NSString *name;
// @property (nonatomic, copy, readonly) NSDate *startDate;
// @property (nonatomic, copy, readonly) NSDate *endDate;
// @property (nonatomic, assign, readonly) BOOL enabled;
  @property(readwrite, nonatomic) NSString *MIMEType;
  @property(readwrite, nonatomic) NSString *fileExtension;
  @property(readwrite, nonatomic) NSData *data;
  @property(readwrite, nonatomic) NSString *fileName;
  @property(readwrite, nonatomic) UIImage *previewImage;
  @property(readwrite, nonatomic) UIImage *fullSizeImage;
  @property(readwrite, nonatomic) BOOL isAnImage;
  @property(readwrite, nonatomic) NSURL *mediaURLForPreviewing;
  @property(readwrite, nonatomic) NSNumber *fileSize;

  

  
  //@property(readwrite, nonatomic) NSURL *previewItemURL;

@end
