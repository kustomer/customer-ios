//
//  KUSAttachmentViewerNavigationController.m
//  Kustomer
//
//  Created by Will Jessop on 1/27/20.
//  Copyright © 2020 Kustomer. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "KUSAttachmentViewerNavigationController.h"
#import "KUSAttachmentViewer.h"

@interface KUSAttachmentViewerNavigationController () <UINavigationControllerDelegate> { }
@end

@implementation KUSAttachmentViewerNavigationController

#pragma mark - UIViewController methods
- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  
}

@end
