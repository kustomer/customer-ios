//
//  KUSForm.h
//  Kustomer
//
//  Created by Daniel Amitay on 12/19/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSModel.h"
#import "KUSFormQuestion.h"

@interface KUSForm : KUSModel

@property (nonatomic, copy, readonly) NSArray<KUSFormQuestion *> *questions;
@property (nonatomic, assign, readwrite) BOOL proactive;

- (BOOL)containsEmailQuestion;

@end
