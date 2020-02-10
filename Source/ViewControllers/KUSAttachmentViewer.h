//
//  KUSAttachmentViewer.h
//  Kustomer
//
//  Created by Will Jessop on 1/27/20.
//  Copyright © 2020 Kustomer. All rights reserved.
//

#import <QuickLook/QuickLook.h>
#import "KUSChatMessage.h"


@interface KUSAttachmentViewer : UIViewController
  @property (nonatomic, retain) NSString *fileName;
  @property (nonatomic, assign, readwrite) KUSChatMessage *chatMessage;
  @property (nonatomic, retain) NSString *localFileName;
  @property (nonatomic, retain) NSString *localFileExtension;
  @property (nonatomic, readwrite) BOOL hasFinishedBeingDataSource;

@end

FOUNDATION_EXPORT NSString *const KUSAttachmentDirectoryName;
