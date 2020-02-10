//
//  KUSUpload.m
//  Kustomer
//
//  Created by Daniel Amitay on 12/31/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSUpload.h"
#import "KUSMediaAttachment.h"

@implementation KUSUpload

#pragma mark - Public methods

+ (void)uploadAttachments:(NSArray<KUSMediaAttachment *> *)originalAttachments
         userSession:(KUSUserSession *)userSession
          completion:(void(^)(NSError *error, NSArray<KUSChatAttachment *> *attachments))completion
{
    if (originalAttachments.count == 0) {
        if (completion) {
            completion(nil, @[]);
        }
        return;
    }

    __block BOOL didSendCompletion = NO;
    __block NSUInteger uploadedCount = 0;
    __block NSMutableArray<id> *attachments = [[NSMutableArray alloc] init];

    void(^onUploadComplete)(NSUInteger, NSError *, KUSChatAttachment *) = ^void(NSUInteger index, NSError *error, KUSChatAttachment *attachment) {
        if (error) {
            if (completion && !didSendCompletion) {
                didSendCompletion = YES;
                completion(error, nil);
            }
            return;
        }

        uploadedCount++;
        [attachments replaceObjectAtIndex:index withObject:attachment];
        if (uploadedCount == originalAttachments.count) {
            if (completion && !didSendCompletion) {
                didSendCompletion = YES;
                completion(nil, attachments);
            }
            return;
        }
    };

    for (NSUInteger i = 0; i < originalAttachments.count; i++) {
        [attachments addObject:[NSNull null]];
        KUSMediaAttachment *anAttachment = [originalAttachments objectAtIndex:i];

        NSUInteger index = i;
        [self
         _uploadAttachment:anAttachment
         userSession:userSession
         completion:^(NSError *error, KUSChatAttachment *attachment) {
             onUploadComplete(index, error, attachment);
         }];
    }
}

#pragma mark - Internal methods

+ (void)_uploadAttachment:(KUSMediaAttachment *)anAttachment
         userSession:(KUSUserSession *)userSession
          completion:(void(^)(NSError *error, KUSChatAttachment *attachment))completion
{
    NSData *fileData;
    NSString *fileName;
  
    if(anAttachment.isAnImage){
      fileData = UIImageJPEGRepresentation(anAttachment.fullSizeImage, 0.8);
      fileName = [NSString stringWithFormat:@"%@.jpg", [NSUUID UUID].UUIDString];
      anAttachment.MIMEType = @"image/jpeg";
    }else{
      fileData = anAttachment.data;
      fileName = [NSString stringWithFormat:@"%@.%@", [NSUUID UUID].UUIDString, anAttachment.fileExtension];
    }
    
    [userSession.requestManager
     performRequestType:KUSRequestTypePost
     endpoint:@"/c/v1/chat/attachments"
     params:@{
              @"name": fileName,
              @"contentLength": @(fileData.length),
              @"contentType": anAttachment.MIMEType
              }
     authenticated:YES
     completion:^(NSError *error, NSDictionary *response) {
         if (error) {
             if (completion) {
                 completion(error, nil);
             }
             return;
         }

         KUSChatAttachment *chatAttachment = [[KUSChatAttachment alloc] initWithJSON:response[@"data"]];
         NSURL *uploadURL = [NSURL URLWithString:[response valueForKeyPath:@"meta.upload.url"]];
         NSDictionary<NSString *, NSString *> *uploadFields = [response valueForKeyPath:@"meta.upload.fields"];

         NSString *boundary = @"----FormBoundary";
         NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
         NSData *bodyData = KUSUploadBodyDataFromImageAndFileNameAndFieldsAndBoundary(fileData, fileName, anAttachment, uploadFields, boundary);

         [userSession.requestManager
          performRequestType:KUSRequestTypePost
          URL:uploadURL
          params:nil
          bodyData:bodyData
          authenticated:NO
          additionalHeaders:@{ @"Content-Type" : contentType }
          completion:^(NSError *error, NSDictionary *response, NSHTTPURLResponse *httpResponse) {
              BOOL twoHundred = httpResponse.statusCode >= 200 && httpResponse.statusCode < 300;
              if (!twoHundred) {
                  if (completion) {
                      completion(error ?: [NSError new], nil);
                  }
                  return;
              }

              if (completion) {
                  completion(nil, chatAttachment);
              }
          }];
     }];
}

#pragma mark - Helper methods

static NSData *KUSUploadBodyDataFromImageAndFileNameAndFieldsAndBoundary(NSData *fileData,
                                                                         NSString *fileName,
                                                                         KUSMediaAttachment *anAttachment,
                                                                         NSDictionary<NSString *, NSString *> *uploadFields,
                                                                         NSString *boundary)
{
    NSMutableData *bodyData = [[NSMutableData alloc] init];

    // Make sure to insert the "key" field first
    NSMutableArray<NSString *> *fieldKeys = [uploadFields.allKeys mutableCopy];
    if ([fieldKeys containsObject:@"key"]) {
        [fieldKeys removeObject:@"key"];
        [fieldKeys insertObject:@"key" atIndex:0];
    }

    [bodyData appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    for (NSString *field in fieldKeys) {
        NSString *value = uploadFields[field];
        [bodyData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n%@", field, value] dataUsingEncoding:NSUTF8StringEncoding]];
        [bodyData appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    }

    [bodyData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"file\"; filename=\"%@\"\r\n", fileName] dataUsingEncoding:NSUTF8StringEncoding]];
    
    if(anAttachment.isAnImage){
      [bodyData appendData:[@"Content-Type: image/jpeg\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }else{
      [bodyData appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", anAttachment.MIMEType] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [bodyData appendData:[NSData dataWithData:fileData]];
    [bodyData appendData:[[NSString stringWithFormat:@"\r\n--%@--", boundary] dataUsingEncoding:NSUTF8StringEncoding]];

    return bodyData;
}

@end
