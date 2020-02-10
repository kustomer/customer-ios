//
//  KUSAttachmentViewer.m
//  Kustomer
//
//  Created by Will Jessop on 1/27/20.
//  Copyright © 2020 Kustomer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuickLook/QuickLook.h>
#import "KUSAttachmentViewer.h"
#import "KUSChatMessage.h"
#import <Kustomer/Kustomer.h>
#import "Kustomer_Private.h"
#import "KUSUserSession.h"
#import <AVKit/AVKit.h>
#import <QuartzCore/QuartzCore.h>
#import "KUSQLPreviewItem.h"

NSString *const KUSAttachmentDirectoryName = @"KUSAttachments";
double const KUSMaxAttachmentDirectorySizeBytes = 9.5 * 1000 * 1000;

@interface KUSAttachmentViewer () <QLPreviewControllerDataSource> {
  
}
@end

@implementation KUSAttachmentViewer

#pragma mark - UIViewController methods
- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.title = [NSString stringWithFormat:@"Loading %@", self.chatMessage.displayAttachmentFileName];
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelTap)];
  self.view.backgroundColor = UIColor.whiteColor;
  UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] init];
  spinner.center = self.view.center;
  [spinner setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleGray];
  [self.view addSubview:spinner];
  [spinner startAnimating];
    
  double delayInSeconds = 0.1;
  dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
  dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
   [self loadNeededFiles];
  });
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelTap)];
}


#pragma mark - Other methods
- (void) loadNeededFiles
{
  NSDictionary *extensionsForMimeTypes = @{
    @"application/msword": @"doc",
    @"application/vnd.openxmlformats-officedocument.wordprocessingml.document": @"docx",
    @"text/plain": @"txt",
    @"application/pdf": @"pdf",
    @"video/mp4": @"mp4",
    @"video/quicktime": @"mov",
    @"application/vnd.ms-excel": @"xls",
    @"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet": @"xlsx",
    @"application/zip": @"zip"
  };
  
  NSString *extension = @"";
  extension = [extensionsForMimeTypes valueForKey:self.chatMessage.attachmentMIMEType];
  
  NSString *fileNameUsingId = [NSString stringWithFormat:@"%@.%@", self.chatMessage.oid, extension];
  self.localFileName = [NSString stringWithFormat:@"%@", self.chatMessage.oid];
  self.localFileExtension = [NSString stringWithFormat:@"%@", extension];
  
  
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString  *documentsDirectory = [paths objectAtIndex:0];
  NSString  *filePath = [NSString stringWithFormat:@"%@/%@/%@.%@", documentsDirectory, KUSAttachmentDirectoryName, self.localFileName, self.localFileExtension];
  NSFileManager *fileManager = [[NSFileManager alloc] init];
  if([fileManager fileExistsAtPath:filePath]){
     dispatch_async(dispatch_get_main_queue(), ^{
       [self showPreviewForLocalItem];
     });
  }else{
    [self downloadFile];
  }
}

- (void) downloadFile
{
  [self emptyAttachmentCacheIfNeeded];
  NSInteger ndx = 0;
  NSString *orignalJsonId = self.chatMessage.originalJSON[@"id"];
  if([orignalJsonId containsString:@"_"]){
    ndx = [orignalJsonId componentsSeparatedByString:@"_"][1].integerValue;
  }
  NSString *sessionIdOriginal = _chatMessage.originalJSON[@"relationships"][@"session"][@"data"][@"id"];
  NSString *activeAttachmentId = _chatMessage.attachmentIds.firstObject;
  NSString *trackingToken = [Kustomer sharedInstance].userSession.trackingTokenDataSource.currentTrackingToken;

  NSString *attachmentInfoUrlString = [NSString stringWithFormat:@"%@/%@", [_chatMessage.originalJSON valueForKeyPath:@"relationships.attachments.links.self"], [_chatMessage.originalJSON valueForKeyPath:@"relationships.attachments.data.id"][ndx]];
  NSString *attachmentInfoFullUrlString = [NSString stringWithFormat:@"https://%@.api.%@/c/v1/chat/messages/%@/attachments/%@",
                              [Kustomer sharedInstance].userSession.orgName, [Kustomer hostDomain], _chatMessage.oid, activeAttachmentId];
  
  NSString *attachmentInfoUrl = [NSURL URLWithString:attachmentInfoUrlString];
  
  [[Kustomer sharedInstance].userSession.requestManager
  performRequestType:KUSRequestTypeGet
  endpoint:attachmentInfoUrlString
  params: @{ }
  authenticated:YES
  completion:^(NSError *error, NSDictionary *response) {
    if (error) {
        return;
    }
    NSString *urlOfAttachment = [response valueForKeyPath:@"data.links.related"];
    NSURL  *url = [NSURL URLWithString:urlOfAttachment];
    
    NSArray *videoMimes = @[@"video/quicktime", @"video/mp4"];
    if([videoMimes containsObject:self.chatMessage.attachmentMIMEType]){
      [self showVideoPlayer: url];
      return;
    }
    
    
    NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject];
    NSURLSessionDataTask * dataTask = [defaultSession dataTaskWithURL:url
                                                      completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
      NSString *directDownloadFileName = response.suggestedFilename;
      NSString *directDownloadMimeType = response.MIMEType;
      if(error == nil){
        NSData *urlData = [NSData dataWithContentsOfURL:url];
          if (urlData){
              NSArray       *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
              NSString  *documentsDirectory = [paths objectAtIndex:0];
    
              NSString  *filePath = [NSString stringWithFormat:@"%@/%@/%@.%@", documentsDirectory, KUSAttachmentDirectoryName, self.localFileName, self.localFileExtension];
    
              NSFileManager *fileManager = [[NSFileManager alloc] init];
              if([fileManager fileExistsAtPath:filePath]){
                //open
                dispatch_async(dispatch_get_main_queue(), ^{
                  [self showPreviewForLocalItem];
                });
              }else{
                //saving is done on main thread
                dispatch_async(dispatch_get_main_queue(), ^{
                    [fileManager createDirectoryAtPath:[NSString stringWithFormat:@"%@/%@", documentsDirectory, KUSAttachmentDirectoryName] withIntermediateDirectories:NO attributes:nil error:nil];
                    [urlData writeToFile:filePath atomically:YES];
                    [self showPreviewForLocalItem];
                });
              }
          }
      }
    
    }];
    [dataTask resume];
    
  }];
}

