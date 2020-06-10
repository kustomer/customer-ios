//
//  AppDelegate.m
//  KustomerExample
//
//  Created by Daniel Amitay on 7/1/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "AppDelegate.h"
#import "ViewController.h"
#import "Kustomer.h"
#import "KUSSatisfactionFormTableViewCell.h"
#import "KUSRatingView.h"
#import "KUSEditFeedbackTableViewCell.h"
#import "KUSColor.h"
#import "KUSChatTableView.h"
#import "KUSChatMessageTableViewCell.h"


#error A valid API key is required
static NSString *const kKustomerAPIKey = @"API_KEY";

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [Kustomer initializeWithAPIKey:kKustomerAPIKey];
  
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[ViewController alloc] init];
    [self.window makeKeyAndVisible];
  
    return YES;
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{

}

@end
