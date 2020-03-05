//
//  KUSQLPreviewItem.m
//  Kustomer
//
//  Created by Will Jessop on 1/29/20.
//  Copyright © 2020 Kustomer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <QuickLook/QuickLook.h>
#import "KUSQLPreviewItem.h"


@interface KUSQLPreviewItem () <QLPreviewItem> {
  
}
@end

@implementation KUSQLPreviewItem
  @synthesize previewItemTitle = _previewItemTitle;  //Must do this

  //Setter method
  - (void) setPreviewItemTitle:(NSString *)title
  {
    _previewItemTitle = title;
  }
  //Getter method
  - (NSString*) previewItemTitle {
    return _previewItemTitle;
  }

@end
