//
//  KustomerViewController.m
//  Kustomer
//
//  Created by Daniel Amitay on 7/16/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KustomerViewController.h"

#import "Kustomer_Private.h"

#import "KUSSessionsViewController.h"
#import "KUSUserSession.h"

@implementation KustomerViewController

#pragma mark - Lifecycle methods

- (instancetype)init
{
    KUSUserSession *userSession = [Kustomer sharedInstance].userSession;
    KUSSessionsViewController *sessionsViewController = [[KUSSessionsViewController alloc] initWithUserSession:userSession];

    if (self = [super initWithRootViewController:sessionsViewController]) {
        self.modalPresentationStyle = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
        ? UIModalPresentationFormSheet
        : UIModalPresentationOverFullScreen;
    }

    return self;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    if (self.isBeingPresented || self.movingToParentViewController) {
        KUSUserSession *userSession = [Kustomer sharedInstance].userSession;
        [userSession.pushClient setSupportViewControllerPresented:YES];
        
        //Connecting to Presence channel when Kustomer support chat screen shown for existing user
        [self connectToCustomerPresenceChannel:userSession];
    }
}

- (void) connectToCustomerPresenceChannel: (KUSUserSession *)userSession {
    
    NSString *customerId = [userSession.chatSessionsDataSource _customerId];
    if(customerId) {
        [userSession.pushClient connectToCustomerPresenceChannel:customerId];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

    if (self.isBeingDismissed || self.movingFromParentViewController) {
        KUSUserSession *userSession = [Kustomer sharedInstance].userSession;
        [userSession.pushClient setSupportViewControllerPresented:NO];
        
        //Disconnecting from Presence channel when Kustomer support is exited
        [userSession.pushClient disconnectFromCustomerPresenceChannel];
    }
}

@end
