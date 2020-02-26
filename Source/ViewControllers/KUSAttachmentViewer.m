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
NSString *const KUSMovieAttachmentDirectoryName = @"KUSAttachmentsMovies";

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
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(cancelTap)];
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
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(cancelTap)];
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
      if([self.localFileExtension isEqualToString:@"mov"] || [self.localFileExtension isEqualToString:@"mp4"]){
        [self downloadFile];
      }else{
        [self showPreviewForLocalItem];
      }
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

- (void) setNavBarWithActionButton
{
  UIBarButtonItem* button = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(tapShareVideo)];
  [button setTintColor:UIColor.whiteColor];
  self.navigationItem.rightBarButtonItems = @[
    button
  ];
}
- (void) setNavBarWithActionLoadingButton
{
  dispatch_async(dispatch_get_main_queue(), ^{
    UIActivityIndicatorView * activityView = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 25, 25)];
    [activityView sizeToFit];
    [activityView setColor:UIColor.whiteColor];
    [activityView setTintColor:UIColor.whiteColor];
    [activityView setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin)];
    UIBarButtonItem *loadingView = [[UIBarButtonItem alloc] initWithCustomView:activityView];
    [activityView startAnimating];
    [self.navigationItem setRightBarButtonItem:loadingView];
  });
}

- (void) showVideoPlayer:(NSURL *) url {
  AVPlayer *player = [AVPlayer playerWithURL:url];
  AVPlayerViewController *controller = [[AVPlayerViewController alloc] init];
  controller.player = player;
  
  //in ios 10 there is no close button on avplayerviewcontroller
  if(!@available(iOS 11, *)) {
    if([self navigationController] != NULL){
      UIViewController *presntr = [self presentingViewController];
      [self.navigationController dismissViewControllerAnimated:YES completion:^{
        [presntr presentViewController:controller animated:YES completion:nil];
        [player play];
      }];
    }
  }else{
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.title = @"";
    [self setNavBarWithActionButton];
    self.mediaURL = url;
    
    [self addChildViewController:controller];
    [self.view addSubview:controller.view];
    
    //only avail in ios 11 + it's too small:
    // controller.view.frame = self.view.safeAreaLayoutGuide.layoutFrame;
    controller.view.frame = self.view.frame;
    
    // CGFloat navbarheight = self.navigationController.navigationBar.frame.size.height;
    // controller.view.frame = self.view.frame;
    // controller.view.frame = CGRectMake(0, navbarheight, controller.view.frame.size.width, controller.view.frame.size.height - navbarheight);
    
    [player play];
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
- (void) emptyMovieAttachmentCacheIfNeeded
{
  NSFileManager *fileManager = [[NSFileManager alloc] init];
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString  *documentsDirectory = [paths objectAtIndex:0];
  NSString  *attachmentsFolder = [NSString stringWithFormat:@"%@/%@", documentsDirectory, KUSMovieAttachmentDirectoryName];
  
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






#pragma mark Video share button
- (void)showShareSheetForVideo
{
  NSURL* mediaLocalUrl = [[NSURL alloc] initFileURLWithPath:self.mediaLocalFilePath];
  NSArray *activityItems = @[mediaLocalUrl];
  UIActivityViewController *activityViewControntroller = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
  activityViewControntroller.excludedActivityTypes = @[];
  
  //todo: check if this is really needed
  if(UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad){
    activityViewControntroller.popoverPresentationController.sourceView = self.view;
    activityViewControntroller.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/4, 0, 0);
  }
  
  [self presentViewController:activityViewControntroller animated:true completion:nil];
  
  [self setNavBarWithActionButton];
}
- (void)tapShareVideo
{
  [self setNavBarWithActionLoadingButton];
  [self emptyMovieAttachmentCacheIfNeeded];
  NSURLSessionConfiguration *defaultConfigObject = [NSURLSessionConfiguration defaultSessionConfiguration];
  NSURLSession *defaultSession = [NSURLSession sessionWithConfiguration: defaultConfigObject];
  NSURLSessionDataTask * dataTask = [defaultSession dataTaskWithURL:self.mediaURL
                                                  completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    NSString *directDownloadFileName = response.suggestedFilename;
    NSString *directDownloadMimeType = response.MIMEType;
    if(error == nil){
      NSData *urlData = [NSData dataWithContentsOfURL:self.mediaURL];
      self.mediaData = urlData;
      if (urlData){
        NSArray       *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString  *documentsDirectory = [paths objectAtIndex:0];
        
        NSString  *filePath = [NSString stringWithFormat:@"%@/%@/%@.%@", documentsDirectory, KUSMovieAttachmentDirectoryName, self.localFileName, self.localFileExtension];
        self.mediaLocalFilePath = filePath;
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        if([fileManager fileExistsAtPath:filePath]){
          //open
          dispatch_async(dispatch_get_main_queue(), ^{
            [self showShareSheetForVideo];
          });
        }else{
          //saving is done on main thread
          dispatch_async(dispatch_get_main_queue(), ^{
            [fileManager createDirectoryAtPath:[NSString stringWithFormat:@"%@/%@", documentsDirectory, KUSMovieAttachmentDirectoryName] withIntermediateDirectories:NO attributes:nil error:nil];
            [urlData writeToFile:filePath atomically:YES];
            [self showShareSheetForVideo];
          });
        }
      }
    }
    
  }];
  [dataTask resume];
}


@end