- (void) showQuickLookPreview
{
  QLPreviewController *preview = [[QLPreviewController alloc] init];
  // for iOS 12 and below
  KUSAttachmentViewer * __strong kParent = self;
  preview.delegate = kParent;
  preview.dataSource = kParent;
  
  if(@available(iOS 13, *)) {
    [preview.navigationItem setHidesBackButton:YES animated:NO];
    [preview.navigationItem setLeftBarButtonItems:@[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(cancelTap)]]];
    
    if([self navigationController] != NULL){
      // [self.navigationController setViewControllers:@[self, preview] animated:YES];
      [[self navigationController] pushViewController:preview animated:NO];
    }
  }else{
    UIViewController* parent = self.navigationController.presentingViewController;
    
    [[self navigationController] dismissViewControllerAnimated:YES completion:^{
      [parent presentViewController:preview animated:YES completion:^{
        [kParent didFinishBeingDataSource];
      }];
    }];
  }
}


- (void) didFinishBeingDataSource
{
  self.hasFinishedBeingDataSource = YES;
}

- (void) showVideoPlayer:(NSURL *) url {
  AVPlayer *player = [AVPlayer playerWithURL:url];

  AVPlayerViewController *controller = [[AVPlayerViewController alloc] init];
  controller.player = player;
  if([self navigationController] != NULL){
    UIViewController *presntr = [self presentingViewController];
    [self.navigationController dismissViewControllerAnimated:YES completion:^{
      [presntr presentViewController:controller animated:YES completion:nil];
      [player play];
    }];
  }
}
- (void) showPreviewForLocalItem
{
  NSArray *videoMimes = @[@"video/quicktime", @"video/mp4"];
  if(![videoMimes containsObject:self.chatMessage.attachmentMIMEType]){
    [self showQuickLookPreview];
  }
}

#pragma mark - Gesture recognizers
- (void)cancelTap
{
  if([self navigationController] != NULL){
    [[self navigationController] dismissViewControllerAnimated:true completion:NULL];
  }
}

#pragma mark - QLPreviewControllerDataSource
- (NSInteger)numberOfPreviewItemsInPreviewController:(nonnull QLPreviewController *)controller {
  return 1;
}

- (nonnull id<QLPreviewItem>)previewController:(nonnull QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
  KUSQLPreviewItem *item = [[KUSQLPreviewItem alloc] init];
  item.previewItemTitle = [[self chatMessage] displayAttachmentFileName];
  item.previewItemURL = [self getUrlForLocalItem];
  return item;
}
- (NSURL*)getUrlForLocalItem
{
  NSURL *fileURL = nil;
  NSString *fileName = [NSString stringWithFormat:@"%@.%@", self.localFileName, self.localFileExtension];
  NSArray* documentDirectories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString* documentDirectory = [documentDirectories objectAtIndex:0];
  NSString *previewFileFullPath = [[NSString stringWithFormat:@"%@/%@", documentDirectory, KUSAttachmentDirectoryName] stringByAppendingPathComponent:fileName];
  fileURL = [NSURL fileURLWithPath:previewFileFullPath];
  return fileURL;
}


#pragma mark Attachment file cache management
- (void) emptyAttachmentCacheIfNeeded
{
  NSFileManager *fileManager = [[NSFileManager alloc] init];
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString  *documentsDirectory = [paths objectAtIndex:0];
  NSString  *attachmentsFolder = [NSString stringWithFormat:@"%@/%@", documentsDirectory, KUSAttachmentDirectoryName];
  
  long fileSizeTotal = 0;
  NSArray* files = [fileManager subpathsOfDirectoryAtPath:attachmentsFolder error:nil];
  for (NSString *aFile in files)
  {
    NSDictionary* fileDict = [fileManager attributesOfItemAtPath:[attachmentsFolder stringByAppendingPathComponent:aFile] error:nil];
    fileSizeTotal += fileDict.fileSize;
  }
  if(fileSizeTotal > KUSMaxAttachmentDirectorySizeBytes){
    [fileManager removeItemAtPath:attachmentsFolder error:nil];
  }
}


@end



