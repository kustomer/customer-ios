//
//  KUSQLPreviewItem.h
//  Kustomer
//
//  Created by Will Jessop on 1/29/20.
//  Copyright © 2020 Kustomer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuickLook/QuickLook.h>

@interface KUSQLPreviewItem : NSObject

// @property (nonatomic, copy, readonly) NSString *name;
// @property (nonatomic, copy, readonly) NSDate *startDate;
// @property (nonatomic, copy, readonly) NSDate *endDate;
// @property (nonatomic, assign, readonly) BOOL enabled;
  @property(readwrite, nonatomic) NSString *previewItemTitle;
  @property(readwrite, nonatomic) NSURL *previewItemURL;

@end
