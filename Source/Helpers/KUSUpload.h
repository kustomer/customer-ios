//
//  KUSUpload.h
//  Kustomer
//
//  Created by Daniel Amitay on 12/31/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "KUSMediaAttachment.h"
#import "KUSChatAttachment.h"
#import "KUSUserSession.h"

@interface KUSUpload : NSObject

+ (void)uploadAttachments:(NSArray<KUSMediaAttachment *> *)attachments
         userSession:(KUSUserSession *)userSession
          completion:(void(^)(NSError *error, NSArray<KUSChatAttachment *> *attachments))completion;

@end

